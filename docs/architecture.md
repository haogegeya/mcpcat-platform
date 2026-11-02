# 平台规范（Architecture & Spec）

> 定义 MCPCat **是什么、边界在哪、按什么规则办事**。
> 本文是产品设计说明，不含服务端实现代码。术语以本文为准。

---

## 1. 定位

**MCPCat = Agent 的数据接入层。**

一个 MCP 端点，后面挂着多供应商、多协议、多字段的数据源。Agent 只需要知道"有一个端点、一个 Key、一批工具"。

平台的价值判断只有一条：**把接入成本留在平台侧，把数据交付给 Agent 侧。**

## 2. 三层模型：Capability / Adapter / Provider

这是平台的核心抽象，也是"聚合"二字的具体含义。

```
Capability（能力）        ← Agent 看到的工具。稳定契约：名字、描述、统一入参 schema、统一出参
  └── Adapter（适配器）   ← 把某个供应商的接口翻译成 Capability 契约
        └── Provider（供应商）← 真实上游 API 账号与配额
```

| 层 | 面向谁 | 变更影响 |
|----|--------|----------|
| Capability | Agent / 模型 | 对外契约，**不可随意改名或改参数语义** |
| Adapter | 平台内部 | 换供应商、调字段映射，Agent 无感 |
| Provider | 平台内部 | 换 Key、换配额、改鉴权，Agent 无感 |

**三层 Adapter 接入模式**（按接入成本分档）：

1. **零配置** — 平台侧已有可用上游凭证，用户勾上就能用。绝大多数工具属于这类。
2. **认证模板** — 用户填自己的上游凭证（如自有 showapi AppCode），平台套用现成模板。适合"数据源是你的、配额是你的"。
3. **自定义** — 用户自带 MCP Server 或私有 HTTP 接口，平台做转发与归一。适合已有内部系统。

设计后果：**换一个上游供应商，是一次数据库变更 + 一次映射调整，不是一次发布。** 上游抖动、涨价、下架，都不该传导到 Agent 侧。

## 3. 路由与主备

- 一个 Capability 可挂多个 Adapter，各带 `provider_weight`。
- 加载顺序显式化：`ORDER BY provider_weight DESC, id ASC` 保证主源确定性，**不依赖数据库返回顺序**；权重并列取先注册者（id 小者优先）。
- `pinned` / `primary_failover` 是路由策略位，用于把某 Capability 钉死到指定 Adapter。
- 真 failover + 上游健康探测：**规划中**，接第二个供应商前完成（见 [roadmap.md](roadmap.md)）。

## 4. 输入契约：让模型能自己推导出正确调用

平台对 input schema 有一条硬要求：**参数之间的组合关系必须写进 schema，不能只写在 description 里。**

- `required`：无脑必填的字段。
- `anyOf`：二选一（例：`area` 与 `areaCode` 至少给一个）。
- `allOf`：条件成对（例：`startDate` 出现则 `endDate` 必须出现）。

两个曾经踩过的坑，作为设计约束固定下来：

1. **schema 必须全链路透传。** 数据库里写了 `anyOf`，如果注册层只取 `properties`/`required`、`tools/list` 拼装又只取这两项，约束就被**静默丢弃**——模型表现为反复用错误参数组合试探。协议模型 `extra=allow` + 注册层完整透传 + `tools/list` 全量输出，三处缺一不可。
2. **约束缺失就是产品缺陷。** 历史上 153 个 Capability 里 43 个 `required=[]`，上游直接报参数错误；用户连续失败 5 次后流失。错误友好化只是止血，schema 补约束才是治本。

## 5. 输出契约：归一化

上游响应五花八门（嵌套 `obj`、字符串数字、中文键名、业务错误码藏在 `remark` 里）。平台统一做两件事：

- **JSONPath 映射** — 把上游字段搬到 Capability 定义的标准字段上。
- **沙箱表达式** — 简单转换（拼接、单位换算、条件默认值）在沙箱里执行，不改代码。

对模型的目标是：**返回可读、结构化、无冗余包装的 JSON。**

**错误翻译**：上游业务错误不原样抛给 Agent。平台从上游响应里提取人类可读提示（如 showapi 的 `remark`）回传，模型据此决定换参数还是换工具，而不是拿到一坨堆栈。

## 6. 协议合规（MCP）

### 传输

| 模式 | 端点 | 说明 |
|------|------|------|
| Streamable HTTP | `POST /v1/mcp` | 主用法，JSON-RPC 请求/响应 |
| Streamable HTTP | `GET /v1/mcp` | server→client SSE 流 |
| 旧式 SSE | `GET /sse` + `POST /messages` | 兼容只支持 SSE 的客户端 |

`Accept` 建议同时带 `application/json, text/event-stream`。

### 方法与支持矩阵

| 方法 | 行为 |
|------|------|
| `initialize` | 返回 `protocolVersion`（协商值，缺省 `2024-11-05`）、`capabilities`、`serverInfo` |
| `notifications/initialized` | **无 body 的 204**（见下方硬规则） |
| `tools/list` | 返回该用户已启用工具；**未配置勾选时返回全部工具** |
| `tools/call` | 鉴权 → 限流 → 计费 → 路由上游 → 归一化输出 |
| `resources/list` / `prompts/list` | 返回**空列表**而非报错，避免客户端整页崩 |
| `logging/setLevel` | 接收并返回空结果（当前不做实际处理） |
| `ping` | 返回空结果 |
| 其他 `notifications/*` | 一律不响应 |

### 协议实现硬规则（踩坑固化）

> **204 / 304 响应禁止携带 body。**

曾为此付出代价：通知类请求写成 `JSONResponse(content={}, status_code=204)`，starlette 对 204 不生成 `Content-Length` 但仍渲染出 `b"{}"`，uvicorn 发送时抛 `RuntimeError: Response content longer than Content-Length` 并**强制关闭该 TCP 连接**——每次 MCP 握手必现，客户端表现为偶发调用失败。10 天累计 1167 次。

改法：通知返回 `Response(status_code=204)`，body 长度 0。

**排障教训**：uvicorn 访问日志打在响应头阶段，"204 日志"与"异常堆栈"并存是同一请求的假象；要靠 1:1 计数对照发现真相，不要凭一条日志下结论。

### 鉴权

- `Authorization: Bearer <API Key>`（仅存哈希，明文不可恢复）。
- 匿名 / 无效 Key：HTTP `401`，JSON-RPC 错误码 `-32001`，message `API Key 无效或已停用`。
- 控制台侧另有 JWT 登录态；MCP 端点只认 API Key。

## 7. 限流（五层）

| 层 | 恒定？ | 作用 |
|----|--------|------|
| IP | 恒定 | 挡无脑扫射 |
| Key | 恒定 | 单 Key 限额，创建时可设 |
| User | 恒定 | 单用户总量 |
| Capability | 用户节流 | 默认 60/min，钉在能力上，**不随上游路由漂移** |
| Adapter | 全平台共享 | 保护上游配额，防止把供应商账号打爆 |

实现约束：**`max_per_min <= 0` 不得跳过 IP/Key/User 层**（历史实现有此隐患，已修）。分层目的不是限制用户，而是**避免一个脚本把上游配额和数据库一起打穿**。

## 8. 计费链路

```
tools/call → 鉴权 → 限流 → 扣费预检（MCoin + 会员月度额度混合）
   → 路由上游 → 输出归一 → 结果判定 → 正常扣 / 异常自动退 → 写 call log
```

- 货币：**MCoin**，¥1 = 100 MCoin，注册送 100。
- 售价 `sell_mcoin`，成本 `cost_mcoin`。**价格防呆**：收费工具（`sell>0`）保存时校验售价 ≥ 成本；`sell=0` 视为免费补贴策略放行。
- 退款判定：上游异常 / 返回空结果 → 自动退还，不需要工单。
- 订单生命周期 7 态：`pending → paid → success / failed / refunded / canceled / expired`。超 2 小时未付自动过期（定时任务扫描 + Redis 延迟队列双保险，每分钟一次）。
  - 教训：时间比较**交给数据库** `DATE_SUB(NOW())`，别让应用和 MySQL 各按自己时区算——曾因此误判过期。

详细规则见 [billing.md](billing.md)。

## 9. 数据与运行时

| 组件 | 选型 | 备注 |
|------|------|------|
| 网关 | FastAPI（Python） | JSON-RPC over HTTP |
| 控制台 | Next.js 14（App Router） | 注册 / Key / 工具市场 / 账单 |
| 数据库 | MySQL 8 | Capability/Adapter/Provider、用户、Key 哈希、订单、调用日志 |
| 缓存与限流 | Redis | 计数 + 延迟队列 |
| 部署 | 单机 systemd + nginx | 生产环境独立于本仓库 |

**运维红线**（都是真金白银换来的）：

- 排障看 **journald 最新错误**，不要追陈旧的 `/tmp/*.log`。
- 生产的 `.service` 文件因机器而异，**不从 git 推**。
- `configs/production.py` 里 `DB_PASSWORD=""` 是**安全设计**，真实值由 systemd `EnvironmentFile` 注入。
- MySQL 8 必须显式建 `root@127.0.0.1`。
- `config.validate()` 的 required 列表要与 `production.env` 同步，否则漏检。
- 部署前跑 secret 预检；前端本地 build 后推 `.next`，不在服务器构建。

## 10. 规模口径（避免文档过期）

本仓库**刻意不写死工具数量**。历史上不同口径并存，容易误导：

| 口径 | 含义 | 量级（2026-09 快照） |
|------|------|----------------------|
| 平台已注册 Capability | 数据库里的全部能力 | 百级（~150） |
| 已启用 Adapter | 有可用上游适配的能力 | 数十级 |
| `tools/list` 实际返回 | 该用户当前可调 | 取决于勾选，默认全量（~136） |
| 官网 `/tools` SEO 页 | 已生成独立页面的工具 | 逐批增长 |

**唯一可信来源是实时 `tools/list`。** 用 [examples/count-tools.sh](../examples/count-tools.sh) 自查。

## 11. 边界与非目标

平台**不做**：MCP Server 目录/榜单（那是 registry）、代持用户私有上游凭证对外复用、模型推理、Agent 编排、对外承诺金融级 SLA。

平台**接受**的取舍：上游质量参差 → 用"失败自动退款 + 错误友好化 + 同类工具多 Adapter"来对冲，而不是承诺不可能兑现的可用性。
