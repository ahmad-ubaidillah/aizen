# AI Agent Ecosystem Comparison Report

**Researcher Agent Report** | Date: 2026-05-01
**Projects:** Aizen ecosystem, Zeph, Hermes Agent

---

## 1. Project Overviews

### 1.1 Aizen Ecosystem

A 6-repo Zig-based micro-ecosystem designed for extreme minimalism and edge deployment.

#### Aizen (Core Agent)
- **Language:** Zig 0.16.0
- **Size:** 678 KB static binary, ~1 MB RAM, <2ms startup, 5,640+ tests, ~230 source files, ~204K LOC
- **Architecture:** Vtable-driven modular plugin system — all extension points (providers, channels, tools, memory, tunnels, peripherals, observers, runtimes) are swappable interfaces
- **Providers:** 50+ AI providers (9 core + 41 OpenAI-compatible)
- **Channels:** 19 channels (Telegram, Discord, Slack, Signal, Matrix, WhatsApp, WeChat, DingTalk, Lark, QQ, IRC, iMessage, Teams, Nostr, LINE, MaixCam, email, web, stdio JSON-RPC)
- **Tools:** 35+ built-in tools (shell, file ops, git, web search with 7 providers, browser, memory store/recall/forget, screenshot, hardware peripherals, cron, delegate)
- **Memory:** 10 engine backends (SQLite, PostgreSQL, Redis, LanceDB, Qdrant, ClickHouse, Markdown, LRU, API, none) with vector search, MMR reranking, LLM reranking, adaptive retrieval, semantic cache, temporal decay
- **Security:** Pairing auth, 4 sandbox backends (Linux landlock, firejail, bubblewrap, Docker), command allowlists, workspace scoping, AEAD-encrypted secrets, URL HTTPS enforcement
- **Other:** MCP support, A2A protocol, subagents, streaming, voice, codex/claude CLI integration, cron scheduling, tunnel providers (Cloudflared, ngrok, Tailscale, custom), hardware peripherals (Arduino, STM32, RPi), OTA updates, WebChannel v1 with E2E encryption (X25519 + ChaCha20-Poly1305)

#### Aizen-Chat-UI
- **Language:** TypeScript/Svelte 5 (Runes API)
- **Stack:** SvelteKit 2, Vite 7, Vitest 4
- **Features:** WebSocket + WebChannel v1, PIN pairing, E2E X25519 key exchange + ChaCha20-Poly1305 streaming, tool timeline rendering, approval flow, session restore, theme persistence
- **Delivered as:** Static SPA, also available as CLI bundle

#### AizenDashboard (Management Hub)
- **Language:** Zig 0.16.0 with embedded Svelte 5 UI
- **Features:** Install wizard, process supervision (start/stop/crash recovery/backoff), health monitoring (HTTP health checks, dashboard cards), cross-component linking (AizenKanban ↦ AizenOrchestration), config management (structured editors + raw JSON), log viewing (tail + SSE streaming), one-click updates with rollback, multi-instance management, admin API for managed Aizen instances, orchestration UI (workflow editor, run monitoring, checkpoint forking, KV store browser)
- **Discovery:** mDNS/Bonjour/Avahi auto-discovery, falls back to localhost
- **Also has:** CLI for automation

#### AizenWatch (Observability)
- **Language:** Zig 0.16.0
- **Storage:** Local JSONL under `~/.aizen-watch/data`
- **API:** HTTP on :7710 — span ingest, eval ingest, run summaries (latency, errors, tokens, cost), OTLP/HTTP JSON ingest at `/v1/traces` and `/otlp/v1/traces`
- **Data model:** Spans (timed execution units), Evals (scored assertions), Run summaries (aggregated metrics)
- **Intentionally headless** — UI belongs in AizenDashboard

#### AizenKanban (Task Tracker)
- **Language:** Zig 0.16.0, SQLite (vendored, static)
- **Features:** Pipeline FSM with stage transitions, lease-based claim system with heartbeat, run event tracking, artifact attachment, KV store with FTS5 full-text search, bulk task creation, task dependencies, agent assignments, OpenAPI 3.1 schema, OTLP trace ingest, idempotent writes
- **API:** 35+ REST endpoints
- **Integration patterns:** Aizen only (sequential), AizenKanban + Aizen (durable backlog), full stack with AizenOrchestration

#### AizenOrchestration (Workflow Orchestrator)
- **Language:** Zig 0.16.0, SQLite (vendored)
- **Features:** Graph-based workflow execution (7 node types: task, agent, route, interrupt, send, transform, subgraph), unified state model (7 reducer types), checkpoint/replay/fork/resume, SSE streaming (5 modes), multi-turn agent loops with continuation_prompt, template rendering (state, input, item, config, store access), hot-reload workflow watcher, worker registration + capacity + A2A-preference routing, token accounting, MQTT and Redis dispatch, subprocess execution, workflow validation (reachability, cycles, state key refs), Mermaid diagram export, callbacks on step/run events
- **API:** 35+ REST endpoints including workflow CRUD, run lifecycle, SSE streaming, rate limits, admin drain

---

### 1.2 Zeph

- **Language:** Rust (MSRV 1.95), 29 crates, 8,849 tests
- **Binary:** ~15 MB, ~50ms startup, ~20 MB idle RAM
- **Architecture:** Workspace with 29 crates under `crates/`
- **License:** MIT OR Apache-2.0

#### Core Differentiators

**Graph Memory (SYNAPSE)**
- 5 typed edge categories: Causal, Temporal, Semantic, CoOccurrence, Hierarchical
- MAGMA embedding technique for typed edges
- APEX-MEM append-only property graph with temporal supersession and ontology normalization
- Spreading activation retrieval: hop-by-hop decay + lateral inhibition surfaces multi-hop connections
- Community detection clusters entities by topic
- BFS recall injected alongside vector results each turn

**Self-Learning Skills**
- Agent-as-a-Judge feedback detection (fast regex path + rate-limited LLM path)
- Wilson score Bayesian ranking promotes skills that actually work
- Autonomous skill evolution triggered by clustered failures
- SleepGate admission control (RL-based) prevents noise from polluting long-term memory
- Experiential Reflective Learning (ERL): heuristic extraction from completed tasks
- STEM: automatic detection of recurring tool-use patterns
- 2-layer MLP routing head (REINFORCE) for skill re-ranking
- Skill hot-reload on edit, BM25+cosine hybrid retrieval with RRF fusion

**Context Engineering**
- Three-tier compaction pipeline
- HiAgent subgoal-aware eviction (preserves context relevant to active subgoal)
- ClawVM typed pages with per-type fidelity invariants and compaction audit
- Failure-driven compression (ACON, ICLR 2026)
- MemReader quality gate scores memory writes on information value, reference completeness, contradiction risk

**Multi-Model Orchestration**
- Complexity triage routing (Simple/Medium/Complex/Expert)
- Thompson Sampling + LinUCB (PILOT) bandit for provider selection per query type
- Cascade cost tiers, plan template caching

**Security-First Architecture**
- 8-layer sanitization pipeline (ContentSanitizer, PII filter, GuardrailFilter, QuarantinedSummarizer, ResponseVerifier, ExfiltrationGuard, MemoryWriteValidator, TurnCausalAnalyzer)
- Age-encrypted vault (zeroizing buffers for in-memory secrets)
- Shell sandbox (macOS Seatbelt + Linux Landlock)
- 17-pattern MCP injection detection
- OAP tool authorization
- Per-session tool quota
- SSRF protection, exfiltration guards
- Trust levels for MCP servers (Trusted/Untrusted/Sandboxed)
- Attestation: schema drift detection between connections
- Embedding anomaly guard for post-call drift

**Sub-agents**
- Isolated agents with scoped tools
- Zero-trust TTL-bounded secret delegation (PermissionGrants)
- Persistent transcripts (JSONL)
- Lifecycle hooks (PreToolUse, PostToolUse, SubagentStart, SubagentStop)
- FilteredToolExecutor enforces per-agent ToolPolicy

**Other Key Features**
- ACP server (stdio/HTTP+SSE/WebSocket) for IDE integration
- A2A protocol with IBCT capability tokens
- Code indexing (tree-sitter AST + semantic search + repo map)
- Document RAG (txt, md, PDF → Qdrant)
- DAG-based task orchestration with LLM goal decomposition
- TUI dashboard (ratatui) with real-time metrics, security panel, plan view
- Config migration system (`zeph migrate-config --diff`)
- Self-experimentation engine (autonomous LLM config tuning via grid sweep)
- MARCH self-check (post-response factual consistency verification)
- `/recap` and `/loop` commands
- LSP integration (rust-analyzer, pyright, gopls)
- Plugin system (`zeph plugin add <url>`)
- Hybrid inference (Ollama, Claude, OpenAI, Gemini, any OpenAI-compatible API, Candle/GGUF for fully local)
- Memory 4-tier (Working/Episodic/Semantic/Persona)
- Cache (plan templates, semantic response cache)
- Token accounting per step and per run

---

### 1.3 Hermes Agent

- **Language:** Python 3.11+, ~12K LOC core (run_agent.py), ~11K LOC CLI (cli.py), 87K LOC state
- **Version:** 0.12.0
- **Built by:** Nous Research
- **License:** MIT

#### Core Differentiators

**Self-Improving Agent Loop**
- Autonomous skill creation after complex tasks
- Skills self-improve during use (curator system)
- FTS5 session search with LLM summarization for cross-session recall
- Honcho dialectic user modeling
- agentskills.io open standard compatible

**Rich Terminal UI**
- Ink (React) based TUI with multiline editing
- Slash-command autocomplete
- Streaming tool output with activity feed
- Skin engine for data-driven CLI theming
- `/compress`, `/usage`, `/insights` commands

**Gateway Architecture**
- Single gateway process for all messaging platforms
- 20+ platform adapters (Telegram, Discord, Slack, WhatsApp, Signal, Matrix, Mattermost, WeChat, WeCom, DingTalk, Feishu, QQ, Home Assistant, email, SMS, BlueBubbles, webhook, API server)
- DM pairing, command approval, streaming

**6 Terminal Backends**
- Local, Docker, SSH, Daytona, Modal, Singularity
- Serverless persistence (Daytona, Modal hibernate when idle)
- Runs on $5 VPS or GPU cluster

**MCP + ACP**
- Full MCP client support (`mcp_tool.py`, `mcp_oauth_manager.py`)
- ACP server for IDE integration (Zed, VS Code, JetBrains)

**Tool Ecosystem**
- 40+ tools including browser (CamoFox), image generation, TTS/STT, file ops, shell, web, code execution, kanban, Feishu docs, Home Assistant, Discord tools, delegate, mixture-of-agents, credential pool
- Terminal backends with tool-accessible environments

**Cron Scheduler**
- Built-in cron/interval scheduling with delivery to any platform
- Natural language cron jobs

**Other Features**
- Subagent delegation (spawn parallel workstreams, Python RPC scripts)
- Batch trajectory generation (Atropos RL environments)
- Trajectory compression for training
- OpenClaw migration wizard
- Context file system (project context shaping every conversation)
- Multi-model support with provider routing
- Reasoning model support (Codex, Gemini Cloud Code, Claude, o3, etc.)
- Image generation routing
- Bedrock adapter
- Mixture-of-agents tool
- Rate limiting with nous_rate_guard
- Context compressor with manual feedback

---

## 2. Comparison Matrix

### 2.1 What Aizen HAS that Hermes Lacks

| Feature | Aizen | Hermes Gap |
|---------|----------|------------|
| **Extreme binary minimalism** | 678KB static binary, ~1MB RAM, <2ms boot | Hermes requires Python 3.11+ runtime, uv, and many pip packages; much heavier footprint |
| **Vtable plugin architecture** | All extension points (providers, channels, tools, memory, tunnels, peripherals) are swappable vtable interfaces compiled into the binary | Hermes uses dynamic plugin directory + tool registry; not as cleanly swappable or typed at compile time |
| **19 messaging channels** | Telegram, Discord, Slack, Signal, Matrix, WhatsApp, WeChat, DingTalk, Lark, QQ, IRC, iMessage, Teams, Nostr, LINE, MaixCam, email, web, stdio JSON-RPC | Hermes has ~20+ platforms but missing IRC, iMessage, Nostr, LINE, MaixCam, stdio JSON-RPC; has extras like Home Assistant, Feishu, SMS |
| **WebChannel v1 protocol** | Standardized WebSocket protocol with PIN pairing, E2E X25519 + ChaCha20-Poly1305 encryption | Hermes gateway uses per-platform protocols; no unified E2E encryption layer |
| **4 OS sandbox backends** | Linux landlock, firejail, bubblewrap, Docker | Hermes relies on Docker only for sandboxed execution |
| **Hardware peripherals** | Arduino, STM32/Nucleo, RPi GPIO (I2C, SPI) | No hardware peripheral support |
| **OTA updates** | Built-in update system (`aizen update`) | Hermes has `hermes update` but less integrated with the binary |
| **AizenDashboard management UI** | Full web UI for install, config, monitoring, orchestration, log streaming, one-click updates with rollback | Hermes has no equivalent management dashboard |
| **AizenWatch observability** | Structured span/eval ingest, run summaries, OTLP trace endpoint, cost/latency/error tracking | Hermes has no dedicated observability layer; relies on logging |
| **AizenKanban task tracking** | Pipeline FSM, lease-based claiming with heartbeat, artifact attachment, KV store with FTS5, dependencies, idempotent writes | Hermes has no equivalent durable task tracker |
| **AizenOrchestration orchestration** | Graph-based workflow engine (7 node types, 7 reducers, checkpoints, replay, fork, resume, subgraphs, SSE streaming, workflow hot-reload, Mermaid export) | Hermes has no DAG workflow engine; subagents are ad-hoc |
| **Zero-dependency deployment** | Single static binary, no runtime | Hermes needs Python, pip packages, and system dependencies |
| **Cross-compilation** | ARM, x86, RISC-V targets | Hermes deployment is Python-centric |

### 2.2 What Zeph HAS that Aizen Lacks

| Feature | Zeph | Aizen Gap |
|---------|------|--------------|
| **SYNAPSE graph memory** | 5 typed edge categories (Causal, Temporal, Semantic, CoOccurrence, Hierarchical) with spreading activation, community detection, BFS recall | Aizen has vector search (Qdrant, LanceDB) + adaptive retrieval but no typed graph memory |
| **Self-learning skill evolution** | Agent-as-a-Judge, Wilson score Bayesian ranking, autonomous evolution on failure clusters, ERL heuristic extraction, STEM pattern detection, REINFORCE MLP re-ranking | Aizen has SkillForge (skill discovery) but not self-learning / self-improving skills |
| **HiAgent context compaction** | Subgoal-aware eviction preserving context relevant to active task, 3-tier pipeline, ClawVM typed pages with fidelity invariants | Aizen has agent/compaction.zig but not subgoal-aware |
| **8-layer sanitization pipeline** | ContentSanitizer → PII filter → GuardrailFilter → QuarantinedSummarizer → ResponseVerifier → ExfiltrationGuard → MemoryWriteValidator → TurnCausalAnalyzer | Aizen has security/policy.zig and sandbox but not layered content sanitization |
| **Age-encrypted vault** | x25519 keypair + age-encrypted JSON, zeroizing buffers, per-key trust levels | Aizen has AEAD-encrypted secrets but not the zeroizing vault pattern |
| **MCP injection detection** | 17-pattern scanner, SSRF validation, pre-connect probing, attestation (schema drift detection), embedding anomaly guard | Aizen has MCP support but no injection detection layer |
| **MARCH self-check** | Post-response factual consistency verification (Proposer+Checker LLM pipeline) | No equivalent |
| **Complexity triage routing** | Simple/Medium/Complex/Expert tiers, Thompson Sampling + LinUCB bandit, cascade cost tiers | Aizen has provider routing but not ML-based complexity triage |
| **Tree-sitter code indexing** | AST-based chunking, semantic retrieval, repo map generation, MCP server exposing code tools | No equivalent |
| **Document RAG** | PDF/txt/md ingestion → Qdrant with auto-retrieval per turn | Aizen has RAG (`src/rag.zig`) but less document-type support |
| **ACP server for IDE integration** | stdio/HTTP+SSE/WebSocket transports, ACP SDK Agent implementation | Aizen has no ACP server |
| **A2A with IBCT tokens** | HMAC-SHA256 scoped delegation tokens, agent discovery via `/.well-known/agent.json` | Aizen has a2a.zig but not IBCT capability tokens |
| **Config migration** | `zeph migrate-config --diff` previews and applies config upgrades | No equivalent (Aizen uses from_json bootstrap) |
| **Self-experimentation** | Autonomous LLM config tuning via grid sweep, random sampling, neighborhood search | No equivalent |
| **Sub-agent permission grants** | Zero-trust TTL-bounded grants with ToolPolicy enforcement | Aizen has subagent_runner.zig but no equivalent permission model |
| **TUI dashboard** | ratatui-based with real-time metrics, security panel, plan view, multi-session support | Aizen is CLI-only (no TUI); AizenDashboard provides web dashboard |

### 2.3 What Hermes HAS that Aizen Lacks

| Feature | Hermes | Aizen Gap |
|---------|--------|--------------|
| **Skill system with learning loop** | 25+ built-in skill categories, autonomous creation from experience, agentskills.io compatibility, skill self-improvement during use | Aizen has SkillForge (discovery) but not autonomous creation/improvement from experience |
| **Honcho dialectic user modeling** | Cross-session user understanding via dialectic modeling | No equivalent |
| **FTS5 session search** | LLM-summarized full-text search across all past sessions | Aizen has memory/engines/sqlite.zig with search but not cross-session LLM-summarized recall |
| **Rich terminal UI (Ink/React)** | Multiline editing, slash autocomplete, streaming tool output, skin theming, `--tui` mode | Aizen CLI is minimal; no TUI mode |
| **20+ messaging platforms** | Extensive platform coverage including Home Assistant, Feishu docs, SMS, BlueBubbles, webhook, API server | Aizen has 19 channels but missing some Hermes-specific ones |
| **6 terminal backends** | Local, Docker, SSH, Daytona, Modal, Singularity with serverless persistence | Aizen has runtime.zig (native, Docker, WASM, Cloudflare) but not SSH/Daytona/Modal |
| **Batch trajectory generation** | Atropos RL environments, parallel batch processing, trajectory compression | No equivalent |
| **Context file system** | Project context files (SOUL.md, AGENTS.md) shaping every conversation | Aizen uses config-based context but not the same file-based system |
| **OpenClaw migration** | Built-in migration wizard for users coming from OpenClaw | No equivalent |
| **Curator system** | Skill quality management, deduplication, improvement tracking | No equivalent |
| **Mixture-of-agents tool** | Multi-model consensus via structured tool call | No equivalent |
| **Image generation routing** | Multi-provider image generation with Fal, DALL-E, local | Aizen has image.zig tool but less routing sophistication |
| **Voice mode** | TTS/STT with Edge TTS (free) + ElevenLabs (premium) | Aizen has voice.zig but less integration |
| **Kanban board** | Built-in kanban task management tool | No equivalent |
| **Plugin system** | Memory providers (honcho, mem0, supermemory), context engines, dashboards, Spotify | No equivalent plugin system |
| **Guild/Yuanbao** | Chinese platform integrations (Yuanbao/WeChat group bridging) | Aizen has QQ/WeChat but not the same Yuanbao integration |
| **Credential pool** | Multi-credential load balancing for API calls | No equivalent (Aizen uses single API keys per provider) |

### 2.4 What Zeph HAS that Hermes Lacks

| Feature | Zeph | Hermes Gap |
|---------|------|------------|
| **SYNAPSE graph memory** | 5-edge typed graph with spreading activation, community detection, BFS recall | Hermes has SQLite FTS5 + Honcho but no graph memory |
| **Age-encrypted vault** | zeroizing buffers, atomic writes, age encryption for all secrets | Hermes uses .env file for API keys; no encrypted vault |
| **Sub-agent permission grants** | Zero-trust TTL-bounded grants, filtered tool policies per sub-agent | Hermes delegates to sub-agents with same tool access |
| **Tree-sitter code indexing** | AST-based RAG, repo map, MCP tool server for code intelligence | Hermes relies on external tools (ripgrep, file read) for code awareness |
| **Self-experimentation** | Autonomous LLM config tuning (grid sweep, random, neighborhood) | No equivalent |
| **MARCH self-check** | Post-response factual consistency (Proposer+Checker LLM pipeline) | No equivalent |
| **Complexity triage** | ML-based routing (Thompson Sampling, LinUCB) per query complexity | Hermes uses provider routing but not ML-based triage |
| **Config migration** | Automated config upgrade with `--diff` preview | No equivalent |
| **Workflow DAG orchestrator** | Built-in DAG execution with LLM planner, plan caching | No equivalent (Hermes subagents are ad-hoc) |
| **Document RAG** | PDF/txt/md ingestion with auto-retrieval | Hermes has no native document ingestion |
| **LSP integration** | Compiler-level code intelligence via rust-analyzer, pyright, gopls | No equivalent |
| **Compiled binary** | ~15 MB single Rust binary, ~50ms startup, ~20 MB idle | Hermes is Python; requires runtime |
| **Session recap** | `/recap` + auto-summary on session resume | Hermes has `/compress` but not auto-recap on resume |

---

## 3. Architecture Comparison

| Dimension | Aizen | Zeph | Hermes |
|-----------|----------|------|--------|
| **Language** | Zig 0.16.0 | Rust (MSRV 1.95) | Python 3.11+ |
| **Binary size** | 678 KB | ~15 MB | N/A (Python) |
| **RAM** | ~1 MB idle | ~20 MB idle | ~150-300 MB |
| **Startup** | <2 ms | ~50 ms | ~2-5 s |
| **Test count** | 5,640+ | 8,849 | ~15,000+ |
| **Architecture** | Vtable plugin monolith | 29-crate workspace | Monolithic Python scripts |
| **Config format** | JSON | TOML | YAML |
| **Database** | SQLite, pluggable engines | SQLite + PostgreSQL + Qdrant | SQLite |
| **Extensions** | Vtable interfaces (compiled) | Feature flags + crates | Tool registry + plugins |
| **Deployment** | Single binary, any $5 board | Single binary | Python venv + pip packages |
| **Web UI** | AizenDashboard (separate) | TUI (ratatui) + web gateway | Ink TUI |
| **Ecosystem** | 6 integrated services | Single binary | Single repo |

---

## 4. Recommended Feature Combination for Aizen

Based on the analysis, here are the recommended features to combine into the new Aizen agent, organized by priority tier:

### Tier 1: Must-Have (Core Differentiators)

| Feature | Source | Reasoning |
|---------|--------|-----------|
| **SYNAPSE graph memory** | Zeph | The 5-edge typed memory with spreading activation is the most sophisticated memory architecture of all three. It enables "why" reasoning, not just "what" recall. Essential for a self-improving agent. |
| **Self-learning skills** | Zeph | Wilson score Bayesian ranking + autonomous evolution on failure clusters + ERL heuristic extraction creates a closed learning loop that none of the others match. |
| **Vtable/plugin architecture** | Aizen | Clean swappable interfaces for all subsystems. Combine with Zeph's crate modularity and Hermes's plugin system. |
| **Skill system** | Hermes | Hermes's skill system (25+ built-in categories, autonomous creation, agentskills.io compatibility, curator) is the most mature. Port to a compiled language. |
| **Multi-channel gateway** | Aizen + Hermes | Combine Aizen's 19 channels with Hermes's platform adapters. The WebChannel v1 E2E encryption is unique. |
| **8-layer sanitization** | Zeph | The defense-in-depth content pipeline (ContentSanitizer → PII filter → GuardrailFilter → QuarantinedSummarizer → ResponseVerifier → ExfiltrationGuard → MemoryWriteValidator → TurnCausalAnalyzer) is the most comprehensive security model. |
| **Age-encrypted vault** | Zeph | Zeroizing buffers + atomic writes + age encryption is superior to Hermes's .env approach and Aizen's AEAD approach. |
| **Sub-agent permission grants** | Zeph | Zero-trust TTL-bounded grants with per-agent ToolPolicy is more secure than all-or-nothing delegation. |

### Tier 2: Should-Have (Strong Differentiators)

| Feature | Source | Reasoning |
|-----------|--------|-----------|
| **AizenOrchestration workflow engine** | Aizen | Graph-based orchestration (7 node types, checkpoints, replay, fork) with SSE streaming is more powerful than Zeph's DAG or Hermes's ad-hoc subagents. |
| **AizenKanban task tracker** | Aizen | Pipeline FSM + lease-based claiming with heartbeat + KV store with FTS5 gives a proper durable task backbone. |
| **AizenWatch observability** | Aizen | Structured span/eval ingest with OTLP support is critical for production. Must have a headless observability layer. |
| **AizenDashboard management dashboard** | Aizen | Process supervision, config editors, log streaming, one-click updates with rollback, orchestration UI — operators need this. |
| **Complexity triage routing** | Zeph | Thompson Sampling + LinUCB bandit for provider selection per query type is a quantitative improvement over static routing. |
| **HiAgent context compaction** | Zeph | Subgoal-aware eviction, 3-tier pipeline, failure-driven compression (ACON) is the state of the art for context management. |
| **MCP with injection detection** | Zeph | 17-pattern scanner + SSRF validation + attestation + embedding anomaly guard makes MCP safe for production. |
| **Tree-sitter code indexing** | Zeph | AST-based RAG with repo map generation enables intelligent code assistance. |
| **MARCH self-check** | Zeph | Post-response factual consistency verification is a quality guarantee mechanism. |
| **6 terminal backends** | Hermes | Local, Docker, SSH, Daytona, Modal, Singularity with serverless persistence. |
| **TUI dashboard** | Zeph + Hermes | Combine Zeph's ratatui real-time metrics/security panel with Hermes's Ink interactive editing. |
| **Config migration** | Zeph | Automated config upgrade with diff preview. Essential for long-term maintainability. |

### Tier 3: Nice-to-Have (Platform Completeness)

| Feature | Source | Reasoning |
|---------|--------|-----------|
| **Batch trajectory generation** | Hermes | Atropos RL environments useful for training but niche. |
| **Honcho dialectic user modeling** | Hermes | Interesting but can be replaced by SYNAPSE's graph memory. |
| **Hardware peripherals** | Aizen | Arduino, STM32, RPi GPIO — valuable for IoT/edge use cases. |
| **Mermaid workflow export** | AizenOrchestration | Nice visualization for workflow debugging. |
| **Self-experimentation** | Zeph | Autonomous config tuning is novel but not essential for v1. |
| **LSP integration** | Zeph | Nice for developer experience but external tool territory. |
| **Document RAG (PDF)** | Zeph | Useful for knowledge ingestion; can start with txt/md. |
| **A2A with IBCT tokens** | Zeph | Important for multi-agent ecosystems but can come later. |
| **ACP server** | Zeph | IDE integration is important for developer adoption. |
| **Cron scheduling** | All three | All have it; standardize on one implementation. |
| **WebChannel E2E encryption** | Aizen | PIN pairing + X25519 + ChaCha20-Poly1305 is the best chat security model. |

---

## 5. Recommended Aizen Architecture

### Language Choice: Zig (primary) with Python skill runtime

**Why Zig (from Aizen):**
- 678 KB binary, <2ms startup, ~1MB RAM enables edge deployment
- Vtable architecture gives clean plugin boundaries
- Single static binary eliminates dependency hell
- Zig's comptime model fits agent configuration well
- C interoperability for Python embedding (skill runtime)

**Why Python skill runtime (from Hermes):**
- 25+ skill categories with active community
- agentskills.io compatibility
- Rapid skill prototyping
- Python is where the ML ecosystem lives

### Service Architecture (from Aizen ecosystem)

```
aizen-core          (Zig) — Agent runtime, providers, channels, tools, memory
aizen-hub           (Zig + Svelte) — Management dashboard, process supervision, config
aizen-watch         (Zig) — Observability, traces, evals, cost tracking
aizen-tickets       (Zig + SQLite) — Durable task tracking, pipeline FSM, leases
aizen-orchestrate   (Zig + SQLite) — Graph-based workflow engine, checkpoints, SSE
aizen-chat-ui       (Svelte 5) — Web chat interface with E2E encryption
```

### Memory Architecture (from Zeph)

```
SYNAPSE Graph Memory
├── 5 edge types (Causal, Temporal, Semantic, CoOccurrence, Hierarchical)
├── Spreading activation retrieval
├── Community detection
├── BFS recall alongside vector results
└── Admission control (SleepGate)

Semantic Memory
├── SQLite (primary) + PostgreSQL + Qdrant (optional)
├── MMR re-ranking, temporal decay
├── HiAgent subgoal-aware compaction
└── MemReader quality gate
```

### Security Architecture (from Zeph + Aizen)

```
Content Pipeline (Zeph's 8 layers):
  ContentSanitizer → PII filter → GuardrailFilter → QuarantinedSummarizer
  → ResponseVerifier → ExfiltrationGuard → MemoryWriteValidator → TurnCausalAnalyzer

Sandbox (Aizen's 4 backends):
  Linux landlock | firejail | bubblewrap | Docker

Vault (Zeph's age encryption):
  x25519 keypair + age-encrypted JSON + zeroizing buffers + atomic writes

MCP Safety (Zeph):
  17-pattern injection detection + SSRF + attestation + embedding anomaly guard
```

### Skill System (from Hermes + Zeph)

```
Hermes-style skill files (SKILL.md YAML+Markdown)
+ Zeph's self-learning (Wilson score, ERL, STEM, REINFORCE MLP)
+ Hermes's autonomous creation from experience
+ Hermes's curator system for quality management
+ agentskills.io compatibility
+ Zeph's hot-reload and BM25+cosine RRF retrieval
```

---

## 6. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Zig is niche — fewer contributors than Python/Rust | Maintain Python skill runtime for community contributions; Zig core stays small |
| Rewriting Hermes's 87K LOC of Python is massive | Start with key subsystems (memory, security, channels); Python skill runtime bridges the gap |
| Zeph's 29-crate architecture is highly modular but complex | Aizen should use Aizen's simpler vtable approach internally, borrowing Zeph's concepts not crate structure |
| E2E encryption (Aizen) requires browser WebCrypto | Progressive enhancement — fallback to server-side encryption for older browsers |
| Graph memory (SYNAPSE) requires Qdrant for full feature set | Graceful degradation to SQLite-only mode (like Zeph's DbVectorStore fallback) |
| AizenOrchestration's workflow engine is Zig-specific | Consider API-first design so orchestration can be consumed by any agent runtime |

---

## 7. Summary

**Aizen** excels at: extreme minimalism, deployment flexibility, ecosystem completeness (6 services covering agent runtime, management, observability, task tracking, orchestration, and chat UI), and WebChannel E2E encryption.

**Zeph** excels at: sophisticated memory (SYNAPSE graph), self-learning skills, multi-layer security (8-layer sanitization), age-encrypted vault, complexity-aware routing, code indexing, and typed sub-agent permissions.

**Hermes** excels at: rich skill ecosystem (25+ categories), TUI experience, gateway breadth (20+ platforms), terminal backend diversity (6 environments), batch RL training, community (agentskills.io), and the self-improving learning loop.

**Aizen should** combine:
1. Aizen's Zig vtable architecture and minimal footprint
2. Zeph's SYNAPSE graph memory, security pipeline, and self-learning skills
3. Hermes's skill ecosystem, gateway breadth, and learning loop
4. Aizen's ecosystem services (Hub, Watch, Tickets, Boiler, Chat-UI) as optional components
5. A Python skill runtime bridge for backward compatibility with Hermes skills