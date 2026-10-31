#!/usr/bin/env bash
#
# Pastable 自动化测试入口。
#
#   ./tools/testing/run-tests.sh                # 逻辑层全量回归（swift test）
#   ./tools/testing/run-tests.sh --repeat 3     # 连跑 3 轮，检查用例稳定性
#   ./tools/testing/run-tests.sh --smoke        # 额外构建 Debug App 并做启动冒烟
#   ./tools/testing/run-tests.sh --e2e          # 额外跑真实 UI 端到端体验测试
#
# 日志写入 build/test-reports/，失败时返回非 0。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

REPEAT=1
SMOKE=0
E2E=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repeat)
      REPEAT="${2:-}"
      shift 2
      ;;
    --smoke)
      SMOKE=1
      shift
      ;;
    --e2e)
      E2E=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$REPEAT" =~ ^[1-9][0-9]*$ ]]; then
  echo "--repeat 需要一个正整数" >&2
  exit 2
fi

REPORT_DIR="$ROOT/build/test-reports"
mkdir -p "$REPORT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
UNIT_LOG="$REPORT_DIR/unit-$STAMP.log"

echo "== 逻辑层回归：swift test（$REPEAT 轮） =="
for run in $(seq 1 "$REPEAT"); do
  echo "-- run $run/$REPEAT"
  swift test 2>&1 | tee -a "$UNIT_LOG"
done

SUMMARY="$(grep -E "Executed [0-9]+ tests, with [0-9]+ failures" "$UNIT_LOG" | tail -1)"
if [[ -z "$SUMMARY" ]]; then
  echo "未能从日志中解析测试结果，见 $UNIT_LOG" >&2
  exit 1
fi
echo "$SUMMARY"
if [[ "$SUMMARY" != *"with 0 failures"* ]]; then
  echo "逻辑层测试失败，见 $UNIT_LOG" >&2
  exit 1
fi

if [[ "$SMOKE" -eq 1 ]]; then
  BUILD_LOG="$REPORT_DIR/build-$STAMP.log"
  SMOKE_LOG="$REPORT_DIR/smoke-$STAMP.log"

  echo "== Xcode 工程构建 =="
  xcodebuild -project Pastable.xcodeproj \
    -scheme Pastable \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath /tmp/PastableDerived \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tee "$BUILD_LOG" | tail -5

  if ! grep -q "BUILD SUCCEEDED" "$BUILD_LOG"; then
    echo "构建失败，见 $BUILD_LOG" >&2
    exit 1
  fi

  echo "== 启动冒烟 =="
  "$ROOT/tools/testing/smoke-launch.sh" \
    /tmp/PastableDerived/Build/Products/Debug/Pastable.app | tee "$SMOKE_LOG"
fi

if [[ "$E2E" -eq 1 ]]; then
  E2E_LOG="$REPORT_DIR/e2e-$STAMP.log"
  echo "== 端到端体验测试（会短暂打开窗口并占用前台） =="
  if ! "$ROOT/tools/testing/e2e/run.sh" 2>&1 | tee "$E2E_LOG"; then
    echo "端到端测试出现非预期失败，见 $E2E_LOG" >&2
    exit 1
  fi
fi

echo "完成。日志目录：$REPORT_DIR"
