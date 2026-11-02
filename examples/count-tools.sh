#!/usr/bin/env bash
# 实时统计 MCPCat 当前可用工具数量与清单
# 用法：export MCPCAT_API_KEY=*** && bash count-tools.sh
set -euo pipefail

KEY="${MCPCAT_API_KEY:-}"
EP="${MCPCAT_ENDPOINT:-https://mcp.mcpcat.cn/v1/mcp}"

if [ -z "$KEY" ]; then
  echo "❌ 请先 export MCPCAT_API_KEY=***  （控制台 /console/keys 创建）" >&2
  exit 1
fi

resp() {
  curl -sS -m 30 -X POST "$EP" \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "$1"
}

echo "▶ endpoint : $EP"

# initialize —— 确认协议握手正常
ini=$(resp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"count-tools","version":"0.1"},"capabilities":{}}}')
echo "▶ initialize ok"
python3 - "$ini" <<'PY'
import json,sys
raw=sys.argv[1]
# streamable-http 可能返回 SSE 帧，取第一条 data:
line=[l[5:].strip() for l in raw.splitlines() if l.startswith("data:")] or [raw]
try:
    payload=json.loads(line[0])
except Exception:
    print("  ❌ 无法解析响应：", raw[:200]); raise SystemExit(1)
if "error" in payload:
    print("  ❌", payload["error"]); raise SystemExit(1)
d=payload.get("result",{})
print("  protocol :", d.get("protocolVersion"))
print("  server   :", d.get("serverInfo",{}).get("name"), d.get("serverInfo",{}).get("version"))
print("  caps     :", ",".join(d.get("capabilities",{}).keys()))
PY

# tools/list —— 数工具
lst=$(resp '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
python3 - "$lst" <<'PY'
import json,sys,re
raw=sys.argv[1]
line=[l[5:].strip() for l in raw.splitlines() if l.startswith("data:")] or [raw]
payload=json.loads(line[0])
if "error" in payload:
    print("❌", payload["error"]); raise SystemExit(1)
tools=payload["result"]["tools"]
print(f"\n✅ 当前账号可用工具：{len(tools)} 个\n")
by_prefix={}
for t in tools:
    n=t["name"]
    key=re.split(r"[._-]", n, maxsplit=1)[0].lower()
    by_prefix.setdefault(key,[]).append(n)
print("按域分布：")
for k,v in sorted(by_prefix.items(), key=lambda x:-len(x[1])):
    print(f"  {k:<12} {len(v):>3}")
print("\n前 15 个工具：")
for t in tools[:15]:
    desc=(t.get("description") or "").replace("\n"," ")[:60]
    print(f"  - {t['name']:<28} {desc}")
if len(tools)>15: print(f"  ... 其余 {len(tools)-15} 个见完整输出")
PY

echo
echo "提示：数量为 0 或偏少 → 去控制台「工具市场」勾选工具；从未保存过勾选配置时返回全部工具。"
