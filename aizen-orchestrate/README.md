# AizenOrchestrate

AizenOrchestrate is an orchestration engine for AI agents.

It is intentionally narrow: it decides what should run, when it should run, and which worker should execute it.  
It does not replace the task tracker and it does not replace the agent runtime.

You do not need all components together.  
Choose only the pieces required for your workflow.

## Design Principle

`tracker = source of truth`  
`orchestrator = policy engine`  
`agent = executor`

### 1) Tracker: [aizen-kanban](https://github.com/aizen/aizen-kanban)

Use aizen-kanban as the authoritative task system for AI agents:

- Stores tasks, states, priorities, and ownership.
- Preserves durable history of task lifecycle.
- Acts as the canonical queue/source of truth for pending work.

### 2) Orchestrator: [aizen-orchestrate](https://github.com/aizen/aizen-orchestrate)

Use aizen-orchestrate to apply orchestration policy:

- Pulls/selects work from tracker or another source.
- Applies scheduling and routing strategies.
- Enforces concurrency limits, retries, and backoff policies.
- Dispatches work to one or many agents/workers.

AizenOrchestrate should not become a task tracker or artifact database.

### 3) Agent Runtime: [aizen](https://github.com/aizen/aizen) or another compatible worker

Use an agent runtime as the execution engine:

- Receives a concrete task/job to run.
- Executes tools, code, and model interactions.
- Returns execution outputs/events back to the orchestrator/tracker flow.

`aizen` is the reference runtime, but `aizen-orchestrate` can also orchestrate other compatible workers
(for example OpenClaw/OpenAI-compatible, ZeroClaw, or PicoClaw via bridge).

Agents should execute work, not own global orchestration policy.

## Why This Separation Exists

Teams often try to move tracker and artifact responsibilities into the orchestrator.  
This project keeps boundaries strict on purpose:

- Tracker owns durable truth.
- Orchestrator owns coordination policy.
- Agent owns execution.

This keeps the architecture modular, simpler to reason about, and easier to evolve.

## Supported Compositions

- `aizen` only: single-agent direct execution.
- `aizen-orchestrate + aizen`: orchestrated execution without dedicated tracker.
- `aizen-orchestrate + other compatible agents`: orchestrated execution without `aizen` dependency.
- `aizen-kanban + aizen`: tracker-driven execution loop.
- `aizen-kanban + aizen-orchestrate + aizen`: full multi-agent orchestration with durable task source.

See additional integration docs in [`docs/`](./docs).

## Workflow Graph Features

The orchestration graph runtime supports:

- `task`, `agent`, `route`, `interrupt`, `send`, `transform`, and `subgraph` nodes
- run replay, checkpoint forking, breakpoint interrupts, and post-start state injection
- `send` fan-out with canonical `items_key` and configurable `output_key`
- task/agent output shaping via `output_key` and `output_mapping`
- template access to `state.*`, `input.*`, `item.*`, `config.*`, and `store.<namespace>.<key>`
- `transform.store_updates` for writing durable workflow memory back to AizenKanban

Store-backed templates and `store_updates` require a AizenKanban base URL. The
runtime resolves it from workflow fields such as `tracker_url` or from run config
(`config.tracker_url` / `config.tracker_api_token`), which are injected into
state as `__config`.

## Config Location

- Default config path: `~/.aizen-orchestrate/config.json`
- Override instance home with `NULLBOILER_HOME=/path/to/dir`
- Override config file directly with `--config /path/to/config.json`

When `NULLBOILER_HOME` is set, `aizen-orchestrate` reads `config.json` from that directory and
resolves relative paths like `db`, `strategies_dir`, `tracker.workflows_dir`, and
`tracker.workspace.root` relative to that config file.
