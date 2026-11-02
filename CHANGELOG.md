# 更新日志

格式：`Keep a Changelog` 风格，按日期倒序。仅记录**文档与规范**变更；服务端变更见线上控制台。

## v0.1 — 2026-11-03

仓库建立。定义平台边界与使用方式，**不含服务端代码**。

- `README.md` — 平台定义：MCP 聚合平台 / Agent 数据接入层；痛点对照表；平台边界（做与不做）
- `docs/usage.md` — 主使用文档：注册 → API Key → 勾选工具 → 5 类客户端配置 → 3 种连通验证 → 排错表
- `docs/architecture.md` — 平台规范：Capability/Adapter/Provider 三层、输入契约（anyOf/allOf 透传）、输出归一、MCP 方法支持矩阵、204 无 body 硬规则、五层限流、计费链路、运维红线、规模口径
- `docs/tool-catalog.md` — 数据域划分（7 域）、免费层定位、工具请求规范、覆盖范围之外
- `docs/billing.md` — MCoin 规则、售价防呆、失败自动退款判定、7 态订单、成本估算法
- `docs/roadmap.md` — 五层能力模型 + 工程前置约束（failover / 出参统一 / schema 覆盖率）
- `examples/` — Claude Desktop / Cursor / Cline / OpenClaw 配置片段；`raw-http.sh` 全链路手测；`count-tools.sh` 实时工具计数；`agent-prompt.md` 给 Agent 的自助接入指令
- `CONTRIBUTING.md`、`LICENSE`（文档 CC BY 4.0）

### 设计决策

- **文档不写死工具数量**：历史上"153 Capability / 136 返回 / 12 官网"三个口径并存且都会过期，统一改为指向实时 `tools/list`。
- **明确不做 MCP Server 目录/榜单**：与"数据接入层"定位冲突。
- 与旧仓库 `haogegeya/mcpcat-docs`（详细分篇文档站）并存：那个是文档站源码，本仓库是平台定义与接入规范。
