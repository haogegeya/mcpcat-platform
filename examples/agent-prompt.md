# 给 Agent 的接入指令（复制粘贴用）

把下面 **一整段** 复制给你正在使用的 AI Agent（Claude / Cursor / Cline / OpenClaw / 任意支持工具调用的 Agent）。
它会自己找到配置文件、写入、验证，然后回来汇报。

---

## 复制这段给你的 Agent

```text
请帮我把 MCPCat 这个 MCP 服务接入到你自己的配置里，让用户可以直接调用它的实时数据工具。

服务端信息：
- 端点：https://mcp.mcpcat.cn/v1/mcp
- 传输：MCP Streamable HTTP（仅支持 SSE 的老客户端可尝试 type: "sse"）
- 鉴权：HTTP Header  Authorization: Bearer <MCPCAT_API_KEY>
- 平台接入说明（可读，含字段差异与验证方法）：https://mcpcat.cn/mcp-setup.md

请你按这个流程做，不要跳步：
1. 判断你运行在哪个客户端上，并确认该客户端 MCP 配置文件的真实路径与格式；
   不确定就先查该客户端官方文档，查不到就如实告诉我，不要凭猜测写文件。
2. 向我要 MCPCat 的 API Key（我没有就告诉我去哪儿创建：https://mcpcat.cn/console/keys）。
   Key 是私密凭证：只写进配置文件，不要输出到聊天、日志或截图里。
3. 合并写入配置：保留我已有的其他 MCP 服务器，只新增一个名为 mcpcat 的条目，
   严禁整体覆盖配置文件。注意不同客户端字段名差异（type/transport/protocol、headers/customHeaders）。
4. 验证连通：调用 tools/list 确认能返回工具列表（可用
   curl -X POST https://mcp.mcpcat.cn/v1/mcp -H "Authorization: Bearer <你的Key>" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'）。
5. 汇报：改了哪个文件、新增了什么、如何自行验证；并提醒我重启/刷新客户端让配置生效。
6. 最后告诉我：可以去控制台「工具市场」勾选需要的工具（不勾选时默认返回全部工具）。
```

---

## 如果 Agent 失败

| 现象 | 原因 | 处理 |
|------|------|------|
| Agent 说不确定配置文件路径 | 客户端太新/太小众 | 让它查官方文档；仍不确定就手动配置，见 [usage.md](../docs/usage.md#手动配置) |
| 401 `API Key 无效或已停用` | Key 错/被吊销/复制丢字符 | 控制台新建一个 Key，注意明文只显示一次 |
| 连上了但 `tools/list` 返回很少 | 工具市场没勾选 | 去 [工具市场](https://mcpcat.cn/console/tools) 勾选，或直接保存空配置以获得全部工具 |
| 只有 SSE 的客户端连不上 | 该客户端不支持自定义 Header | 无法安全传 Key，换用支持 Header 的客户端 |

## 手动配置（不通过 Agent）

各客户端的配置片段见 [examples/](.) 目录，逐字段说明见 [docs/usage.md](../docs/usage.md)。
