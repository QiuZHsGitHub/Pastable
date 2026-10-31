#!/usr/bin/env bash
#
# 启动冒烟：用临时数据库目录启动 Debug 版 Pastable，确认进程存活、存储初始化
# 完成，然后退出。不会打开浮动面板，也不会触碰真实剪贴板历史。
#
#   ./tools/testing/smoke-launch.sh [/path/to/Pastable.app]
#
# 退出码 0 = 通过。

set -euo pipefail

APP="${1:-/tmp/PastableDerived/Build/Products/Debug/Pastable.app}"
BIN="$APP/Contents/MacOS/Pastable"

if [[ ! -x "$BIN" ]]; then
  echo "找不到可执行文件：$BIN" >&2
  echo "请先运行：xcodebuild -project Pastable.xcodeproj -scheme Pastable -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/PastableDerived CODE_SIGNING_ALLOWED=NO build" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/PastableSmoke.XXXXXX")"
LOG="$WORK/launch.log"
PID=""

cleanup() {
  if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    kill -TERM "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  if [[ "$WORK" == "${TMPDIR:-/tmp}"/PastableSmoke.* ]]; then
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT

echo "启动：$BIN"
echo "临时存储：$WORK"
PASTABLE_STORAGE_DIR="$WORK" "$BIN" >"$LOG" 2>&1 &
PID=$!

# 最多等 10 秒，等 SwiftData 建库。
for _ in $(seq 1 40); do
  if [[ -f "$WORK/Storage.sqlite" ]]; then
    break
  fi
  if ! kill -0 "$PID" 2>/dev/null; then
    echo "FAIL：进程提前退出" >&2
    cat "$LOG" >&2
    exit 1
  fi
  sleep 0.25
done

if [[ ! -f "$WORK/Storage.sqlite" ]]; then
  echo "FAIL：10 秒内没有创建 Storage.sqlite" >&2
  cat "$LOG" >&2
  exit 1
fi

# 再观察一会儿，确认不是创建数据库后立刻崩溃。
sleep 1
if ! kill -0 "$PID" 2>/dev/null; then
  echo "FAIL：初始化后进程退出" >&2
  cat "$LOG" >&2
  exit 1
fi

if grep -qE "Fatal error|fatal error|crash|Trace/BPT trap" "$LOG"; then
  echo "FAIL：日志中出现崩溃关键字" >&2
  cat "$LOG" >&2
  exit 1
fi

SIZE="$(stat -f%z "$WORK/Storage.sqlite" 2>/dev/null || echo 0)"
kill -TERM "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
PID=""

echo "PASS：启动成功，Storage.sqlite 已创建（${SIZE} bytes），进程存活检查通过"
