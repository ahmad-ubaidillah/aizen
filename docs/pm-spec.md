# Aizen Agent — Phase 1 MVP Implementation Spec

**PM Agent** | Date: 2026-05-01
**Target:** v0.1 "The Core"
**Timeline:** 4-6 weeks
**Goal:** Rebranded NullClaw core agent running with basic features from all three sources, plus Python skill bridge and basic dashboard.

---

## 0. Guiding Principles

1. **Fork, don't rewrite.** Every Zig service starts as a verified fork of its NullClaw counterpart. Only rebranding changes are permitted in Phase 1.
2. **Rebrand is compile-time correct.** All renames must produce a binary that boots, serves requests on the correct port, and reads from `~/.aizen/` paths.
3. **Smoke-test every service.** A service is "done" when its health endpoint returns 200 on its designated port after rebranding.
4. **Python bridge is minimal but functional.** It must load a SKILL.md file, execute it, and return a result. No self-learning, no curator, no ranking yet.
5. **Dashboard boots and navigates.** UI must render, connect to aizen-core via WebSocket, and display a chat interface. No new features beyond rebranding.

---

## 1. Task Breakdown

### Legend

- **Complexity:** S (1-3 days) / M (3-5 days) / L (5-10 days) / XL (10+ days)
- **Dependencies:** Tasks that must complete before this one can start
- **Risk:** H/M/L — likelihood of unexpected complications
- **Owner:** Suggested team/persona (for reference)

---

## 1.1 Epic: Fork + Rebrand aizen-core

**Goal:** Take nullclaw source, rename every identifier/path/string, produce a `aizen-core` binary that boots and passes all existing tests.

### Task 1.1.1 — Create aizen monorepo skeleton

| Field | Value |
|-------|-------|
| Complexity | S |
| Dependencies | None |
| Risk | L |

**Description:** Create the top-level `aizen/` repository with the directory structure defined in architecture-design.md Section 1. Initialize git, add `.gitignore` for Zig (zig-cache, zig-out), Python (__pycache__, .egg-info), and Node (node_modules, .svelte-kit). Add top-level `README.md`, `LICENSE` (MIT), and a `Makefile` with phony targets for each service.

**Acceptance Criteria:**
- [ ] `aizen/` repo exists with all directories from Section 1 of architecture design
- [ ] `git status` shows clean working tree
- [ ] `make help` lists targets for all 5 services + skill-bridge
- [ ] `.gitignore` covers Zig, Python, Node, Svelte, and IDE artifacts
- [ ] `README.md` contains project name, tagline, and link to architecture doc

---

### Task 1.1.2 — Fork nullclaw into aizen-core with full rebrand

| Field | Value |
|-------|-------|
| Complexity | XL |
| Dependencies | Task 1.1.1 |
| Risk | H |

**Description:** Copy the entire nullclaw source tree into `aizen/aizen-core/`. Perform the global renames from architecture-design.md Section 7.2:

- `nullclaw` → `aizen` (all identifiers, comments, strings)
- `NullClaw` → `Aizen` (PascalCase types, comments)
- `nullclaw_` → `aizen_` (snake_case functions)
- `nullclaw-` → `aizen-` (CLI commands, package names)
- `~/.nullclaw/` → `~/.aizen/` (data paths)
- `nullclaw.json` → `aizen.json` (config filenames)
- `NULLCLAW_HOME` → `AIZEN_HOME` (environment variables)
- All port references verified to stay on `:8080`

This includes:
- Zig source files (`.zig`)
- `build.zig` and `build.zig.zon`
- Test files
- CLI help strings and argument parsers
- Default config JSON
- Embedded HTML/JS (if any)
- Documentation files

**Acceptance Criteria:**
- [ ] `cd aizen-core && zig build` compiles without errors
- [ ] `zig build test` passes all 5,640+ existing tests
- [ ] The produced binary is named `aizen-core` (or `aizen`)
- [ ] `./aizen-core --help` shows "Aizen" branding, not "NullClaw"
- [ ] `./aizen-core` boots and listens on `:8080`
- [ ] `curl http://localhost:8080/api/v1/healthz` returns 200
- [ ] `~/.aizen/` is created on first run (not `~/.nullclaw/`)
- [ ] `aizen.json` is the default config filename
- [ ] `grep -ri "nullclaw" aizen-core/src/` returns zero matches
- [ ] `grep -ri "NullClaw" aizen-core/src/` returns zero matches (except possibly in license/attribution comments acknowledging origins)
- [ ] All 50+ provider modules load correctly
- [ ] All 19 channel adapters compile and are registered
- [ ] All 35+ built-in tools are available via tool registry
- [ ] Config migration: `AIZEN_HOME` env var takes precedence over `~/.aizen/` default

**Risk Assessment:**
- **HIGH risk** because nullclaw has ~230 source files and ~204K LOC. Automated find-replace may miss edge cases in strings, test fixtures, or embedded data.
- **Mitigation:** Write a rebranding script (`scripts/rebrand.sh`) that performs sed replacements in a deterministic order, then run the full test suite. Keep the script in the repo for audit. Do a manual review of the diff before committing.

---

### Task 1.1.3 — Config migration script (nullclaw → aizen)

| Field | Value |
|-------|-------|
| Complexity | M |
| Dependencies | Task 1.1.2 |
| Risk | M |

**Description:** Create a `scripts/migrate-config.sh` script that handles migration from an existing nullclaw installation to aizen. This must:

1. Copy `~/.nullclaw/` → `~/.aizen/` preserving structure
2. Rename `nullclaw.json` → `aizen.json` inside the config
3. Update any internal path references within the JSON config
4. Migrate environment variables: if `NULLCLAW_HOME` is set, map it to `AIZEN_HOME`
5. Preserve SQLite databases without modification (schema is unchanged)
6. Log what was migrated and flag any manual-review items

**Acceptance Criteria:**
- [ ] `migrate-config.sh` runs without errors on a system with existing nullclaw data
- [ ] After migration, `aizen-core` boots and reads the migrated config from `~/.aizen/`
- [ ] SQLite databases are untouched (byte-identical)
- [ ] Script produces a migration report: files copied, paths updated, env vars detected
- [ ] Script is idempotent — re-running it on an already-migrated system is a no-op
- [ ] Script warns if `~/.aizen/` already exists and offers `--force` to overwrite
- [ ] Script is tested on both Linux and macOS

**Risk Assessment:**
- **MEDIUM risk** because config format differences or edge cases in user data may cause runtime failures.
- **Mitigation:** The existing nullclaw config is JSON-based with a `from_json` bootstrap mechanism — we can validate the migrated config by booting aizen-core with it.

---

### Task 1.1.4 — aizen-core Dockerfile and CI pipeline

| Field | Value |
|-------|-------|
| Complexity | S |
| Dependencies | Task 1.1.2 |
| Risk | L |

**Description:** Create a `Dockerfile` for aizen-core that produces a minimal static binary image. Set up GitHub Actions CI that:
1. Builds aizen-core on push/PR
2. Runs the full test suite
3. Produces a release artifact (static binary) on tag push
4. Builds Docker image on main branch

**Acceptance Criteria:**
- [ ] `docker build -t aizen-core .` succeeds and produces a working image
- [ ] `docker run aizen-core --help` shows Aizen branding
- [ ] CI pipeline runs on every push to main and on PRs
- [ ] CI runs `zig build test` and fails on test failures
- [ ] Tagging `v0.1.0` triggers a release build that uploads the static binary
- [ ] Docker image size is under 50MB (Zig static binary should be ~1MB + Alpine base)

---

## 1.2 Epic: Fork + Rebrand aizen-dashboard

**Goal:** Combine nullhub (Zig management hub) and nullclaw-chat-ui (Svelte 5 chat) into a single `aizen-dashboard` that serves both management and chat UI.

### Task 1.2.1 — Fork nullhub into aizen-dashboard hub component

| Field | Value |
|-------|-------|
| Complexity | L |
| Dependencies | Task 1.1.2 (needs running aizen-core to verify integration) |
| Risk | M |

**Description:** Copy nullhub source into `aizen/aizen-dashboard/src/hub/`. Perform global renames:

- `nullhub` → `aizen-dashboard` (identifiers, strings)
- `NullHub` → `AizenDashboard` (types)
- `nullhub_` → `aizen_dashboard_` (functions)
- `~/.nullhub/` → `~/.aizen/dashboard/` (paths)
- Port stays on `:3000`

Update the hub's references to point to aizen-core service names and ports:
- Agent instance management → `localhost:8080`
- Config → `localhost:8080`
- Logs → `localhost:8080`
- Orchestration proxy → `localhost:7730` (future, stub for now)

**Acceptance Criteria:**
- [ ] `cd aizen-dashboard && zig build` compiles the hub component
- [ ] Hub boots on `:3000`
- [ ] `curl http://localhost:3000/api/instances` returns 200 (may be empty list)
- [ ] `curl http://localhost:3000/api/config` returns 200
- [ ] `curl http://localhost:3000/api/logs` returns 200 (SSE stream)
- [ ] `grep -ri "nullhub" aizen-dashboard/src/hub/` returns zero matches
- [ ] Hub can start/stop a local aizen-core instance via process supervision
- [ ] mDNS discovery works (detects aizen-core on local network)
- [ ] Config editor UI loads and can modify aizen.json

---

### Task 1.2.2 — Fork nullclaw-chat-ui into aizen-dashboard chat component

| Field | Value |
|-------|-------|
| Complexity | M |
| Dependencies | Task 1.2.1 |
| Risk | M |

**Description:** Copy nullclaw-chat-ui (Svelte 5) source into `aizen/aizen-dashboard/src/ui/`. Perform rebranding:

- `nullclaw-chat-ui` → `aizen-dashboard` (package name)
- `NullClaw` → `Aizen` in all UI text, titles, headers
- WebSocket connection URLs updated to point to aizen-core (`:8080`)
- WebChannel E2E pairing references updated
- Color scheme updated to Aizen branding (Cyan #58A6FF primary, Dark #0D1117 background)
- Logo/brand assets updated to Aizen jellyfish branding

Integrate the chat UI as a route or component within the dashboard SvelteKit app so both management views and chat are served from `:3000`.

**Acceptance Criteria:**
- [ ] `cd aizen-dashboard && npm install && npm run build` succeeds
- [ ] Chat UI renders at `http://localhost:3000/` or a dedicated `/chat` route
- [ ] WebSocket connection to aizen-core on `:8080` works
- [ ] Sending a message in the chat UI receives a response from aizen-core
- [ ] All "NullClaw" references in UI text replaced with "Aizen"
- [ ] Color scheme matches Aizen brand spec (Cyan #58A6FF / Dark #0D1117)
- [ ] PIN pairing flow for WebChannel E2E encryption still works
- [ ] Tool timeline rendering still functions
- [ ] Session restore works across browser refresh
- [ ] Theme persistence works (dark/light mode)
- [ ] `grep -ri "nullclaw" aizen-dashboard/src/ui/` returns zero matches (excluding package-lock transitive deps)

---

### Task 1.2.3 — aizen-dashboard integration testing

| Field | Value |
|-------|-------|
| Complexity | S |
| Dependencies | Task 1.2.2 |
| Risk | L |

**Description:** Write integration tests that verify the dashboard correctly connects to and manages aizen-core. Tests should cover:

1. Process supervision: start/stop aizen-core from dashboard
2. Config management: read and modify aizen.json via dashboard API
3. Chat: send a message through the dashboard chat UI, get a response
4. Log streaming: verify SSE log stream works
5. Health checks: dashboard shows aizen-core health status

**Acceptance Criteria:**
- [ ] Integration test suite exists in `aizen-dashboard/tests/`
- [ ] Tests can be run with `make test-dashboard`
- [ ] All 5 test scenarios pass in CI
- [ ] Tests are documented in README

---

## 1.3 Epic: Fork + Rebrand aizen-watch

**Goal:** Rebrand nullwatch as aizen-watch, verified working observability service.

### Task 1.3.1 — Fork nullwatch into aizen-watch

| Field | Value |
|-------|-------|
| Complexity | M |
| Dependencies | Task 1.1.2 (for aizen-core to emit spans) |
| Risk | L |

**Description:** Copy nullwatch source into `aizen/aizen-watch/`. Perform global renames:

- `nullwatch` → `aizen-watch` / `aizen_watch` (identifiers, strings)
- `NullWatch` → `AizenWatch` (types)
- `~/.nullwatch/` → `~/.aizen/watch/` (data paths)
- Port stays on `:7710`

Make aizen-core aware of `aizen-watch` endpoint for span/eval/trace export (update its telemetry config).

**Acceptance Criteria:**
- [ ] `cd aizen-watch && zig build` compiles without errors
- [ ] `zig build test` passes all existing nullwatch tests
- [ ] aizen-watch boots on `:7710`
- [ ] `curl http://localhost:7710/v1/spans` returns 200
- [ ] `curl http://localhost:7710/v1/evals` returns 200
- [ ] `curl http://localhost:7710/v1/runs` returns 200
- [ ] `curl http://localhost:7710/otlp/v1/traces` accepts OTLP JSON
- [ ] aizen-core can be configured to export traces to `localhost:7710`
- [ ] Data persists to `~/.aizen/watch/data/` as JSONL
- [ ] `grep -ri "nullwatch" aizen-watch/src/` returns zero matches

---

## 1.4 Epic: Fork + Rebrand aizen-kanban

**Goal:** Rebrand nulltickets as aizen-kanban, verified working task tracking service.

### Task 1.4.1 — Fork nulltickets into aizen-kanban

| Field | Value |
|-------|-------|
| Complexity | M |
| Dependencies | Task 1.1.2 |
| Risk | L |

**Description:** Copy nulltickets source into `aizen/aizen-kanban/`. Perform global renames:

- `nulltickets` → `aizen-kanban` / `aizen_kanban` (identifiers, strings)
- `NullTickets` → `AizenKanban` (types)
- `~/.nulltickets/` → `~/.aizen/kanban/` (data paths)
- Port stays on `:7720`

Update pipeline stage names if they reference "nulltickets" in any FSM states.

**Acceptance Criteria:**
- [ ] `cd aizen-kanban && zig build` compiles without errors
- [ ] `zig build test` passes all existing nulltickets tests
- [ ] aizen-kanban boots on `:7720`
- [ ] `curl http://localhost:7720/v1/tasks` returns 200
- [ ] `curl http://localhost:7720/v1/pipelines` returns 200
- [ ] `curl http://localhost:7720/v1/kv` returns 200
- [ ] Full CRUD works on tasks (create, read, update, delete)
- [ ] Pipeline FSM transitions work (triage → todo → ready → running → blocked → done)
- [ ] Lease-based claiming with heartbeat works
- [ ] FTS5 full-text search on KV store works
- [ ] SQLite database created at `~/.aizen/kanban/kanban.db`
- [ ] `grep -ri "nulltickets" aizen-kanban/src/` returns zero matches

---

## 1.5 Epic: Fork + Rebrand aizen-orchestrate

**Goal:** Rebrand nullboiler as aizen-orchestrate, verified working workflow engine.

### Task 1.5.1 — Fork nullboiler into aizen-orchestrate

| Field | Value |
|-------|-------|
| Complexity | M |
| Dependencies | Task 1.1.2 |
| Risk | L |

**Description:** Copy nullboiler source into `aizen/aizen-orchestrate/`. Perform global renames:

- `nullboiler` → `aizen-orchestrate` / `aizen_orchestrate` (identifiers, strings)
- `NullBoiler` → `AizenOrchestrate` (types)
- `~/.nullboiler/` → `~/.aizen/orchestrate/` (data paths)
- Port stays on `:7730`

**Acceptance Criteria:**
- [ ] `cd aizen-orchestrate && zig build` compiles without errors
- [ ] `zig build test` passes all existing nullboiler tests
- [ ] aizen-orchestrate boots on `:7730`
- [ ] `curl http://localhost:7730/v1/workflows` returns 200
- [ ] `curl http://localhost:7730/v1/runs` returns 200
- [ ] `curl http://localhost:7730/v1/workers` returns 200
- [ ] Workflow CRUD works (create, read, update, delete)
- [ ] Workflow execution with all 7 node types works
- [ ] SSE streaming of workflow progress works
- [ ] Checkpoint/replay/fork works
- [ ] SQLite database created at `~/.aizen/orchestrate/orchestrate.db`
- [ ] `grep -ri "nullboiler" aizen-orchestrate/src/` returns zero matches

---

## 1.6 Epic: Python Skill Bridge (aizen-skill-bridge)

**Goal:** Create a minimal but functional Python skill loader that can parse SKILL.md files and execute them, bridging the Hermes skill ecosystem into aizen-core.

### Task 1.6.1 — Project scaffolding and build system

| Field | Value |
|-------|-------|
| Complexity | S |
| Dependencies | Task 1.1.1 |
| Risk | L |

**Description:** Create the `aizen-skill-bridge/` Python package with:

- `pyproject.toml` with dependencies (PyYAML, etc.)
- `requirements.txt` for pip-based installs
- `aizen_skill_bridge/__init__.py` with version and package metadata
- `aizen_skill_bridge/exceptions.py` with custom exception types
- Test framework setup (pytest)
- `Makefile` target: `make test-bridge`

**Acceptance Criteria:**
- [ ] `pip install -e .` succeeds
- [ ] `python -c "import aizen_skill_bridge; print(aizen_skill_bridge.__version__)"` prints `0.1.0`
- [ ] `pytest tests/` runs (0 tests, but framework is ready)
- [ ] `pyproject.toml` specifies Python >= 3.11
- [ ] Code passes `ruff check` and `mypy` with zero errors

---

### Task 1.6.2 — SKILL.md parser (loader.py)

| Field | Value |
|-------|-------|
| Complexity | M |
| Dependencies | Task 1.6.1 |
| Risk | L |

**Description:** Implement the SKILL.md YAML frontmatter + Markdown body parser. This must be compatible with the Hermes SKILL.md format (YAML frontmatter delimited by `---`, Markdown body with instructions).

The parser must:
1. Extract YAML frontmatter (name, version, category, description, triggers, toolsets)
2. Extract Markdown body as the skill instructions
3. Validate required fields (name, version at minimum)
4. Handle malformed files gracefully (skip with warning, don't crash)
5. Support loading from filesystem paths (`~/.aizen/skills/`)
6. Support hot-reload: detect file changes and reload

**Acceptance Criteria:**
- [ ] Parser correctly handles valid SKILL.md files with YAML frontmatter
- [ ] Parser rejects files with missing required fields and logs a warning
- [ ] Parser handles files without frontmatter gracefully (treat as plain text skill)
- [ ] Parser loads all `.md` files from a directory recursively
- [ ] Parser returns structured `Skill` dataclass with all parsed fields
- [ ] Unit tests cover: valid frontmatter, missing frontmatter, malformed YAML, empty file, nested directories
- [ ] Hot-reload detects file changes within 5 seconds and reloads the skill
- [ ] Performance: loads 100 skill files in under 500ms

---

### Task 1.6.3 — Skill executor (executor.py)

| Field | Value |
|-------|-------|
| Complexity | M |
| Dependencies | Task 1.6.2 |
| Risk | M |

**Description:** Implement the skill executor that runs loaded skills in a sandboxed subprocess. For Phase 1 MVP, execution is:

1. Parse the skill's Markdown body for step-by-step instructions
2. Present instructions to aizen-core via the skill bridge C ABI interface
3. Return execution result (success/failure + output)

The executor must:
- Run skills in a subprocess with resource limits (timeout, memory cap)
- Capture stdout/stderr from skill execution
- Report success/failure with structured output
- Support the `toolsets` field to declare which tool categories a skill can access
- Handle skill execution timeout (default 60s, configurable)

**Acceptance Criteria:**
- [ ] Executor can run a simple "hello world" skill and capture output
- [ ] Executor enforces timeout — skill running >60s is killed
- [ ] Executor captures stdout and stderr separately
- [ ] Executor returns structured `ExecutionResult` (success: bool, output: str, error: Optional[str], duration_ms: int)
- [ ] Executor respects toolset allowlisting (a skill declaring `toolsets: [terminal]` can only use terminal tools)
- [ ] Executor handles subprocess crashes (segfault, OOM) and returns error result
- [ ] Unit tests cover: successful execution, timeout, crash, missing toolset, empty skill body

---

### Task 1.6.4 — Skill registry and discovery (registry.py)

| Field | Value |
|-------|-------|
| Complexity | S |
| Dependencies | Task 1.6.2 |
| Risk | L |

**Description:** Implement the skill registry that manages discovered skills and provides lookup by trigger, category, or name.

The registry must:
1. Index all loaded skills by name, triggers, and category
2. Support lookup by trigger keyword (e.g., "deploy" → "my-deploy-skill")
3. Support listing by category (e.g., all "devops" skills)
4. Support listing all available skills with metadata
5. Integrate with the hot-reload mechanism from loader.py

**Acceptance Criteria:**
- [ ] Registry loads all skills from `~/.aizen/skills/` on startup
- [ ] `registry.lookup_by_trigger("deploy")` returns matching skills
- [ ] `registry.list_by_category("devops")` returns skills in that category
- [ ] `registry.list_all()` returns all skills with metadata
- [ ] Hot-reload: adding a new skill file is detected and loaded within 5s
- [ ] Hot-reload: removing a skill file is detected and unloaded within 5s
- [ ] Registry handles duplicate skill names (last write wins, with warning log)

---

### Task 1.6.5 — C ABI bridge interface

| Field | Value |
|-------|-------|
| Complexity | L |
| Dependencies | Task 1.6.3, Task 1.1.2 |
| Risk | H |

**Description:** Implement the C ABI interface that allows aizen-core (Zig) to call into the Python skill bridge. This is the most technically risky task in Phase 1.

Implementation approach:
1. Define the C ABI in `aizen-skill-bridge/c_abi.h` with function signatures:
   - `aizen_skill_bridge_init()` — Initialize the Python runtime
   - `aizen_skill_bridge_load(path)` — Load a skill from path
   - `aizen_skill_bridge_execute(skill_id, input_json)` — Execute a skill
   - `aizen_skill_bridge_list()` — List loaded skills
   - `aizen_skill_bridge_deinit()` — Shutdown the Python runtime
2. Implement these in Python via `ctypes` or `cffi` on the Python side
3. On the Zig side (aizen-core), implement the `SkillBridgeVTable` that calls these C functions via `std.Environment.call`
4. Communication format: JSON strings over C ABI (zero-copy for small payloads, shared memory for large ones)

Alternative (backup) approach: Use subprocess IPC (stdin/stdout JSON) instead of C ABI embedding. Simpler to implement, higher latency, but lower risk for Phase 1.

**Acceptance Criteria:**
- [ ] C ABI header file exists with all 5 function signatures
- [ ] Python implementation of all 5 functions works in isolation
- [ ] Zig `SkillBridgeVTable` is defined and compiles
- [ ] Integration test: aizen-core can call `aizen_skill_bridge_load()` and get a skill ID back
- [ ] Integration test: aizen-core can call `aizen_skill_bridge_execute()` and get a result back
- [ ] Integration test: aizen-core can call `aizen_skill_bridge_list()` and see loaded skills
- [ ] Skill execution from aizen-core returns within time limits
- [ ] Error handling: Python crash does not take down aizen-core (isolation verified)
- [ ] If C ABI proves too risky, subprocess IPC approach documented with clear migration path

**Risk Assessment:**
- **HIGH risk** because Zig↔Python FFI via C ABI is non-trivial. Zig's C interop is good but embedding a Python interpreter introduces lifetime, GIL, and crash isolation concerns.
- **Mitigation:** Start with subprocess IPC as Phase 1 default. The C ABI approach is the Phase 2 target. Document the vtable interface clearly so the transport can be swapped without changing caller code.

---

### Task 1.6.6 — curator.py stub (future self-learning)

| Field | Value |
|-------|-------|
| Complexity | S |
| Dependencies | Task 1.6.4 |
| Risk | L |

**Description:** Create the `curator.py` module with stubs for the self-learning pipeline. In Phase 1, this is a placeholder that:
1. Records skill execution success/failure logs
2. Provides a `rank()` method that returns skills in discovery order (no Wilson score yet)
3. Provides a `record_feedback()` method that logs feedback but doesn't change ranking
4. Documents the intended Phase 2 self-learning API

**Acceptance Criteria:**
- [ ] `aizen_skill_bridge/curator.py` exists with stub methods
- [ ] `curator.rank(skills)` returns skills in discovery order (no-op for now)
- [ ] `curator.record_feedback(skill_id, success)` logs feedback to `~/.aizen/skills/feedback.jsonl`
- [ ] API is documented with docstrings showing the intended Phase 2 behavior
- [ ] Integration test: executor calls curator.rank() and gets a valid ordering

---

## 1.7 Epic: End-to-End Integration

**Goal:** All services boot, discover each other, and the dashboard can chat with aizen-core through the full stack.

### Task 1.7.1 — Service discovery and startup script

| Field | Value |
|-------|-------|
| Complexity | S |
| Dependencies | Task 1.1.2, 1.2.1, 1.3.1, 1.4.1, 1.5.1 |
| Risk | M |

**Description:** Create a `scripts/start-all.sh` that starts all aizen services in the correct order with proper health checks:

1. Start aizen-kanban (`:7720`) — no dependencies
2. Start aizen-orchestrate (`:7730`) — no dependencies
3. Start aizen-watch (`:7710`) — no dependencies
4. Start aizen-core (`:8080`) — depends on watch for trace export
5. Start aizen-dashboard (`:3000`) — depends on core being healthy
6. Wait for each service's health endpoint before starting the next

Also create `scripts/stop-all.sh` and `scripts/status.sh`.

**Acceptance Criteria:**
- [ ] `start-all.sh` starts all 5 services in order
- [ ] Each service's health endpoint returns 200 before the next service starts
- [ ] `stop-all.sh` gracefully terminates all services
- [ ] `status.sh` reports the health of each service (running/stopped, port, uptime)
- [ ] Script works on Linux and macOS
- [ ] Script can be run from any directory (uses absolute paths)

---

### Task 1.7.2 — End-to-end smoke test

| Field | Value |
|-------|-------|
| Complexity | M |
| Dependencies | Task 1.7.1, Task 1.6.3 |
| Risk | L |

**Description:** Write an end-to-end smoke test that verifies the complete aizen stack:

1. Start all services via `start-all.sh`
2. Open dashboard in headless browser (or just API calls)
3. Send a chat message through aizen-core's `/api/v1/chat` endpoint
4. Verify response is received
5. Verify a span appears in aizen-watch
6. Create a task in aizen-kanban via API
7. Verify task persists in SQLite
8. Create a simple workflow in aizen-orchestrate via API
9. Verify workflow can be listed
10. Test skill bridge: load a skill via Python bridge, trigger it from aizen-core
11. Stop all services and verify clean shutdown

**Acceptance Criteria:**
- [ ] All 11 steps pass in automated CI
- [ ] Smoke test runs in under 60 seconds
- [ ] Smoke test is idempotent (can run multiple times)
- [ ] Test cleans up all created data on completion
- [ ] Test outputs a clear PASS/FAIL summary for each step

---

### Task 1.7.3 — Documentation: getting started guide

| Field | Value |
|-------|-------|
| Complexity | S |
| Dependencies | Task 1.7.1 |
| Risk | L |

**Description:** Write a `docs/getting-started.md` that covers:

1. Prerequisites (Zig 0.16+, Python 3.11+, Node 18+)
2. Building each service from source
3. Configuration (`aizen.json` format, environment variables)
4. Starting all services
5. Opening the dashboard
6. Sending your first chat message
7. Creating a task in aizen-kanban
8. Loading your first skill
9. Connecting a messaging channel (Telegram example)

**Acceptance Criteria:**
- [ ] Document exists at `docs/getting-started.md`
- [ ] All commands in the document have been copy-paste tested
- [ ] Document covers all 5 services
- [ ] Document includes troubleshooting section (common errors and fixes)

---

## 2. Dependency Graph

```
Task 1.1.1 (monorepo skeleton)
  ├─→ Task 1.1.2 (fork aizen-core) ──┬──→ Task 1.1.3 (config migration)
  │                                    ├──→ Task 1.1.4 (Dockerfile + CI)
  │                                    ├──→ Task 1.2.1 (fork dashboard hub) ──→ Task 1.2.2 (fork chat UI) ──→ Task 1.2.3 (integration tests)
  │                                    ├──→ Task 1.3.1 (fork aizen-watch)
  │                                    ├──→ Task 1.4.1 (fork aizen-kanban)
  │                                    ├──→ Task 1.5.1 (fork aizen-orchestrate)
  │                                    └──→ Task 1.6.5 (C ABI bridge)
  └─→ Task 1.6.1 (skill-bridge scaffolding) ──→ Task 1.6.2 (parser) ──┬──→ Task 1.6.3 (executor) ──→ Task 1.6.5 (C ABI bridge)
  │                                                                      └──→ Task 1.6.4 (registry) ──→ Task 1.6.6 (curator stub)
  │
Task 1.7.1 (startup scripts) ──→ Task 1.7.2 (smoke test) ──→ Task 1.7.3 (docs)
  (depends on all services built)

Critical Path: 1.1.1 → 1.1.2 → 1.2.1 → 1.2.2 → 1.7.1 → 1.7.2
```

---

## 3. Risk Register

| ID | Risk | Impact | Likelihood | Mitigation |
|----|------|--------|------------|------------|
| R1 | NullClaw rebranding misses embedded strings/fixtures | Tests fail at runtime | Medium | Write deterministic rebrand script; run full test suite; grep audit |
| R2 | Zig↔Python C ABI FFI crashes or GIL issues | Skill bridge unusable | High | Fall back to subprocess IPC for Phase 1; C ABI targeted for Phase 2 |
| R3 | Dashboard Svelte integration breaks existing nullhub or chat-ui functionality | UI doesn't render | Medium | Keep hub and chat as separate SvelteKit routes, minimal integration |
| R4 | nullclaw build system has hardcoded paths or names | Build fails after rename | Medium | Carefully audit `build.zig` and `build.zig.zon` for hardcoded references |
| R5 | Config format incompatibilities between nullclaw versions | Config migration breaks | Low | Migration script validates before writing; offers `--dry-run` mode |
| R6 | Port conflicts on developer machines | Services don't start | Low | All ports configurable via env vars; defaults match architecture doc |
| R7 | Zig 0.16 breaking changes during development | Build breaks | Medium | Pin exact Zig version in CI; document tested version |
| R8 | Python 3.11+ not available on target platforms | Skill bridge won't install | Low | Document Python requirement; consider Python 3.10 support for wider reach |
| R9 | SQLite schema incompatibility after rebrand | Data migration fails | Low | DB schema is unchanged; only paths and filenames change |
| R10 | Upstream nullclaw continues to ship fixes during our fork | Merge conflicts on rebase | Medium | Maintain a clean `upstream/` remote and rebase regularly before Phase 1 freeze |

---

## 4. Complexity Summary

| Epic | Tasks | Total Complexity | Estimated Days |
|------|-------|-------------------|-----------------|
| 1.1 aizen-core | 4 tasks | 1×XL + 1×M + 2×S | 10-14 days |
| 1.2 aizen-dashboard | 3 tasks | 1×L + 1×M + 1×S | 7-10 days |
| 1.3 aizen-watch | 1 task | 1×M | 3-5 days |
| 1.4 aizen-kanban | 1 task | 1×M | 3-5 days |
| 1.5 aizen-orchestrate | 1 task | 1×M | 3-5 days |
| 1.6 aizen-skill-bridge | 6 tasks | 1×L + 2×M + 3×S | 10-14 days |
| 1.7 Integration | 3 tasks | 1×M + 2×S | 4-6 days |
| **Total** | **19 tasks** | | **40-59 days** |

With 2-3 engineers, this maps to roughly 4-6 weeks as estimated.

---

## 5. Task Priority Order (Recommended Implementation Sequence)

### Sprint 1 (Week 1-2): Foundation

1. **Task 1.1.1** — Monorepo skeleton (S, no deps)
2. **Task 1.1.2** — Fork aizen-core (XL, blocks almost everything)
3. **Task 1.6.1** — Skill bridge scaffolding (S, no deps)
4. **Task 1.1.4** — aizen-core Dockerfile + CI (S, only needs 1.1.2)

### Sprint 2 (Week 2-3): Services

5. **Task 1.1.3** — Config migration script (M, needs 1.1.2)
6. **Task 1.3.1** — Fork aizen-watch (M, needs 1.1.2)
7. **Task 1.4.1** — Fork aizen-kanban (M, needs 1.1.2)
8. **Task 1.5.1** — Fork aizen-orchestrate (M, needs 1.1.2)
9. **Task 1.6.2** — SKILL.md parser (M, needs 1.6.1)

### Sprint 3 (Week 3-4): Dashboard + Bridge

10. **Task 1.2.1** — Fork dashboard hub (L, needs 1.1.2)
11. **Task 1.6.3** — Skill executor (M, needs 1.6.2)
12. **Task 1.6.4** — Skill registry (S, needs 1.6.2)

### Sprint 4 (Week 4-5): Integration

13. **Task 1.2.2** — Fork chat UI (M, needs 1.2.1)
14. **Task 1.6.5** — C ABI bridge (L, needs 1.6.3 + 1.1.2) — may slip to Phase 2 as subprocess IPC
15. **Task 1.6.6** — Curator stub (S, needs 1.6.4)

### Sprint 5 (Week 5-6): Polish

16. **Task 1.2.3** — Dashboard integration tests (S, needs 1.2.2)
17. **Task 1.7.1** — Startup scripts (S, needs all services)
18. **Task 1.7.2** — E2E smoke test (M, needs 1.7.1)
19. **Task 1.7.3** — Documentation (S, needs 1.7.1)

---

## 6. Out of Scope for Phase 1

The following features from the architecture design are explicitly **NOT** in Phase 1 MVP:

- SYNAPSE graph memory (Phase 2)
- 8-layer sanitization pipeline (Phase 2)
- Age-encrypted vault (Phase 2)
- Complexity triage routing (Phase 2)
- HiAgent context compaction (Phase 2)
- MCP injection detection (Phase 2)
- MARCH self-check (Phase 2)
- Sub-agent permission grants (Phase 2)
- Self-learning skills (Wilson score, ERL, STEM) (Phase 2)
- Tree-sitter code indexing (Phase 2/3)
- Config migration system (diff+apply) (Phase 3) — our Phase 1 only does nullclaw→aizen path migration
- TUI dashboard (Phase 3)
- A2A protocol with IBCT tokens (Phase 3)
- ACP server (Phase 3)
- OTA updates (Phase 3)
- Cross-compilation (Phase 3)
- Hardware peripherals (Phase 3)
- Credential pool (Phase 3)
- Batch trajectory generation (Phase 3)

---

## 7. Decision Log

| Date | Decision | Rationale | Alternatives Considered |
|------|----------|-----------|------------------------|
| 2026-05-01 | Use subprocess IPC for skill bridge in Phase 1 | Lower risk than C ABI embedding; isolates Python crashes | C ABI embedding (deferred to Phase 2), HTTP API (higher latency) |
| 2026-05-01 | Keep all 5 Zig services as separate binaries | Matches nullclaw ecosystem architecture; each can be deployed independently | Monolithic single binary (too coupled), microservices with sidecars (overkill) |
| 2026-05-01 | Rebrand via automated script, not manual | 204K LOC makes manual rename error-prone; script is auditable and repeatable | Manual find-replace (error-prone), IDE refactoring (Zig IDE support is limited) |
| 2026-05-01 | Combine nullhub + nullclaw-chat-ui into single dashboard | Reduces operational complexity; both serve the same user at the same port | Separate services (more infra to manage), iframe embedding ( insecurity) |
| 2026-05-01 | Pin Zig 0.16.0 exact version | NullClaw is tested on 0.16.0; Zig is pre-1.0 with frequent breaking changes | Latest Zig (risk of breakage), Zig master (too unstable) |

---

## 8. Open Questions

| # | Question | Owner | Status | Decision Needed By |
|---|----------|-------|--------|-------------------|
| 1 | Should aizen-core be a single binary or support dynamic plugin loading for channels/tools? | Architect | Open | Sprint 2 |
| 2 | What is the minimum Python version for aizen-skill-bridge? (3.11 has tomllib, 3.10 doesn't) | PM | Open | Sprint 1 |
| 3 | How do we handle upstream nullclaw patches during Phase 1? Rebase or cherry-pick? | Lead Engineer | Open | Sprint 1 |
| 4 | Should the dashboard's management UI and chat UI share authentication state? | Architect | Open | Sprint 3 |
| 5 | What is the CI/CD target? GitHub Actions only, or also GitLab/Gitea? | DevOps | Open | Sprint 1 |
| 6 | Should we vendor nullclaw as a git subtree or git submodule? | Lead Engineer | Open | Sprint 1 |