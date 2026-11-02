# MCPCat · MCP 聚合平台

> **一个 MCP 端点，让 AI Agent 直接拿到实时世界的数据。**
> 本仓库**不含服务端代码**，定义的是平台的**产品边界、接入规范与使用方式**。

[![Website](https://img.shields.io/badge/website-mcpcat.cn-FF6B35?style=flat-square)](https://mcpcat.cn)
[![MCP](https://img.shields.io/badge/MCP-streamable--http-1A1A2E?style=flat-square)](https://modelcontextprotocol.io)
[![Spec](https://img.shields.io/badge/spec-v0.1-4ECDC4?style=flat-square)](docs/architecture.md)
[![License](https://img.shields.io/badge/docs-CC%20BY%204.0-lightgrey?style=flat-square)](LICENSE)

**在线服务** · [`https://mcp.mcpcat.cn/v1/mcp`](https://mcp.mcpcat.cn/v1/mcp) · [使用文档](docs/usage.md) · [平台规范](docs/architecture.md) · [Agent 接入指令](examples/agent-prompt.md)

---

## 这是什么

**MCPCat 是一个 MCP（Model Context Protocol）聚合网关**：把几十上百个异构数据源（天气、快递、行情、归属地、核验、出行……）聚合到**一个标准 MCP 端点**后面，供 AI Agent 直接调用。

一句话定位：**Agent 的数据接入层。**

```
   上游：几十家数据供应商，各家协议/鉴权/字段/计费都不一样
                       ↓  聚合 · 归一 · 计费 · 限流
   MCPCat 网关：一个 URL + 一个 Bearer Key + 一套 MCP 协议
                       ↓
   下游：Claude Desktop / Cursor / Cline / OpenClaw / 任意 MCP 客户端
```

## 为什么要有它

给 Agent 加一个真实数据能力，今天的成本是这样的：

| 痛点 | 自建 | MCPCat |
|------|------|--------|
| 买 API、申请配额、填身份证 | 每个数据源一次 | 0 次 |
| 写并维护一个 MCP Server | 每个数据源一个 | 0 个 |
| 跑一个常驻进程 / 公网服务 | 自己搭、自己保活 | 已经在线上 |
| 上游改字段、改鉴权 | 自己跟 | 平台侧吸收 |
| 输出格式不统一，模型看不懂 | 自己写映射 | 统一 JSON 结构 |
| 按结果付费 | 包月配额浪费 | 平台币按次，**失败自动退款** |

**结论：Agent 要的是"数据"，不是"运维一个 MCP Server"。** 所以平台把前者留下，把后者吃掉。

## 5 分钟接入

```jsonc
// 1. 在 https://mcpcat.cn 注册 → 控制台「API Key 管理」创建 Key（明文只显示一次）
// 2. 控制台「工具市场」勾选需要的工具（不勾选 = 返回全部工具）
// 3. 把下面这段贴进你的 MCP 客户端配置
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

不想手动改配置？把 [examples/agent-prompt.md](examples/agent-prompt.md) 里那段话复制给你正在用的 Agent，它自己找配置文件、自己写、自己验证。

## 平台边界（Definition of Product）

**平台做的：**

- **协议归一** — 完整 MCP `initialize` / `tools/list` / `tools/call`，JSON-RPC 2.0，Streamable HTTP
- **工具聚合** — 多供应商同类能力归入同一 Capability，按权重路由
- **输出归一** — JSONPath 映射 + 沙箱表达式，把五花八门的上游响应压成模型读得懂的结构
- **参数约束** — `required` / `anyOf` / `allOf` 组合约束写进 input schema，让模型能自己推导出正确调用
- **鉴权与配额** — API Key（仅存哈希）、按 Key 限流、按用户限流
- **计费与退款** — 平台币 MCoin 按次结算，上游异常/空结果自动退
- **错误友好化** — 上游报错翻译成人类可读提示回给 Agent，而不是丢一坨原始 JSON

**平台不做的：**

- ❌ 不做 MCP Server 目录 / 榜单（那是 registry，不是网关）
- ❌ 不代持用户的私有上游凭证对外复用
- ❌ 不做模型推理、不做 Agent 编排
- ❌ 不承诺上游 SLA —— 上游抖动由 failover 与自动退款兜底，不对外承诺金融级可用性

## 文档导航

| 文档 | 给谁看 | 内容 |
|------|--------|------|
| [docs/usage.md](docs/usage.md) | **要用的人** | 完整使用方式：注册 → Key → 勾选工具 → 各客户端配置 → 调用示例 → 排错 |
| [docs/architecture.md](docs/architecture.md) | 想理解原理的人 | 平台规范：Capability/Adapter/Provider 三层、输出映射、限流、计费链路、协议合规 |
| [docs/tool-catalog.md](docs/tool-catalog.md) | 找数据的人 | 数据域划分、免费工具清单、如何请求新工具 |
| [docs/billing.md](docs/billing.md) | 关心成本的人 | MCoin 规则、单价档位、退款条件 |
| [docs/roadmap.md](docs/roadmap.md) | 想看未来的人 | 五层能力演进 |
| [examples/](examples/) | 直接抄配置 | 各客户端 JSON、原始 HTTP 调用脚本、工具计数脚本 |

## 快速自查：现在到底有多少工具？

**本仓库刻意不写死工具数量**——写死就会过期。用这个自查：

```bash
export MCPCAT_API_KEY=***
bash examples/count-tools.sh
```

## 安全提示

> 🔒 API Key 是私密凭证。**不要**提交进公开仓库、贴进公开 Issue、写进截图或日志。
> 万一泄露：控制台立即吊销并新建。平台侧仅保存 Key 的 SHA-256 哈希，无法帮你找回明文。

## 许可与说明

- 本仓库文档采用 **CC BY 4.0**（署名即可自由引用/转载）。
- 服务端代码不在本仓库，不开源；平台服务按其线上服务条款提供。
- 文档里出现的工具名、价格、端点以线上实际返回为准，可能与某个快照不一致。

## 反馈

Issue 提在这儿：[mcpcat-platform/issues](https://github.com/haogegeya/mcpcat-platform/issues) —— 工具请求、文档纠错、接入踩坑都欢迎。
