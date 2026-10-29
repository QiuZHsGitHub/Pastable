#!/usr/bin/env bash
#
# Builds the certificate-free GitHub Releases package for Pastable.
#
# The app is signed ad-hoc ("-"), so no Developer ID / Apple Development
# certificate is required. Gatekeeper still asks the user to confirm the first
# launch because the build is not notarized — that is expected for this
# distribution channel and is documented in the release notes.
#
# Usage:
#   tools/release/build-direct-dmg.sh [--archs "arm64 x86_64"] [--no-clean]
#
# Output: dist/Pastable-<version>.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ARCHS="arm64 x86_64"
CLEAN=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --archs) ARCHS="${2:?missing value for --archs}"; shift 2 ;;
    --no-clean) CLEAN=0; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

DERIVED="$ROOT/.build/dd-direct"
DIST="$ROOT/dist"
ENTITLEMENTS="$ROOT/tools/release/Direct.entitlements"

echo "==> Building Pastable (Release, ad-hoc signed, archs: $ARCHS)"
if [[ $CLEAN -eq 1 ]]; then
  rm -rf "$DERIVED"
fi

xcodebuild \
  -project Pastable.xcodeproj \
  -scheme Pastable \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  ARCHS="$ARCHS" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
  build

APP="$DERIVED/Build/Products/Release/Pastable.app"
[[ -d "$APP" ]] || { echo "build product missing: $APP" >&2; exit 1; }

# Xcode signs local builds with get-task-allow so a debugger can attach. The
# release binary stores clipboard history, so re-sign it with only the direct
# distribution entitlements and drop that debugging entitlement.
echo "==> Re-signing with the direct entitlement set"
codesign --force --sign - --options runtime --entitlements "$ENTITLEMENTS" "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")
echo "==> Product version $VERSION ($BUILD)"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
lipo -archs "$APP/Contents/MacOS/Pastable"
codesign -dvv "$APP" 2>&1 | grep -E '^(Identifier|Authority|TeamIdentifier|Format)|Signature=adhoc' || true

if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q 'com.apple.developer'; then
  echo "error: restricted entitlements leaked into the ad-hoc build" >&2
  exit 1
fi

if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q 'get-task-allow'; then
  echo "error: get-task-allow survived the re-sign" >&2
  exit 1
fi

echo "==> Staging disk image"
DMG="$DIST/Pastable-$VERSION.dmg"
STAGE="$DIST/dmg-stage"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$DIST"
hdiutil create \
  -volname "Pastable" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG" >/dev/null

rm -rf "$STAGE"

echo "==> Verifying disk image"
MOUNT=$(mktemp -d /tmp/pastable-dmg.XXXXXX)
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" >/dev/null
codesign --verify --deep --strict "$MOUNT/Pastable.app"
[[ -L "$MOUNT/Applications" ]] || { echo "error: Applications link missing" >&2; exit 1; }
hdiutil detach "$MOUNT" >/dev/null
rmdir "$MOUNT"

echo "==> Done: $DMG ($(du -h "$DMG" | cut -f1))"
shasum -a 256 "$DMG"
