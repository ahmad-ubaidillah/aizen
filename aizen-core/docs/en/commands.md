# Commands

This page groups the Aizen CLI by task so you can find the right command quickly without scanning the full help output.

`aizen help` gives the top-level summary; this page stays aligned with it and expands into the detailed subcommands and notes.

## Page Guide

**Who this page is for**

- Users who already have Aizen installed and need the right CLI entry point
- Operators checking runtime, service, channel, or diagnostic commands
- Contributors verifying command names, flags, and task groupings

**Read this next**

- Open [Configuration](./configuration.md) if you need to understand what the commands act on
- Open [Usage and Operations](./usage.md) if you want workflows instead of command listings
- Open [Development](./development.md) if you are changing CLI behavior or docs

**If you came from ...**

- [README](./README.md): this page is the fastest way to find a concrete command
- [Installation](./installation.md): after setup, use this page to validate the install and learn daily commands
- `aizen help`: use this page when the built-in help is correct but too terse

## Start with these

- Show help: `aizen help`
- Show version: `aizen version` or `aizen --version`
- First-time setup: `aizen onboard --interactive`
- Quick validation: `aizen agent -m "hello"`
- Long-running mode: `aizen gateway`

## Setup and interaction

| Command | Purpose |
|---|---|
| `aizen help` | Show top-level help |
| `aizen version` / `aizen --version` | Show CLI version |
| `aizen onboard --interactive` | Run the interactive setup wizard |
| `aizen onboard --api-key sk-... --provider openrouter` | Quick provider + API key setup |
| `aizen onboard --api-key ... --provider ... --model ... --memory ...` | Set provider, model, and memory backend in one command |
| `aizen onboard --channels-only` | Reconfigure channels and allowlists only |
| `aizen agent -m "..."` | Run a single prompt |
| `aizen agent` | Start interactive chat mode |

### Interactive model routing

- In `aizen agent`, `/model` shows the current model plus configured routing/fallback status.
- `/config reload` hot reloads supported keys from `config.json` (including agent profiles).
- When auto-routing is configured, `/model` also shows the last auto-route decision and why it was chosen.
- If a routed provider is temporarily rate-limited or out of credits, `/model` shows that route as degraded until its cooldown expires.
- `/model` also lists configured auto routes with their `cost_class` and `quota_class` metadata.
- `/model <provider/model>` pins the current session to that model and disables automatic routing.
- `/model auto` clears the user pin, restores the configured default model, and re-enables `model_routes` for later turns in the same session.
- If no `model_routes` are configured, `/model auto` still clears the pin and returns the session to the configured default model.
- Starting `aizen agent` with `--model` or `--provider` also pins the run and bypasses `model_routes`.

## Runtime and operations

| Command | Purpose |
|---|---|
| `aizen gateway` | Start the long-running runtime using configured host and port |
| `aizen gateway --port 8080` | Override the gateway port from the CLI |
| `aizen gateway --host 0.0.0.0 --port 8080` | Override host and port from the CLI |
| `aizen service install` | Install the background service |
| `aizen service start` | Start the background service |
| `aizen service stop` | Stop the background service |
| `aizen service restart` | Restart the background service |
| `aizen service status` | Show service status |
| `aizen service uninstall` | Remove the background service |
| `aizen status [--json]` | Show overall system status or emit the machine-readable runtime snapshot |
| `aizen doctor` | Run diagnostics |
| `aizen update --check` | Check for updates without installing |
| `aizen update --yes` | Install updates without prompting |
| `aizen auth login openai-codex` | Authenticate `openai-codex` via OAuth device flow |
| `aizen auth login openai-codex --import-codex` | Import auth from `~/.codex/auth.json` |
| `aizen auth status openai-codex` | Show authentication state |
| `aizen auth logout openai-codex` | Remove stored credentials |

Notes:

- `auth` currently supports only `openai-codex`.
- `gateway --host/--port` overrides only the bind settings; the rest of gateway security still comes from config.

## Channels, scheduling, and extensions

### `channel`

| Command | Purpose |
|---|---|
| `aizen channel list [--json]` | List known and configured channels |
| `aizen channel start` | Start the default available channel |
| `aizen channel start telegram` | Start a specific channel |
| `aizen channel status` | Show channel health |
| `aizen channel info <type> [--json]` | Show configured accounts for one channel type |
| `aizen channel add <type>` | Print guidance for adding a channel to config |
| `aizen channel remove <name>` | Print guidance for removing a channel from config |

### `cron`

| Command | Purpose |
|---|---|
| `aizen cron list [--json]` | List scheduled tasks |
| `aizen cron status [--json]` | Show scheduler-level status and job counters |
| `aizen cron add "0 * * * *" "command"` | Add a recurring shell task |
| `aizen cron add-agent "0 * * * *" "prompt" --model <model> [--announce] [--channel <name>] [--account <id>] [--to <id>]` | Add a recurring agent task |
| `aizen cron once 10m "command"` | Add a one-shot delayed shell task |
| `aizen cron once-agent 10m "prompt" --model <model>` | Add a one-shot delayed agent task |
| `aizen cron run <id>` | Run a task immediately |
| `aizen cron pause <id>` / `resume <id>` | Pause or resume a task |
| `aizen cron remove <id>` | Delete a task |
| `aizen cron runs <id>` | Show recent run history |
| `aizen cron update <id> --expression ... --command ... --prompt ... --model ... --enable/--disable` | Update an existing task |

### `skills`

| Command | Purpose |
|---|---|
| `aizen skills list` | List installed skills |
| `aizen skills install <source>` | Install from a Git URL, local path, or HTTPS well-known skill endpoint |
| `aizen skills install --name <query>` | Search the skill registry and install the best matching skill |
| `aizen skills remove <name>` | Remove a skill |
| `aizen skills info <name>` | Show skill metadata |

### `history`

| Command | Purpose |
|---|---|
| `aizen history list [--limit N] [--offset N] [--json]` | List conversation sessions |
| `aizen history show <session_id> [--limit N] [--offset N] [--json]` | Show messages for a session |

## Data, models, and workspace

### `memory`

| Command | Purpose |
|---|---|
| `aizen memory stats` | Show resolved memory config and counters |
| `aizen memory count` | Show total number of memory entries |
| `aizen memory reindex` | Rebuild the vector index |
| `aizen memory search "query" --limit 10` | Run retrieval against memory |
| `aizen memory get <key>` | Show one memory entry |
| `aizen memory list --category task --limit 20` | List memory entries by category |
| `aizen memory drain-outbox` | Drain the durable vector outbox queue |
| `aizen memory forget <key>` | Delete one memory entry |

### `workspace`, `capabilities`, `models`, `migrate`

| Command | Purpose |
|---|---|
| `aizen workspace edit AGENTS.md` | Open a bootstrap markdown file in `$EDITOR` |
| `aizen workspace reset-md --dry-run` | Preview workspace markdown reset |
| `aizen workspace reset-md --include-bootstrap --clear-memory-md` | Reset bundled markdown files and optionally clear extra files |
| `aizen capabilities` | Show a text capability summary |
| `aizen capabilities --json` | Show a JSON capability manifest |
| `aizen config show [--json]` | Print the full on-disk config |
| `aizen config get <path> [--json]` | Read one dotted config value from disk |
| `aizen models list` | List providers and default models |
| `aizen models info <model>` | Show model details |
| `aizen models summary [--json]` | Print the provider/key-safe admin summary used by integrations |
| `aizen models benchmark` | Run model latency benchmark |
| `aizen models refresh` | Refresh the model catalog |
| `aizen migrate openclaw --dry-run` | Preview OpenClaw migration |
| `aizen migrate openclaw --source /path/to/workspace` | Migrate from a specific source workspace |

Notes:

- `workspace edit` works only with file-based backends such as `markdown` and `hybrid`.
- If bootstrap data is stored in the database backend, the CLI will tell you to use the agent's `memory_store` tool instead.
- The `--json` read-side commands are intended for automation and for AizenDashboard's managed-instance admin API boundary.

## Hardware and automation-facing entry points

### `hardware`

| Command | Purpose |
|---|---|
| `aizen hardware scan` | Scan connected hardware |
| `aizen hardware flash <firmware_file> [--target <board>]` | Flash firmware to a device (currently a placeholder command) |
| `aizen hardware monitor` | Monitor hardware devices (currently a placeholder command) |

### Top-level machine-facing flags

These are more useful for automation, probing, or integrations than for normal day-to-day CLI use:

| Command | Purpose |
|---|---|
| `aizen --export-manifest` | Export the runtime manifest |
| `aizen --list-models` | Print model information |
| `aizen --probe-provider-health` | Probe provider health |
| `aizen --probe-channel-health` | Probe channel health |
| `aizen --from-json` | Run a JSON-driven entry path |

## Recommended troubleshooting order

1. `aizen doctor`
2. `aizen status`
3. `aizen channel status`
4. `aizen agent -m "self-check"`
5. If gateway is involved, also run `curl http://127.0.0.1:3000/health`

## Next Steps

- Go to [Usage and Operations](./usage.md) for task-based runtime workflows
- Go to [Configuration](./configuration.md) if a command depends on provider, gateway, or memory settings
- Go to [Development](./development.md) if you plan to change command behavior or update docs alongside code

## Related Pages

- [README](./README.md)
- [Installation](./installation.md)
- [Gateway API](./gateway-api.md)
- [Architecture](./architecture.md)
