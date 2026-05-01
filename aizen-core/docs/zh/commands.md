# 命令参考

本页按使用场景整理 Aizen CLI，目标是让你先找到正确命令，再去看更细的输出。

`aizen help` 提供的是顶层摘要；本页与其保持对齐，并继续展开到子命令与注意事项。

## 页面导航

- 这页适合谁：已经准备使用 CLI，但还不确定命令名、子命令或常见入口的人。
- 看完去哪里：首次配置看 [配置指南](./configuration.md)；日常运行和排障看 [使用与运维](./usage.md)；如果你在改 CLI 或文档，去 [开发指南](./development.md)。
- 如果你是从某页来的：从 [README](./README.md) 来，可先看“先看这几条”；从 [安装指南](./installation.md) 来，通常下一步是 `onboard`、`agent` 和 `gateway`；从 [开发指南](./development.md) 来，请把本页当作 CLI 行为和示例索引。

## 先看这几条

- 看总帮助：`aizen help`
- 看版本：`aizen version` 或 `aizen --version`
- 首次初始化：`aizen onboard --interactive`
- 单条对话验证：`aizen agent -m "hello"`
- 长期运行：`aizen gateway`

## 初始化与交互

| 命令 | 说明 |
|---|---|
| `aizen help` | 显示顶层帮助 |
| `aizen version` / `aizen --version` | 查看 CLI 版本 |
| `aizen onboard --interactive` | 交互式初始化配置 |
| `aizen onboard --api-key sk-... --provider openrouter` | 快速写入 provider 与 API Key |
| `aizen onboard --api-key ... --provider ... --model ... --memory ...` | 一次性指定 provider、model、memory backend |
| `aizen onboard --channels-only` | 只重配 channel / allowlist |
| `aizen agent -m "..."` | 单条消息模式 |
| `aizen agent` | 交互会话模式 |

### 交互式模型路由

- 在 `aizen agent` 里，`/model` 会显示当前模型以及已配置的路由/回退状态。
- `/config reload` 会热重载 `config.json` 中支持的配置项（包括 Agent Profile 的更新）。
- 如果配置了自动路由，`/model` 还会显示最近一次自动路由决策以及选择原因。
- 如果某条自动路由命中的提供方暂时被限流或额度耗尽，`/model` 会把这条路线标成 degraded，直到冷却结束。
- `/model` 还会列出已配置的自动路由及其 `cost_class`、`quota_class` 元数据。
- `/model <provider/model>` 会把当前会话 pin 到该模型，并关闭自动路由。
- `/model auto` 会清除这个用户 pin，把会话恢复到配置里的默认模型，并让后续回合重新使用 `model_routes`。
- 如果没有配置 `model_routes`，`/model auto` 仍然会清除 pin，并把会话切回配置里的默认模型。
- 通过 `--model` 或 `--provider` 启动 `aizen agent` 时，也会把该次运行 pin 到显式模型，从而绕过 `model_routes`。

## 运行与运维

| 命令 | 说明 |
|---|---|
| `aizen gateway` | 启动长期运行 runtime，默认读取配置中的 host/port |
| `aizen gateway --port 8080` | 用 CLI 覆盖网关端口 |
| `aizen gateway --host 0.0.0.0 --port 8080` | 用 CLI 覆盖监听地址与端口 |
| `aizen service install` | 安装后台服务 |
| `aizen service start` | 启动后台服务 |
| `aizen service stop` | 停止后台服务 |
| `aizen service restart` | 重启后台服务 |
| `aizen service status` | 查看后台服务状态 |
| `aizen service uninstall` | 卸载后台服务 |
| `aizen status [--json]` | 查看全局状态总览，或输出 machine-readable runtime snapshot |
| `aizen doctor` | 执行系统诊断 |
| `aizen update --check` | 仅检查是否有更新 |
| `aizen update --yes` | 自动确认并安装更新 |
| `aizen auth login openai-codex` | 为 `openai-codex` 做 OAuth 登录 |
| `aizen auth login openai-codex --import-codex` | 从 `~/.codex/auth.json` 导入登录态 |
| `aizen auth status openai-codex` | 查看认证状态 |
| `aizen auth logout openai-codex` | 删除本地认证信息 |

说明：

- `auth` 目前只支持 `openai-codex`。
- `gateway` 只是覆盖 host/port，其他安全策略仍以配置文件为准。

## 渠道、任务与扩展

### Channel

| 命令 | 说明 |
|---|---|
| `aizen channel list [--json]` | 列出已知 / 已配置渠道 |
| `aizen channel start` | 启动默认可用渠道 |
| `aizen channel start telegram` | 启动指定渠道 |
| `aizen channel status` | 查看渠道健康状态 |
| `aizen channel info <type> [--json]` | 查看某类渠道的已配置账号 |
| `aizen channel add <type>` | 提示如何往配置里添加某类渠道 |
| `aizen channel remove <name>` | 提示如何从配置里移除渠道 |

### Cron

| 命令 | 说明 |
|---|---|
| `aizen cron list [--json]` | 查看所有计划任务 |
| `aizen cron status [--json]` | 查看 scheduler 层状态与任务计数 |
| `aizen cron add "0 * * * *" "command"` | 新增周期性 shell 任务 |
| `aizen cron add-agent "0 * * * *" "prompt" --model <model> [--announce] [--channel <name>] [--account <id>] [--to <id>]` | 新增周期性 agent 任务 |
| `aizen cron once 10m "command"` | 新增一次性延迟任务 |
| `aizen cron once-agent 10m "prompt" --model <model>` | 新增一次性 agent 延迟任务 |
| `aizen cron run <id>` | 立即执行指定任务 |
| `aizen cron pause <id>` / `resume <id>` | 暂停 / 恢复任务 |
| `aizen cron remove <id>` | 删除任务 |
| `aizen cron runs <id>` | 查看任务最近执行记录 |
| `aizen cron update <id> --expression ... --command ... --prompt ... --model ... --enable/--disable` | 更新已有任务 |

### Skills

| 命令 | 说明 |
|---|---|
| `aizen skills list` | 列出已安装 skill |
| `aizen skills install <source>` | 从 Git URL、本地路径或 HTTPS well-known skill 端点安装 skill |
| `aizen skills install --name <query>` | 在 skill registry 中搜索并安装最匹配的 skill |
| `aizen skills remove <name>` | 移除 skill |
| `aizen skills info <name>` | 查看 skill 元信息 |

### History

| 命令 | 说明 |
|---|---|
| `aizen history list [--limit N] [--offset N] [--json]` | 列出会话记录 |
| `aizen history show <session_id> [--limit N] [--offset N] [--json]` | 查看指定会话的消息详情 |

## 数据、模型与工作区

### Memory

| 命令 | 说明 |
|---|---|
| `aizen memory stats` | 查看当前 memory 配置与关键计数 |
| `aizen memory count` | 查看总条目数 |
| `aizen memory reindex` | 重建向量索引 |
| `aizen memory search "query" --limit 10` | 执行检索 |
| `aizen memory get <key>` | 查看单条 memory |
| `aizen memory list --category task --limit 20` | 按分类列出 memory |
| `aizen memory drain-outbox` | 清空 durable vector outbox 队列 |
| `aizen memory forget <key>` | 删除一条 memory |

### Workspace / Capabilities / Models / Migrate

| 命令 | 说明 |
|---|---|
| `aizen workspace edit AGENTS.md` | 用 `$EDITOR` 打开 bootstrap 文件 |
| `aizen workspace reset-md --dry-run` | 预览将要重置的 markdown prompt 文件 |
| `aizen workspace reset-md --include-bootstrap --clear-memory-md` | 重置 bundled markdown，并可附带清理 bootstrap / memory 文件 |
| `aizen capabilities` | 输出运行时能力摘要 |
| `aizen capabilities --json` | 输出 JSON manifest |
| `aizen config show [--json]` | 输出完整的磁盘配置 |
| `aizen config get <path> [--json]` | 读取一条 dotted config 值 |
| `aizen models list` | 列出 provider 与默认模型 |
| `aizen models info <model>` | 查看模型说明 |
| `aizen models summary [--json]` | 输出供集成侧使用的 provider/key-safe 管理摘要 |
| `aizen models benchmark` | 运行模型延迟基准 |
| `aizen models refresh` | 刷新模型目录 |
| `aizen migrate openclaw --dry-run` | 预演迁移 OpenClaw |
| `aizen migrate openclaw --source /path/to/workspace` | 指定源工作区路径迁移 |

说明：

- `workspace edit` 只适用于 file-based backend（如 `markdown`、`hybrid`）。
- 如果当前 memory backend 把 bootstrap 数据放在数据库里，CLI 会提示改用 agent 的 `memory_store` 工具，或切回 file-based backend。
- 这些带 `--json` 的 read-side 命令主要用于自动化集成，以及 AizenDashboard 对 managed instance 的 admin API 边界。

## 硬件与自动化集成

| 命令 | 说明 |
|---|---|
| `aizen hardware scan` | 扫描已连接硬件 |
| `aizen hardware flash <firmware_file> [--target <board>]` | 烧录固件（当前输出提示，尚未完整实现） |
| `aizen hardware monitor` | 监控硬件（当前输出提示，尚未完整实现） |

## 顶层 machine-facing flags

这组入口更偏自动化、集成、探针，不是普通用户的第一阅读路径：

| 命令 | 说明 |
|---|---|
| `aizen --export-manifest` | 导出 manifest |
| `aizen --list-models` | 列出模型信息 |
| `aizen --probe-provider-health` | 探测 provider 健康状态 |
| `aizen --probe-channel-health` | 探测 channel 健康状态 |
| `aizen --from-json` | 从 JSON 输入执行特定流程 |

## 推荐的日常排查顺序

1. `aizen doctor`
2. `aizen status`
3. `aizen channel status`
4. `aizen agent -m "self-check"`
5. 如涉及网关，再执行 `curl http://127.0.0.1:3000/health`

## 下一步

- 要把命令真正跑起来：继续看 [配置指南](./configuration.md) 和 [使用与运维](./usage.md)。
- 要部署长期运行：继续看 [使用与运维](./usage.md) 和 [Gateway API](./gateway-api.md)。
- 要修改命令实现或补测试：继续看 [开发指南](./development.md) 和 [架构总览](./architecture.md)。

## 相关页面

- [中文文档入口](./README.md)
- [安装指南](./installation.md)
- [配置指南](./configuration.md)
- [开发指南](./development.md)
