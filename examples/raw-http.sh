#!/usr/bin/env bash
# 不依赖任何 MCP 客户端，用原始 HTTP 走一遍 MCP 握手 + 列工具 + 调工具
# 用法：export MCPCAT_API_KEY=*** && bash raw-http.sh [城市，默认 北京]
set -euo pipefail

KEY="${MCPCAT_API_KEY:-}"
AREA="${1:-北京}"
EP="${MCPCAT_ENDPOINT:-https://mcp.mcpcat.cn/v1/mcp}"

if [ -z "$KEY" ]; then
  echo "❌ 请先 export MCPCAT_API_KEY=<你的 Key>（控制台 /console/keys 创建）" >&2
  exit 1
fi

call() {
  curl -sS -m 30 -X POST "$EP" \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "$1"
}

echo "=== 1) initialize ==="
call '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"raw-http","version":"0.1"},"capabilities":{}}}'
echo

echo "=== 2) notifications/initialized（期望：HTTP 204，无 body）==="
code=$(curl -sS -m 30 -o /dev/null -w '%{http_code}' -X POST "$EP" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}')
echo "HTTP $code   （204 = 正常；200 带 {} 的写法会导致连接被服务端关闭）"
echo

echo "=== 3) tools/list ==="
call '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | head -c 800
echo " ..."
echo

echo "=== 4) tools/call → weather.area（免费工具，拿 $AREA 的区域编码）==="
call "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"weather.area\",\"arguments\":{\"area\":\"$AREA\"}}}"
echo

echo "=== 5) 负例：无效 Key（期望 401 / -32001）==="
curl -sS -m 30 -o /dev/null -w 'HTTP %{http_code}\n' -X POST "$EP" \
  -H "Authorization: Bearer mcpc_sk_invalid" -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{}}'
