#!/usr/bin/env bash
#
# 逻辑层覆盖率：swift test --enable-code-coverage + llvm-cov。
# 报告写入 build/test-reports/coverage-*.txt，同时打印到终端。
#
#   ./tools/testing/coverage.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "== 运行带覆盖率插桩的测试 =="
swift test --enable-code-coverage

BIN="$(swift build --show-bin-path)/PastablePackageTests.xctest/Contents/MacOS/PastablePackageTests"
PROF="$(swift build --show-bin-path)/codecov/default.profdata"

if [[ ! -x "$BIN" ]]; then
  echo "找不到测试二进制：$BIN" >&2
  exit 1
fi
if [[ -z "${PROF:-}" || ! -f "$PROF" ]]; then
  echo "找不到覆盖率数据 default.profdata" >&2
  exit 1
fi

REPORT_DIR="$ROOT/build/test-reports"
mkdir -p "$REPORT_DIR"
OUT="$REPORT_DIR/coverage-$(date +%Y%m%d-%H%M%S).txt"

xcrun llvm-cov report "$BIN" \
  -instr-profile="$PROF" \
  -ignore-filename-regex='Tests/|\.build/' | tee "$OUT"

echo "覆盖率报告：$OUT"
