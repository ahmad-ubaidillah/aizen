# Aizen Agent — Architecture Design

**Architect Agent** | Date: 2026-05-01
**Tagline:** Execute with Zen
**Base:** Aizen ecosystem (Zig) + Zeph (Rust) intelligence + Hermes (Python) skill breadth

---

## 1. Project Structure

```
aizen/
├── aizen-core/              # Core agent runtime (Zig) — forked from aizen
│   ├── src/
│   │   ├── aizen.zig        # Main entry (renamed from aizen.zig)
│   │   ├── agent/           # Agent loop, provider routing
│   │   ├── channels/        # 19+ messaging adapters
│   │   ├── memory/          # SYNAPSE graph memory (new) + existing engines
│   │   ├── security/        # 8-layer sanitization (new) + sandbox + vault
│   │   ├── skills/          # Skill loader + self-learning engine (new)
│   │   ├── tools/           # 35+ built-in tools
│   │   ├── compaction/      # HiAgent subgoal-aware (from Zeph)
│   │   ├── routing/         # Complexity triage + Thompson Sampling (new)
│   │   └── config/          # Config migration system (new)
│   ├── build.zig
│   └── build.zig.zon
├── aizen-dashboard/         # Management hub + chat UI — forked from aizen-dashboard + aizen-chat-ui
│   ├── src/
│   │   ├── hub/             # Process supervision, config, orchestration (Zig)
│   │   └── ui/              # Svelte 5 web dashboard + chat
│   └── package.json
├── aizen-watch/             # Observability — forked from aizen-watch
│   ├── src/
│   │   ├── span.zig         # Span ingest
│   │   ├── eval.zig         # Eval scoring
│   │   ├── otlp.zig         # OTLP ingest
│   │   └── api.zig           # HTTP API :7710
│   └── build.zig
├── aizen-kanban/            # Task tracking — forked from aizen-kanban
│   ├── src/
│   │   ├── pipeline.zig     # Pipeline FSM
│   │   ├── lease.zig        # Lease-based claiming
│   │   ├── kv.zig           # FTS5 KV store
│   │   └── api.zig           # 35+ REST endpoints
│   └── build.zig
├── aizen-orchestrate/       # Workflow engine — forked from aizen-orchestrate
│   ├── src/
│   │   ├── workflow.zig     # Graph engine (7 node types)
│   │   ├── reducer.zig      # 7 reducer types
│   │   ├── checkpoint.zig   # Checkpoint/replay/fork
│   │   └── api.zig           # REST + SSE streaming
│   └── build.zig
├── aizen-skill-bridge/      # Python skill runtime bridge
│   ├── aizen_skill_bridge/
│   │   ├── __init__.py
│   │   ├── loader.py        # SKILL.md parser (Hermes-compatible)
│   │   ├── executor.py      # Skill execution sandbox
│   │   ├── curator.py       # Self-learning + Wilson score ranking
│   │   └── registry.py      # Skill discovery and hot-reload
│   ├── pyproject.toml
│   └── requirements.txt
├── docs/
├── tests/
├── docker/
└── scripts/
```

---

## 2. Core Architecture

### 2.1 Language Decision: Zig (primary) + Python (skills)

**Zig for core runtime** because:
- 678 KB binary, <2ms startup, ~1MB RAM
- Vtable plugin system from Aizen proven at scale (5,640+ tests)
- C ABI interop for Python embedding
- Comptime configuration model fits agent config patterns
- Single static binary eliminates dependency hell

**Python for skill bridge** because:
- 25+ Hermes skill categories already in Python
- ML ecosystem lives in Python (embeddings, RAG, tokenizers)
- agentskills.io compatibility
- Rapid prototyping; skill authors don't need Zig

### 2.2 Vtable Plugin System (from Aizen)

All extension points are vtable interfaces:

```zig
pub const ProviderVTable = struct {
    chat_completion: *const fn(*Context, []const Message) Error![]const u8,
    stream_completion: *const fn(*Context, []const Message, StreamCallback) Error!void,
    embed: ?*const fn(*Context, []const u8) Error![]const f32,
    // ...
};

pub const ChannelVTable = struct { ... };
pub const ToolVTable = struct { ... };
pub const MemoryVTable = struct { ... };
pub const VaultVTable = struct { ... };
pub const SandboxVTable = struct { ... };
pub const CompactionVTable = struct { ... };
pub const RoutingVTable = struct { ... };
```

New vtables from Zeph/Hermes integration:

```zig
pub const SynapseVTable = struct {       // NEW: SYNAPSE graph memory
    store: *const fn(*Graph, Edge) Error!void,
    recall: *const fn(*Graph, []const u8, RecallOpts) Error![]const Edge,
    spread_activate: *const fn(*Graph, []const u8, f64) Error![]const Node,
    community_detect: *const fn(*Graph) Error![]const Community,
};

pub const SanitizationVTable = struct {  // NEW: 8-layer pipeline
    sanitize: *const fn(*Pipeline, []const u8) Error!SanitizedOutput,
    validate_output: *const fn(*Pipeline, []const u8) Error!ValidationResult,
};

pub const SkillBridgeVTable = struct {   // NEW: Python skill bridge
    load: *const fn([]const u8) Error!*Skill,
    execute: *const fn(*Skill, []const u8) Error![]const u8,
    hot_reload: *const fn([]const u8) Error!void,
    rank: *const fn([]const u8, []const f64) Error![]const RankedSkill,
};
```

### 2.3 Process Communication

All aizen-* services communicate via:
- **HTTP/REST** for synchronous operations (CRUD, queries)
- **SSE (Server-Sent Events)** for streaming (workflow progress, logs, chat)
- **SQLite** as embedded database (each service has its own)
- **mDNS** for auto-discovery (from AizenDashboard)

---

## 3. Service Architecture

### 3.1 aizen-core (Agent Runtime)

| Responsibility | Implementation |
|---|---|
| Provider routing | Vtable providers (50+) + complexity triage (Thompson Sampling from Zeph) |
| Channel adapters | 19+ channels from Aizen, plus Hermes extras (Home Assistant, Feishu, SMS) |
| Tool registry | 35+ built-in tools + Python skill bridge for Hermes skills |
| Memory | SYNAPSE graph memory (primary) + SQLite (fallback) + Qdrant (optional) |
| Security | 8-layer sanitization + 4 sandbox backends + age-encrypted vault |
| Compaction | HiAgent subgoal-aware eviction + ClawVM typed pages |
| MCP | Full MCP client + 17-pattern injection detection |
| ACP | ACP server for IDE integration (from Zeph) |

**API surface:**
- `:8080/api/v1/chat` — Main chat endpoint
- `:8080/api/v1/tools` — Tool registry
- `:8080/api/v1/memory` — Memory CRUD + SYNAPSE queries
- `:8080/api/v1/skills` — Skill management
- `:8080/api/v1/config` — Runtime configuration
- `:8080/api/v1/healthz` — Health check

### 3.2 aizen-dashboard (Hub + Chat UI)

| Responsibility | Implementation |
|---|---|
| Install wizard | Guided setup (from AizenDashboard) |
| Process supervision | Start/stop/crash recovery/backoff for aizen-core |
| Config management | Structured editors + raw JSON |
| Log streaming | Tail + SSE |
| Orchestration UI | Workflow editor, run monitoring, checkpoint forking, KV browser |
| Chat interface | Svelte 5 WebSocket + WebChannel E2E encryption |

**API surface:**
- `:3000/` — Dashboard SPA
- `:3000/api/instances` — Manage aizen-core instances
- `:3000/api/config` — Config management
- `:3000/api/logs` — Log streaming
- `:3000/api/workflows` — Orchestration proxy to aizen-orchestrate

### 3.3 aizen-watch (Observability)

| Responsibility | Implementation |
|---|---|
| Span ingest | Timed execution units with latency/error/token/cost tracking |
| Eval ingest | Scored assertions |
| Run summaries | Aggregated metrics per run |
| OTLP endpoint | OpenTelemetry compatible trace ingest |

**API surface:**
- `:7710/v1/spans` — Span ingest
- `:7710/v1/evals` — Eval ingest
- `:7710/v1/runs` — Run summaries
- `:7710/otlp/v1/traces` — OTLP ingest

### 3.4 aizen-kanban (Task Tracker)

| Responsibility | Implementation |
|---|---|
| Pipeline FSM | Stage transitions (triage → todo → ready → running → blocked → done) |
| Lease-based claiming | Heartbeat-based task acquisition |
| KV store | FTS5 full-text search on task metadata |
| Dependencies | Task dependency links |
| Agent assignments | Per-task agent assignment |

**API surface:**
- `:7720/v1/tasks` — Task CRUD (35+ endpoints)
- `:7720/v1/pipelines` — Pipeline management
- `:7720/v1/kv` — Key-value store with FTS5

### 3.5 aizen-orchestrate (Workflow Engine)

| Responsibility | Implementation |
|---|---|
| Graph workflow | 7 node types (task, agent, route, interrupt, send, transform, subgraph) |
| Unified state | 7 reducer types |
| Checkpoint/replay | Fork, resume, replay execution |
| SSE streaming | 5 streaming modes |
| Worker registration | Capacity + A2A-preference routing |

**API surface:**
- `:7730/v1/workflows` — Workflow CRUD
- `:7730/v1/runs` — Run lifecycle + SSE
- `:7730/v1/workers` — Worker registration

---

## 4. Memory Architecture (SYNAPSE from Zeph)

### 4.1 Graph Memory Layer

```
SYNAPSE Graph Memory
├── 5 Typed Edge Categories
│   ├── Causal (A caused B)
│   ├── Temporal (A happened before B)
│   ├── Semantic (A is related to B)
│   ├── CoOccurrence (A and B appeared together)
│   └── Hierarchical (A is parent of B)
├── MAGMA Embedding Technique
│   └── Typed edge embeddings with positional encoding
├── APEX-MEM Append-Only Property Graph
│   ├── Temporal supersession (newer facts override older)
│   └── Ontology normalization (multi-label entity dedup)
├── Retrieval Pipeline
│   ├── Spreading activation (hop-by-hop decay + lateral inhibition)
│   ├── Community detection (Leiden algorithm)
│   ├── BFS recall alongside vector results each turn
│   └── MMR reranking + LLM reranking
└── Admission Control
    └── SleepGate (RL-based) prevents noise from polluting long-term memory
```

### 4.2 Storage Backends (from Aizen + Zeph)

| Backend | Use Case | Priority |
|---|---|---|
| SQLite | Primary (always available) | Must-have |
| Qdrant | Vector search (optional) | Should-have |
| LanceDB | Vector search (embedded alternative) | Nice-to-have |
| PostgreSQL | Production scale | Should-have |
| Redis | Caching layer | Nice-to-have |

### 4.3 Compaction Pipeline (from Zeph)

```
3-Tier Compaction:
├── Tier 1: Window trimming (remove oldest messages in conversation window)
├── Tier 2: HiAgent subgoal-aware eviction (preserve context relevant to active goal)
└── Tier 3: Failure-driven compression (ACON — compress on error patterns)

ClawVM Typed Pages:
├── System page (immutable instructions)
├── Memory page (SYNAPSE recall results)
├── Tool page (tool outputs)
├── Context page (user context files)
└── Each page has fidelity invariant (min/max retention rules)
```

---

## 5. Security Architecture

### 5.1 Content Sanitization Pipeline (8 layers from Zeph)

```
Input → ContentSanitizer → PII Filter → GuardrailFilter → QuarantinedSummarizer
     → ResponseVerifier → ExfiltrationGuard → MemoryWriteValidator → TurnCausalAnalyzer → Output

Each layer:
├── ContentSanitizer: Remove/normalize harmful patterns
├── PII Filter: Detect and redact personal information
├── GuardrailFilter: Enforce safety policies
├── QuarantinedSummarizer: Summarize quarantined content for audit
├── ResponseVerifier: Verify response factual consistency (MARCH)
├── ExfiltrationGuard: Prevent data leakage
├── MemoryWriteValidator: Validate memory writes for quality
└── TurnCausalAnalyzer: Analyze turn causality for anomaly detection
```

### 5.2 Secrets Vault (from Zeph)

```
Age-Encrypted Vault
├── x25519 keypair per vault
├── age encryption for all stored secrets
├── Zeroizing buffers (secure memory wipe after use)
├── Atomic writes (no partial state)
├── Per-key trust levels (Trusted/Untrusted/Sandboxed)
└── TTL-bounded secret delegation for sub-agents
```

### 5.3 Sandbox (from Aizen)

```
4 Sandbox Backends:
├── Linux landlock (kernel-level, zero overhead)
├── firejail (namespace-based)
├── bubblewrap (lightweight namespace)
└── Docker (full isolation)
```

### 5.4 MCP Safety (from Zeph)

```
17-Pattern Injection Detection
├── SQL injection patterns
├── Command injection patterns
├── Path traversal patterns
├── SSRF validation
├── Pre-connect probing
├── Schema drift detection (attestation)
├── Embedding anomaly guard
└── MCP tool authorization (OAP)
```

---

## 6. Skill System Design

### 6.1 Hybrid Skill Architecture

```
Skill Types:
├── Native Skills (Zig) — Built into binary via vtable
│   ├── Shell, file ops, git, web search, browser, memory, cron, delegate
│   └── Zero-overhead, compiled into aizen-core
├── Python Skills (Bridge) — Loaded via aizen-skill-bridge
│   ├── SKILL.md format (Hermes-compatible YAML+Markdown)
│   ├── Hot-reload on edit
│   ├── BM25+cosine RRF retrieval (from Zeph)
│   └── agentskills.io compatibility
└── Self-Learning Skills (from Zeph)
    ├── Agent-as-a-Judge feedback detection
    ├── Wilson score Bayesian ranking (promotes skills that work)
    ├── Autonomous evolution on failure clusters
    ├── STEM pattern detection (recurring tool-use patterns)
    ├── REINFORCE MLP re-ranking
    └── Skill hot-reload on edit
```

### 6.2 Skill File Format (Hermes-compatible)

```yaml
---
name: my-skill
version: 1.0.0
category: devops
description: "Deploy to production"
triggers:
  - deploy
  - release
toolsets:
  - terminal
  - web
  - file
---
# My Skill

Steps:
1. Run tests
2. Build binary
3. Deploy to server
```

Loaded by `aizen-skill-bridge` Python runtime, executed in sandboxed subprocess.

---

## 7. Rebranding Plan

### 7.1 Service Name Mapping

| Original | New Name | Description |
|---|---|---|
| aizen | aizen-core | Core agent runtime |
| aizen-chat-ui | aizen-dashboard (chat component) | Web chat interface |
| aizen-dashboard | aizen-dashboard (hub component) | Management dashboard |
| aizen-watch | aizen-watch | Observability service |
| aizen-kanban | aizen-kanban | Task tracking service |
| aizen-orchestrate | aizen-orchestrate | Workflow orchestration |

### 7.2 Global Renames (Zig source)

| Pattern | Replace |
|---|---|
| `aizen` → `aizen` | All identifiers, comments, strings |
| `Aizen` → `Aizen` | PascalCase types, comments |
| `aizen_` → `aizen_` | Snake_case functions |
| `aizen-` → `aizen-` | CLI commands, package names |
| `aizen-dashboard` → `aizen-dashboard` | Hub service |
| `aizen-watch` → `aizen-watch` | Watch service |
| `aizen-kanban` → `aizen-kanban` | Tickets service |
| `aizen-orchestrate` → `aizen-orchestrate` | Boiler service |
| `AizenDashboard` → `AizenDashboard` | Hub types |
| `AizenWatch` → `AizenWatch` | Watch types |
| `AizenKanban` → `AizenKanban` | Tickets types |
| `AizenOrchestration` → `AizenOrchestrate` | Boiler types |

### 7.3 Config and Data Paths

| Original | New |
|---|---|
| `~/.aizen/` | `~/.aizen/` |
| `~/.aizen-dashboard/` | `~/.aizen/dashboard/` |
| `~/.aizen-watch/` | `~/.aizen/watch/` |
| `~/.aizen-kanban/` | `~/.aizen/kanban/` |
| `~/.aizen-orchestrate/` | `~/.aizen/orchestrate/` |
| `aizen.json` | `aizen.json` |
| `AIZEN_HOME` | `AIZEN_HOME` |
| `:8080` (aizen) | `:8080` (aizen-core) |
| `:3000` (aizen-dashboard) | `:3000` (aizen-dashboard) |
| `:7710` (aizen-watch) | `:7710` (aizen-watch) |
| `:7720` (aizen-kanban) | `:7720` (aizen-kanban) |
| `:7730` (aizen-orchestrate) | `:7730` (aizen-orchestrate) |

### 7.4 Branding Assets

- **Name:** Aizen Agent
- **Tagline:** Execute with Zen
- **Secondary:** Assign. Review. Repeat.
- **Avatar:** Jellyfish (ubur-ubur)
- **Colors:** Cyan #58A6FF (primary), Dark #0D1117 (background)
- **Logo:** Minimal jellyfish silhouette in cyan on dark

---

## 8. Integration Points

### 8.1 Zeph → Aizen (Rust concepts, Zig implementation)

| Zeph Feature | Integration Point | Implementation |
|---|---|---|
| SYNAPSE graph memory | `aizen-core/src/memory/synapse/` | Rewrite in Zig with same API surface |
| 8-layer sanitization | `aizen-core/src/security/sanitizer/` | Port pipeline architecture to Zig |
| Self-learning skills | `aizen-skill-bridge/curator.py` | Keep in Python (skill bridge) |
| HiAgent compaction | `aizen-core/src/compaction/hiagent.zig` | Port algorithm to Zig |
| Complexity triage | `aizen-core/src/routing/triage.zig` | Port Thompson Sampling + LinUCB |
| Age-encrypted vault | `aizen-core/src/security/vault.zig` | Port vault architecture to Zig |
| MCP injection detection | `aizen-core/src/security/mcp_guard.zig` | Port 17-pattern scanner |
| MARCH self-check | `aizen-core/src/security/march.zig` | Port Proposer+Checker pipeline |
| Sub-agent permissions | `aizen-core/src/agent/permissions.zig` | Port PermissionGrants + ToolPolicy |

### 8.2 Hermes → Aizen (Python runtime)

| Hermes Feature | Integration Point | Implementation |
|---|---|---|
| Skill SKILL.md format | `aizen-skill-bridge/loader.py` | Direct compatibility |
| 25+ skill categories | `aizen-skill-bridge/skills/` | Ported as Python plugins |
| Kanban task system | `aizen-kanban` API compatibility | Zig implementation, Hermes-compatible API |
| Gateway platform adapters | `aizen-core/src/channels/` | Port missing platforms (Home Assistant, Feishu, SMS) |
| Terminal backends | `aizen-core/src/runtimes/` | Port SSH, Daytona, Modal backends |
| Context file system | `aizen-core/src/context/` | Port SOUL.md / AGENTS.md loader |
| Curator system | `aizen-skill-bridge/curator.py` | Keep in Python |
| Session search | `aizen-core/src/memory/session.zig` | FTS5 + LLM summarization |

### 8.3 New Components (Not in any source)

| Component | Location | Description |
|---|---|---|
| Python skill bridge | `aizen-skill-bridge/` | Subprocess isolation, hot-reload, skill discovery |
| WebChannel E2E | `aizen-dashboard/src/ui/` | Already from Aizen |
| mDNS discovery | `aizen-dashboard/src/hub/discovery.zig` | Already from AizenDashboard |

---

## 9. Phased Roadmap

### Phase 1: MVP (v0.1) — "The Core"

**Goal:** Rebranded Aizen core agent running with basic features from all three sources.

| Feature | Source | Status |
|---|---|---|
| Core agent runtime | Aizen | Fork + rebrand |
| 19 messaging channels | Aizen | Direct |
| 35+ tools | Aizen | Direct |
| Vtable plugin system | Aizen | Direct |
| 4 sandbox backends | Aizen | Direct |
| SQLite memory engine | Aizen | Direct |
| WebChannel E2E encryption | Aizen | Direct |
| Rebranding aizen→aizen | New | Full rename |
| Python skill bridge | New (from Hermes pattern) | Minimal: SKILL.md loader + executor |
| Config paths ~/.aizen/ | New | Migration script |
| Dashboard (basic) | Aizen | Rebrand aizen-dashboard→aizen-dashboard |

**Timeline:** 4-6 weeks

### Phase 2: Intelligence (v0.5) — "The Brain"

**Goal:** Add Zeph's intelligence features and Hermes's skill ecosystem.

| Feature | Source | Effort |
|---|---|---|
| SYNAPSE graph memory (SQLite) | Zeph | High — rewrite in Zig |
| 8-layer sanitization pipeline | Zeph | High — port to Zig |
| Age-encrypted vault | Zeph | Medium — port vault.zig |
| Complexity triage routing | Zeph | Medium — Thompson Sampling in Zig |
| HiAgent context compaction | Zeph | Medium — algorithm port |
| MCP injection detection | Zeph | Medium — 17-pattern scanner |
| Self-learning skills (Wilson score) | Zeph (Python bridge) | Medium — in aizen-skill-bridge |
| MARCH self-check | Zeph | Low — 2-LLM pipeline |
| Sub-agent permission grants | Zeph | Medium — permission model |
| Hermes skill categories (25+) | Hermes | Low — Python skill files |
| Tree-sitter code indexing | Zeph | High — Zig FFI to tree-sitter |
| Watch service | Aizen | Rebrand aizen-watch→aizen-watch |
| Kanban service | Aizen | Rebrand aizen-kanban→aizen-kanban |

**Timeline:** 8-12 weeks

### Phase 3: Orchestration (v1.0) — "The Ecosystem"

**Goal:** Full ecosystem with workflow engine, observability, and production features.

| Feature | Source | Effort |
|---|---|---|
| Workflow engine (7 node types) | Aizen | Rebrand aizen-orchestrate→aizen-orchestrate |
| Orchestration UI | AizenDashboard | Port to aizen-dashboard |
| Dashboard chat UI | Aizen | Rebrand aizen-chat-ui |
| Session search (FTS5+LLM) | Hermes | Medium — in Zig |
| Context file system | Hermes | Low — SOUL.md/AGENTS.md loader |
| Credential pool | Hermes | Medium — multi-key load balancing |
| Batch trajectory generation | Hermes | Low — Python bridge |
| A2A protocol (IBCT tokens) | Zeph | Medium — capability tokens |
| ACP server | Zeph | Medium — stdio/HTTP+SSE/WS |
| Config migration system | Zeph | Low — diff+apply |
| TUI dashboard | Zeph + Hermes | High — ratatui + Ink hybrid |
| OTA updates | Aizen | Direct |
| Cross-compilation | Aizen | ARM, x86, RISC-V |
| Hardware peripherals | Aizen | Arduino, STM32, RPi |
| Self-experimentation | Zeph | Low — grid sweep tuning |
| Document RAG (PDF/md) | Zeph | Medium — PDF parser + Qdrant |

**Timeline:** 12-16 weeks

---

## 10. Tech Stack Decisions

| Layer | Technology | Rationale |
|---|---|---|
| Core runtime | Zig 0.16+ | Aizen's proven minimal footprint, vtable architecture, C interop |
| Skill runtime | Python 3.11+ | Hermes skill ecosystem compatibility, ML library availability |
| Skill bridge interface | C ABI | Zig↔Python FFI via cabi, zero-copy where possible |
| Dashboard UI | Svelte 5 + Runes | Aizen-chat-ui already uses it, reactive by default |
| Primary database | SQLite | Embedded, zero-config, always available, FTS5 support |
| Vector database | Qdrant (optional) | SYNAPSE full features need it; graceful degradation to SQLite |
| Graph database | SQLite property graph | APEX-MEM implementation on SQLite, portable |
| Object storage | Local filesystem | No cloud dependency |
| Service discovery | mDNS/Bonjour/Avahi | Auto-discovery on local network (from AizenDashboard) |
| Inter-service API | HTTP/REST + SSE | Simple, proven, curl-testable |
| Inter-service streaming | SSE (Server-Sent Events) | Unidirectional real-time, simpler than WebSocket |
| Encryption | age + X25519 + ChaCha20-Poly1305 | Zeph's vault + Aizen's WebChannel combined |
| Containerization | Docker (optional) | Not required (single binary), but supported for sandbox |
| CI | GitHub Actions | Standard, free for open source |
| Package format | Single static binary per service | Each aizen-* service is one binary |
| Config format | JSON (from Aizen) | Simpler than TOML/YAML for programmatic manipulation |

---

## Appendix A: Port Mapping

| Service | Port | Role |
|---|---|---|
| aizen-core | 8080 | Agent runtime API |
| aizen-dashboard | 3000 | Web UI + management |
| aizen-watch | 7710 | Observability API |
| aizen-kanban | 7720 | Task tracking API |
| aizen-orchestrate | 7730 | Workflow engine API |

## Appendix B: Environment Variables

```
AIZEN_HOME=~/.aizen
AIZEN_CORE_PORT=8080
AIZEN_DASHBOARD_PORT=3000
AIZEN_WATCH_PORT=7710
AIZEN_KANBAN_PORT=7720
AIZEN_ORCHESTRATE_PORT=7730
AIZEN_LOG_LEVEL=info
AIZEN_VAULT_KEY=          # age encryption key
AIZEN_SKILL_PATH=~/.aizen/skills/
AIZEN_MEMORY_ENGINE=sqlite  # sqlite|qdrant|postgres
```