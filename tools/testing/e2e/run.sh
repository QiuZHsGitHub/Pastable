#!/usr/bin/env bash
#
# 端到端体验自动化：真实启动 App、驱动辅助功能树、截图并计时。
# 使用独立的 bundle id（com.qzh.Pastable.e2e）与临时 SwiftData 库，
# 不读写用户的真实历史、偏好或剪贴板（结束时恢复）。
#
#   ./tools/testing/e2e/run.sh
#
# 需要：已登录的 macOS 会话、Xcode、辅助功能权限、屏幕录制权限。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

BUNDLE_ID="com.qzh.Pastable.e2e"
DERIVED="/tmp/PastableE2E"
APP="$DERIVED/Build/Products/Debug/Pastable.app"
APP_BIN="$APP/Contents/MacOS/Pastable"
FIXTURE="/tmp/PastableE2EFixture"
RUNNER="/tmp/PastableE2ERunner"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARTIFACTS="$ROOT/build/test-reports/e2e-$STAMP"
mkdir -p "$ARTIFACTS"

cleanup() {
  pkill -f "$APP_BIN" 2>/dev/null || true
  pkill -f "$FIXTURE" 2>/dev/null || true
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
echo "== 构建 E2E App（$BUNDLE_ID） =="
if ! xcodebuild -project Pastable.xcodeproj \
  -scheme Pastable \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  build >"$ARTIFACTS/build.log" 2>&1; then
  tail -20 "$ARTIFACTS/build.log" >&2
  echo "构建失败，日志：$ARTIFACTS/build.log" >&2
  exit 1
fi
grep -q "BUILD SUCCEEDED" "$ARTIFACTS/build.log"
ACTUAL_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
if [[ "$ACTUAL_ID" != "$BUNDLE_ID" ]]; then
  echo "bundle id 不符合预期：$ACTUAL_ID" >&2
  exit 1
fi

echo "== 编译文档夹具与测试驱动 =="
swiftc -O tools/testing/e2e/Fixture/main.swift \
  -o "$FIXTURE" -framework AppKit >"$ARTIFACTS/fixture-build.log" 2>&1
swiftc -O tools/testing/e2e/main.swift \
  -o "$RUNNER" -framework AppKit -framework ApplicationServices -framework CoreGraphics \
  >"$ARTIFACTS/runner-build.log" 2>&1

echo "== 运行端到端体验用例 =="
set +e
"$RUNNER" "$APP_BIN" "$FIXTURE" "$ARTIFACTS" "$BUNDLE_ID"
STATUS=$?
set -e

echo
echo "报告与截图：$ARTIFACTS"
ls -1 "$ARTIFACTS" | sed 's/^/  /'
exit "$STATUS"
