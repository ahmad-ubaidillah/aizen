# AizenDashboard

The simplest way to install, configure, and manage
[Aizen](https://github.com/aizen/aizen).

Management hub for the aizen ecosystem.

`AizenDashboard` is a single Zig binary with an embedded Svelte web UI for installing,
configuring, monitoring, and updating ecosystem components (Aizen, AizenOrchestrate,
AizenKanban).

## Features

- **Install wizard** -- manifest-driven guided setup with component-aware flows and local `AizenKanban -> AizenOrchestrate` linking
- **Process supervision** -- start, stop, restart, crash recovery with backoff
- **Health monitoring** -- periodic HTTP health checks, dashboard status cards
- **Cross-component linking** -- auto-connect `AizenKanban -> AizenOrchestrate`, generate native tracker config, and inspect queue/orchestrator status from one UI
- **Config management** -- structured editors for `Aizen`, `AizenOrchestrate`, and `AizenKanban`, with raw JSON fallback when needed
- **Log viewing** -- tail and live SSE streaming per instance
- **One-click updates** -- download, migrate config, rollback on failure
- **Multi-instance** -- run multiple instances of the same component side by side
- **Web UI + CLI** -- browser dashboard for humans, CLI for automation
- **Managed instance admin API** -- instance-scoped status, config, models, cron, channels, and skills routes for managed Aizen installs
- **Orchestration UI** -- workflow editor, poll-based run monitoring, checkpoint forking, encoded workflow/run/store links, and key-value store browser (proxied to AizenKanban through AizenDashboard)

## Quick Start

```bash
zig build
./zig-out/bin/aizen-dashboard
```

Opens browser to [http://aizen-dashboard.localhost:19800](http://aizen-dashboard.localhost:19800).
The resulting binary includes the built web UI; it no longer depends on a
runtime `ui/build` directory.

Local access chain:

- `http://aizen-dashboard.local:19800`
- `http://aizen-dashboard.localhost:19800`
- `http://127.0.0.1:19800`

`aizen-dashboard` tries to publish `aizen-dashboard.local` through `dns-sd`/Bonjour or
`avahi-publish` when those tools are available, and otherwise falls back to
`aizen-dashboard.localhost` and finally `127.0.0.1`.

### Runtime Prerequisites

- `curl` is required to fetch releases and binaries.
- `tar` is required to extract UI module bundles.

### Build Prerequisites

- `npm` is required for `zig build` and `zig build test` because the Svelte UI is
  built and embedded into the binary during the Zig build.

When these tools are missing, `aizen-dashboard` will try to install them automatically
via available system package managers (`apt`, `dnf`, `yum`, `pacman`, `zypper`,
`apk`, `brew`, `winget`, `choco`).

## CLI Usage

```
aizen-dashboard                          # Start server + open browser
aizen-dashboard serve [--host H] [--port N]
               [--allowed-origin ORIGIN] ...
                                 # Start server. Repeat --allowed-origin to
                                 # authorize extra CORS origins (e.g. a
                                 # Tailscale domain). Origins may also come
                                 # from NULLHUB_ALLOWED_ORIGINS as a
                                 # comma-separated list.
aizen-dashboard version | -v | --version # Print version

aizen-dashboard install <component>      # Terminal wizard
aizen-dashboard uninstall <c>/<n>        # Remove instance

aizen-dashboard start <c>/<n>            # Start instance
aizen-dashboard stop <c>/<n>             # Stop instance
aizen-dashboard restart <c>/<n>          # Restart instance
aizen-dashboard start-all / stop-all     # Bulk start/stop

aizen-dashboard status                   # Table of all instances
aizen-dashboard status <c>/<n>           # Single instance detail
aizen-dashboard logs <c>/<n> [-f]        # Tail logs (-f for follow)

aizen-dashboard check-updates            # Check for new versions
aizen-dashboard update <c>/<n>           # Update single instance
aizen-dashboard update-all               # Update everything

aizen-dashboard config <c>/<n> [--edit]  # View/edit config
aizen-dashboard api GET /api/instances/aizen/<n>/status --pretty
aizen-dashboard api GET /api/instances/aizen/<n>/cron --pretty
aizen-dashboard service install          # Register/start OS service (systemd/launchd)
aizen-dashboard service uninstall        # Remove OS service
aizen-dashboard service status           # Show OS service status
```

Instance addressing uses `{component}/{instance-name}` everywhere.

## Architecture

**Zig backend** -- HTTP server, process supervisor, installer, manifest engine.
Two modes: server (HTTP + supervisor threads) or CLI (direct calls, stdout, exit).

**Svelte frontend** -- SvelteKit with static adapter, `@embedFile`'d into the
binary. Component UI modules (chat, monitor) loaded dynamically via Svelte 5
`mount()`.

**Manifest-driven** -- each component publishes `aizen-dashboard-manifest.json` that
describes installation, configuration, launch, health checks, wizard steps, and
UI modules. AizenDashboard is a generic engine that interprets manifests.

**Storage** -- all state lives under `~/.aizen-dashboard/` (config, instances, binaries,
logs, cached manifests).

**Orchestration proxy** -- requests to `/api/orchestration/*` are reverse-proxied
to the local orchestration stack. Most routes go to AizenOrchestrate's REST API via
`NULLBOILER_URL` (e.g. `http://localhost:8080`) and optional `NULLBOILER_TOKEN`.
`/api/orchestration/store/*` is proxied to AizenKanban via `NULLTICKETS_URL` and
optional `NULLTICKETS_TOKEN`.

## Development

Backend:

```bash
zig build test
```

Frontend:

```bash
cd ui && npm run dev
```

End-to-end:

```bash
./tests/test_e2e.sh
```

## Tech Stack

- Zig 0.16.0
- Svelte 5 + SvelteKit (static adapter)
- JSON over HTTP/1.1
- SSE for instance log streaming
- Poll-based orchestration run updates over the `/orchestration/runs/{id}/stream` API

## Project Layout

```
src/
  main.zig              # Entry: CLI dispatch or server start
  cli.zig               # CLI command parser & handlers
  server.zig            # HTTP server (API + static UI)
  auth.zig              # Optional bearer token auth
  api/                  # REST endpoints (components, instances, wizard, ...)
    orchestration.zig   # Reverse proxy to AizenOrchestrate orchestration API
  core/                 # Manifest parser, state, platform, paths
  installer/            # Download, build, UI module fetching
  supervisor/           # Process spawn, health checks, manager
ui/src/
  routes/               # SvelteKit pages
    orchestration/      # Orchestration pages (dashboard, workflows, runs, store)
  lib/components/       # Reusable Svelte components
    orchestration/      # GraphViewer, StateInspector, RunEventLog, InterruptPanel,
                        # CheckpointTimeline, WorkflowJsonEditor, NodeCard, SendProgressBar
  lib/api/              # Typed API client
tests/
  test_e2e.sh           # End-to-end test script
```
