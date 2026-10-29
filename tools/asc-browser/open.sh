#!/usr/bin/env bash
# 打开「独立配置」的 Chrome,指向 App Store Connect。
#   用法: ./open.sh [初始URL]
# 幂等:实例已在运行时只复用/聚焦已有标签页,不会重复启动。
# 环境变量: ASC_PROFILE_DIR(默认 ~/.pastable-asc-profile)、ASC_CDP_PORT(默认 9223)
set -euo pipefail

PROFILE="${ASC_PROFILE_DIR:-$HOME/.pastable-asc-profile}"
PORT="${ASC_CDP_PORT:-9223}"
URL="${1:-https://appstoreconnect.apple.com/apps}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"

[ -x "$CHROME" ] || { echo "未找到 Google Chrome: $CHROME" >&2; exit 1; }

cd "$DIR"

if curl -sf "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1; then
  echo "✔ 独立配置 Chrome 已在运行 (CDP :$PORT),复用现有实例。"
else
  echo "→ 启动独立配置 Chrome (profile: $PROFILE, CDP :$PORT) ..."
  mkdir -p "$PROFILE"
  nohup "$CHROME" \
    --user-data-dir="$PROFILE" \
    --remote-debugging-port="$PORT" \
    --remote-allow-origins='*' \
    --no-first-run \
    --no-default-browser-check \
    --window-size=1440,900 \
    "$URL" >/dev/null 2>&1 &
  disown || true

  for _ in $(seq 1 40); do
    if curl -sf "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1; then
      echo "✔ Chrome 已就绪。"
      break
    fi
    sleep 0.5
  done
  curl -sf "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1 || {
    echo "✘ Chrome 的调试端口 :$PORT 未响应。若该 profile 正被别的方式占用,请先退出该实例。" >&2
    exit 1
  }
fi

# 打开/聚焦 App Store Connect 页(复用已有标签,避免开一堆重复页)
node "$DIR/drive.mjs" open "$URL" >/dev/null 2>&1 || true
echo
echo "浏览器窗口已弹出。请在窗口里登录 App Store Connect(两步验证只做这一次)。"
echo "登录后,agent 用 drive.mjs 即可替你操作页面: node $DIR/drive.mjs snapshot"
