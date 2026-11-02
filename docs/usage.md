# 使用方式（Usage）

> 这一篇是**主文档**：从零到 Agent 能调到真实数据。
> 想理解平台内部原理请看 [architecture.md](architecture.md)。

---

## 0. 你需要准备什么

| 项 | 要求 |
|----|------|
| MCP 客户端 | Claude Desktop / Claude Code / Cursor / Cline / Windsurf / OpenClaw / 任意支持 MCP 的客户端 |
| 网络 | 能访问 `mcp.mcpcat.cn`（HTTPS 443，长连接不被中间设备掐断） |
| 账号 | 一个 MCPCat 账号（邮箱 + 密码，[注册](https://mcpcat.cn)） |
| 额度 | 新用户注册送 **100 MCoin**（¥1 = 100 MCoin） |

---

## 1. 注册并创建 API Key

1. 打开 <https://mcpcat.cn> 注册。
2. 进入控制台 →「API Key 管理」（`/console/keys`）→ **+ 创建 API Key**。
3. 起个能区分用途的名字（例如 `claude-desktop`、`prod-server`），设速率限制（默认 60 次/分钟）。
4. **立刻复制明文 Key**——平台只保存它的 SHA-256 哈希，明文只显示这一次，丢了只能重建。

Key 形态：

```
mcpc_sk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> 🔒 一个 Key 对应一个用途。生产环境、本地实验、演示机各给一个，出事只吊销那一个。

## 2. 勾选工具

控制台 →「工具市场」（`/console/tools`）勾选你要的能力。

- **新用户默认预勾** 6 个稳定的免费工具：`weather.area`、`weather.forecast15`、`dns_lookup`、`http_status_check`、`express.query`、`lottery.draw`。
- **完全不保存勾选配置 = 返回全部工具**（后端兜底行为），适合"先全都要"的场景。
- 勾选只影响 `tools/list` 的返回集合；`tools/call` 调未启用的工具会被拒。
- 按需勾选是有意义的：**工具越少，模型的上下文越干净，选错工具的概率越低。**

## 3. 配置客户端

标准连接参数就三个：

| 项 | 值 |
|----|----|
| Endpoint | `https://mcp.mcpcat.cn/v1/mcp` |
| Transport | `streamable-http`（MCP Streamable HTTP） |
| Auth | Header `Authorization: Bearer <MCPCAT_API_KEY>` |

### Claude Desktop / Claude Code

编辑 `claude_desktop_config.json`（macOS `~/Library/Application Support/Claude/`，Windows `%APPDATA%\Claude\`，Linux `~/.config/Claude/`）：

```json
{
  "mcpServers": {
    "mcpcat": {
      "type": "streamable-http",
      "url": "https://mcp.mcpcat.cn/v1/mcp",
      "headers": { "Authorization": "***" }
    }
  }
}
```

保存后重启客户端。

### Cursor

`Settings → Features → MCP → + Add New MCP Server`：

- Name：`mcpcat`
- Type：`http`
- URL：`https://mcp.mcpcat.cn/v1/mcp`
- Headers：`Authorization: Bearer ***`

或写入项目根的 `.cursor/mcp.json`（见 [examples/cursor.mcp.json](../examples/cursor.mcp.json)）。

### Cline / 其他 JSON 形态客户端

```json
{
  "mcpServers": {
    "mcpcat": {
      "url": "https://mcp.mcpcat.cn/v1/mcp",
      "type": "http",
      "headers": { "Authorization": "***" }
    }
  }
}
```

### OpenClaw

见 [examples/openclaw-mcp.json](../examples/openclaw-mcp.json)。

### 只支持 SSE 的老客户端

平台同时提供旧式 SSE 传输：

- 建立长连接：`GET /sse`
- 消息通道：`POST /messages`

把 `type` 改为 `sse`、URL 换成 `https://mcp.mcpcat.cn/sse` 尝试即可。**不支持自定义 Header 的客户端无法安全传 Key，建议换客户端**——把 Key 塞进 URL 查询串会被访问日志记录，不要这么干。

### 让 Agent 自己接

不想手动找配置文件？把 [examples/agent-prompt.md](../examples/agent-prompt.md) 里那段话复制给 Agent。平台也提供机器可读的接入说明：<https://mcpcat.cn/mcp-setup.md>（服务端热更新，是接入知识的唯一真相源）。

## 4. 验证连通

### 方式 A：原始 HTTP（不依赖客户端）

```bash
curl -sS -X POST https://mcp.mcpcat.cn/v1/mcp \
  -H "Authorization: Bearer $MCPCAT_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

返回工具列表 JSON = 接入成功。完整脚本见 [examples/raw-http.sh](../examples/raw-http.sh)。

### 方式 B：客户端里数工具

对 Agent 说"列出你现在能用的 MCP 工具"，看到 `weather.area` 之类的名字即通。

### 方式 C：真实调用一次免费工具

```bash
curl -sS -X POST https://mcp.mcpcat.cn/v1/mcp \
  -H "Authorization: Bearer $MCPCAT_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"weather.area","arguments":{"area":"北京"}}}'
```

## 5. 日常使用

- **直接问 Agent**：「杭州明天天气怎么样」「这条快递单号到哪了」。Agent 自己挑工具、自己填参数。
- **不要绕过 tools/list 猜工具名**。工具名是 Capability 名（点号或下划线风格，如 `weather.forecast15`、`http_status_check`），以 `tools/list` 实时返回为准。
- **参数有组合约束**。部分工具要求 `area` 或 `areaCode` 二选一、`startDate`+`endDate` 成对——这些约束写在 input schema 的 `anyOf`/`allOf` 里，正规 MCP 客户端会把它们交给模型，不需要人肉记忆。
- **控制台可看调用日志与余额**：哪次调用花了多少 MCoin、失败是否已退款，都在账上。

## 6. 计费与退款

MCoin 规则、单价档位、自动退款的判定条件见 [billing.md](billing.md)。一句话版：

> 收费工具按次扣 MCoin；**上游异常或返回空结果自动识别并退还**，不需要提工单。

## 7. 排错

| 现象 | 原因 | 处理 |
|------|------|------|
| `401` / `-32001 API Key 无效或已停用` | Key 错、被吊销、复制丢字符、Header 没带上 | 核对 `Authorization: Bearer <key>`；必要时重建 Key |
| `tools/list` 返回空或很少 | 工具市场未勾选对应工具 | 去 `/console/tools` 勾选并保存 |
| 连接建立但调用偶发失败 | 中间设备掐长连接 / 客户端把 204 通知当错误 | 换网络或更新客户端；平台侧通知响应为无 body 的 204 |
| 报"参数缺失/参数组合不合法" | 未满足 `anyOf`/`allOf` 约束 | 按 `tools/list` 返回的 schema 补全参数 |
| 提示 MCoin 不足 | 余额低于本次售价 | 控制台充值，或改用微信支付；会员有月度额度 |
| 上游业务报错（如 450） | 该接口本身有故障或超出数据范围 | 换同类工具；平台会把上游 `remark` 翻译成可读提示 |
| 只有 SSE 的客户端连不上 | 不支持自定义 Header | 无法安全传 Key，换客户端 |

**自查顺序**：`curl` 通不通 → Key 对不对 → 工具有没有勾 → 客户端配置格式对不对。前三步在平台侧，最后一步在客户端侧。

## 8. 安全

- Key 只进配置文件，不进仓库、不进日志、不进截图、不进公开 Issue。
- 泄露立即在控制台吊销。
- 建议：给不同环境发不同 Key，并按环境设不同的每分钟限额。
