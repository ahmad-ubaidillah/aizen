# Aizen Agent — Comprehensive Gap Analysis

> Generated: 2026-05-01 | Comparing: Aizen vs Hermes vs OMNI vs Zeph vs Aizen vs RTK

## 1. Executive Summary

Aizen is a Zig-based autonomous AI agent forked from Aizen, rebranded and enhanced with OMNI integration, tool pruning, prompt caching, and a Python skill bridge. With 319K+ lines of Zig code across 6 services, Aizen has a solid foundation. However, several critical gaps remain compared to the 5 reference systems.

**Key Finding**: Aizen has 402 stale brand references (290 in markdown, 112 in Zig source) that need cleanup. The documentation is outdated, referencing aizen/aizen-dashboard/aizen-watch/aizen-kanban/aizen-orchestrate instead of aizen. Feature-wise, Aizen lacks self-learning skills (from Zeph), DAG task orchestration (from Zeph), structured command rewriting (from RTK), and the breadth of Hermes's ecosystem (profiles, kanban, TUI, plugins).

---

## 2. Feature Matrix

| Feature | Aizen | Hermes | OMNI | Zeph | Aizen | RTK |
|---|---|---|---|---|---|---|
| **Core Language** | Zig | Python | Rust | Rust | Zig | Rust |
| **Agent Loop** | ✓ Full | ✓ Full | ✗ (filter) | ✓ Full | ✓ Full | ✗ (proxy) |
| **Binary Size** | ~678KB* | ~50MB+ | Standard | ~15MB | 678KB | Standard |
| **RAM Usage** | ~1MB* | ~200MB+ | N/A | ~50MB | ~1MB | Minimal |
| **Startup Time** | <2ms* | ~2-5s | N/A | ~50ms | <2ms | Instant |
| **Memory System** | ✓ 10 backends | ✓ Built-in | ✓ Session+SQLite | ✓ SYNAPSE graph | ✓ 10 backends | ✗ None |
| **Tool System** | ✓ 42 tools | ✓ 86+ tools | ✗ (MCP provider) | ✓ ToolExecutor trait | ✓ 35+ tools | ✗ (filter) |
| **Skills/Plugins** | ✓ SkillForge+loader | ✓ 26 skill categories | ✗ | ✓ Self-learning YAML | ✓ SkillForge+TOML/JSON | ✗ |
| **Multi-Agent** | ✓ subagent+A2A | ✓ delegate+kanban | ✓ Shared streams | ✓ A2A+sub-agents | ✓ subagents+A2A | ✗ |
| **Profiles/Personas** | ✓ Named profiles | ✓ 22 profiles | ✗ Per-agent TOML | ✓ Skills+hot-reload | ✓ Named+OpenClaw | ✗ |
| **Cron/Scheduling** | ✓ Full cron | ✓ Full cron | ✗ | ✓ zeph-scheduler | ✓ Full cron | ✗ |
| **MCP Support** | ✓ Client+Server | ✓ Native client | ✓ MCP provider | ✓ MCP+OAuth | ✓ Client | ✗ |
| **Channels** | ✓ 19 channels | ✓ Telegram/Discord/Slack | ✗ (hooks) | ✓ 5 channels | ✓ 19 channels | ✗ (terminal) |
| **Web UI/Dashboard** | ✓ (aizen-dashboard) | ✓ Gateway+Dashboard | ✗ | ✗ (TUI only) | ✓ WebChannel | ✗ |
| **Kanban/Tasks** | ✓ (aizen-kanban) | ✓ Plugin (SQLite) | ✗ | ✓ DAG tasks+plans | ✗ (cron only) | ✗ |
| **Monitoring/Watch** | ✓ (aizen-watch) | ✗ | ✓ Distill Monitor | ✓ TUI dashboard | ✓ Observer vtable | ✓ rtk gain/stats |
| **Orchestration** | ✓ (aizen-orchestrate) | ✗ | ✗ | ✓ (sub-agent) | ✗ | ✗ |
| **Token Optimization** | ✓ OMNI bridge+pruning | ✓ Context compression | ✓ 90% distillation | ✓ 3-tier compaction | ✓ Compaction only | ✓ 60-90% rewrite |
| **Prompt Caching** | ✓ Anthropic cache | ✓ Built-in | ✗ | ✗ | ← Aizen addition | ✗ |
| **Tool Pruning** | ✓ 30-50% savings | ✗ | ✗ | ✗ | ← Aizen addition | ← RTK filter approach |
| **Security** | ✓ ChaCha20+Landlock | ✓ Basic | ✓ Filtering | ✓ 17-pattern+vault | ✓ ChaCha20+Landlock | ✗ Basic |
| **Self-Learning/Evolve** | ✗ | ✗ | ✗ | ✓ Wilson score+Bayes | ✓ SkillForge discovery | ✗ |
| **DAG Task Orchestration** | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |
| **Structured Cmd Rewrite** | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ 100+ filters |
| **Credential Pool** | ✗ | ✓ Multi-key rotation | ✗ | ✓ Per-session quota | ✗ | ✗ |
| **Rate Limiting** | ✗ | ✓ Built-in | ✗ | ✓ | ✗ | ✗ |
| **Model Routing** | ✓ Basic | ✓ Metadata+smart | ✗ | ✓ | ✓ | ✗ |
| **Plugins** | ✗ | ✓ Plugin system | ✗ | ✗ | ✗ | ✗ |
| **TUI** | ✗ | ✓ Curses/Ink | ✗ | ✓ ratatui dashboard | ✗ | ✗ |
| **Documentation** | ⚠ Stale (aizen refs) | ✓ Comprehensive | ✓ Good | ✓ mdBook | ✓ Bilingual | ✓ Good |

*Inherited from Aizen base

---

## 3. What Aizen Already Has

| # | Feature | Source | Details |
|---|---|---|---|
| 1 | Full Agent Loop | Aizen | 10K-line agent root, dispatcher, compaction |
| 2 | 19 Channels | Aizen | Telegram, Discord, Slack, WhatsApp, Matrix, IRC, etc. |
| 3 | 50+ LLM Providers | Aizen | Anthropic, OpenAI, Gemini, Ollama, OpenRouter, etc. |
| 4 | 42 Tools | Aizen + Aizen | shell, file ops, browser, git, memory, web search, cron, delegate, etc. |
| 5 | 10 Memory Backends | Aizen | SQLite, Markdown, ClickHouse, PostgreSQL, Redis, LanceDB, etc. |
| 6 | MCP Client | Aizen | stdio + HTTP transport |
| 7 | Security Sandbox | Aizen | ChaCha20-Poly1305, Landlock, Firejail, Bubblewrap |
| 8 | Cron Scheduling | Aizen | Full cron expressions + one-shot timers |
| 9 | Web Dashboard | aizen-dashboard | WebSocket browser UI, relay transport |
| 10 | Kanban Board | aizen-kanban | Task management (from aizen-kanban) |
| 11 | Monitoring | aizen-watch | Observer vtable, Prometheus/OTel |
| 12 | Orchestration | aizen-orchestrate | Multi-bot dispatch, MQTT/Redis |
| 13 | OMNI Integration | Aizen (NEW) | bridge.zig, hook.zig — semantic distillation |
| 14 | Tool Pruning | Aizen (NEW) | tool_pruning.zig — 30-50% token savings |
| 15 | Prompt Caching | Aizen (NEW) | prompt_cache.zig — Anthropic cache_control |
| 16 | Skill Loader | Aizen (NEW) | SKILL.md parser, Hermes-compatible |
| 17 | SkillForge | Aizen | GitHub skill discovery + evaluation |
| 18 | A2A Protocol | Aizen | Multi-agent communication v0.3.0 |
| 19 | Subagent Spawning | Aizen | /subagents spawn, bindings/routing |
| 20 | Config System | Aizen | 7.5K-line config, mutator, paths, types |
| 21 | Compaction | Aizen | Auto-context compaction (842 lines) |
| 22 | Python Skill Bridge | Aizen (NEW) | 733 LOC, runs Hermes-compatible skills |

---

## 4. What Aizen Is Missing (Gaps)

### CRITICAL (Must-Have)

| # | Gap | Source System | Impact | Effort |
|---|---|---|---|---|
| G1 | **Self-Learning Skills** | Zeph | Skills that evolve via Wilson score + Bayesian ranking from usage data. Aizen has SkillForge (discovery) but not self-learning. | 5-7 days |
| G2 | **Credential Pool / Multi-Key Rotation** | Hermes | Rotate multiple API keys automatically, avoiding rate limits. | 2-3 days |
| G3 | **Plugin System** | Hermes | Runtime-loadable plugins for extending agent capabilities without recompilation. | 4-5 days |
| G4 | **TUI (Terminal UI)** | Hermes/Zeph | Interactive terminal dashboard for monitoring, chat, and control. | 5-7 days |
| G5 | **Documentation Cleanup** | Internal | 402 old brand references, stale Aizen docs. | 1-2 days |
| G6 | **Structured Output Rewriting** | RTK | Intelligent filtering of tool output beyond pruning — 4 strategies (filter, group, truncate, deduplicate). | 3-4 days |

### HIGH (Should-Have)

| # | Gap | Source System | Impact | Effort |
|---|---|---|---|---|
| G7 | **DAG Task Orchestration** | Zeph | Directed Acyclic Graph task execution with parallel/sequential steps, plan templates. | 5-7 days |
| G8 | **MCP Injection Detection** | Zeph | 17-pattern security scanner for MCP prompt injection attacks. | 2-3 days |
| G9 | **Rate Limiting** | Hermes | Per-provider rate limit tracking and backoff. | 2-3 days |
| G10 | **Memory Quality Gate** | Zeph | MemReader quality scoring for stored memories, pruning low-quality entries. | 3-4 days |
| G11 | **Age-Encrypted Secrets Vault** | Zeph | Encrypted secret storage with age encryption, better than ChaCha20 env files. | 2-3 days |
| G12 | **Context Compression** | Hermes | LLM-based context compression beyond auto-compaction. | 3-4 days |

### MEDIUM (Nice-to-Have)

| # | Gap | Source System | Impact | Effort |
|---|---|---|---|---|
| G13 | **Trajectory Replay** | Hermes | Record and replay agent execution trajectories for debugging. | 2-3 days |
| G14 | **PII Filter** | Zeph | Automatic detection and redaction of PII in agent I/O. | 1-2 days |
| G15 | **Exfiltration Detection** | Zeph | Detect when agent tries to send sensitive data externally. | 1-2 days |
| G16 | **Health Registry** | Aizen (observer) | Structured health checks beyond simple monitoring. | 1-2 days |
| G17 | **Model Metadata Smart Routing** | Hermes | Intelligent model routing based on task type, cost, speed. | 2-3 days |

---

## 5. Top 10 Priority Gaps (Ranked by Impact × Feasibility)

| Priority | Gap | Why Critical | Source | Est. Days |
|---|---|---|---|---|
| 1 | **Documentation Cleanup** | 402 brand refs block legitimacy. First impression matters. | Internal | 1-2 |
| 2 | **Self-Learning Skills** | Differentiating feature — skills that improve over time. | Zeph | 5-7 |
| 3 | **Credential Pool** | Essential for production — multi-key rotation prevents outages. | Hermes | 2-3 |
| 4 | **Plugin System** | Enables community contributions without Zig compilation. | Hermes | 4-5 |
| 5 | **TUI Dashboard** | Primary interface for power users. | Hermes/Zeph | 5-7 |
| 6 | **Structured Output Rewriting** | Complements OMNI integration for deeper token savings. | RTK | 3-4 |
| 7 | **Rate Limiting** | Prevents API ban and throttling in production. | Hermes | 2-3 |
| 8 | **MCP Injection Detection** | Security is critical — Zeph's 17-pattern scanner. | Zeph | 2-3 |
| 9 | **DAG Task Orchestration** | Enables complex multi-step agent workflows. | Zeph | 5-7 |
| 10 | **Age-Encrypted Vaults** | Better secret management than env files. | Zeph | 2-3 |

**Total estimated effort: 30-45 engineer-days**

---

## 6. Markdown Audit

### Files Categorized

#### DELETE (Stale / Duplicate / Old Brand)

| File | Reason |
|---|---|
| /aizen-kanban/aizen.md | Entire file references aizen |
| /aizen-orchestrate/docs/docker-compose-aizen-kanban-aizen.md | Old brand names |
| /aizen-orchestrate/docs/aizen-kanban-aizen-orchestrate-aizen.md | Old brand names |
| /aizen-orchestrate/docs/single-aizen-integration.md | Old brand names |
| /aizen-orchestrate/docs/multi-bot-integration.md | Likely references old brands |
| /aizen-orchestrate/reference/todo.md | Stale TODO |
| /aizen-dashboard/chat-ui/docs/*.md | Derivative Aizen docs |

#### UPDATE (Needs rebranding + content refresh)

| File | Issue | Action |
|---|---|---|
| /README.md | References aizen | Rebrand to Aizen |
| /aizen-core/README.md | References Aizen x3 | Rebrand + add Aizen features |
| /aizen-core/CLAUDE.md | References Aizen | Rebrand |
| /docs/research-report.md | 57+ aizen refs | Rebrand to Aizen, update analysis |
| /docs/architecture-design.md | 42+ aizen refs | Rebrand, update design for Aizen |
| /docs/pm-spec.md | 41+ aizen refs | Rebrand, update spec |
| /aizen-dashboard/README.md | aizen-dashboard, aizen-kanban, aizen-orchestrate refs | Rebrand |
| /aizen-kanban/README.md | 12x aizen-kanban refs | Rebrand |
| /aizen-kanban/AGENTS.md | 2x aizen-kanban refs | Rebrand |
| /aizen-kanban/docs/*.md | aizen-kanban refs | Rebrand all |
| /aizen-orchestrate/README.md | aizen-orchestrate refs | Rebrand |
| /aizen-orchestrate/docs/superpowers/*.md | Old content | Rebrand + update |
| All docs/en/ & docs/zh/ | Language-specific pages | Rebrand throughout |

#### KEEP (Good as-is or minor updates)

| File | Notes |
|---|---|
| /aizen-core/docs/integration-analysis.md | Technical content, no brand issues |
| /aizen-core/docs/integration-roadmap.md | Technical content |
| /docs/gap-analysis.md | This file (NEW) |
| /aizen-core/SECURITY.md | Security docs |
| /aizen-core/SIGNAL.md | Signal protocol docs |
| /aizen-core/RELEASING.md | Release process |
| /aizen-core/CONTRIBUTING.md | Contribution guidelines |
| /aizen-core/docs/en/*.md | Need rebrand but content OK |
| /aizen-core/src/workspace_templates/*.md | Template files, update branding |

### Zig Source Brand References (112 total)

33 Zig files still reference aizen/aizen-dashboard/aizen-watch/aizen-kanban/aizen-orchestrate. Key files:
- /src/skills.zig (10 refs)
- /src/config.zig (9 refs)
- /src/config_types.zig (4 refs)
- /dashboard/src/api/instances.zig (15 refs)
- /dashboard/src/core/aizen_web_channel.zig (7 refs — rename entire file!)

These should be batch-replaced using a rebranding script (like `scripts/rebrand.sh` but for Zig source).

---

## 7. Implementation Roadmap

### Phase 1: Cleanup (1-2 days)
- [ ] Run comprehensive rebrand (290 MD refs + 112 Zig refs)
- [ ] Delete 7 stale markdown files
- [ ] Rename aizen_web_channel.zig → aizen_web_channel.zig
- [ ] Update all docs/en/ and docs/zh/ pages
- [ ] Verify `zig build` still passes

### Phase 2: Core Gaps (15-25 days)
- [ ] G1: Self-Learning Skills (Wilson score + Bayesian ranking)
- [ ] G2: Credential Pool (multi-key rotation)
- [ ] G3: Plugin System (runtime-loadable)
- [ ] G4: TUI Dashboard (Bubble Tea or zig-spoon)
- [ ] G6: Structured Output Rewriting (4 strategies from RTK)

### Phase 3: Hardening (10-18 days)
- [ ] G7: DAG Task Orchestration
- [ ] G8: MCP Injection Detection (17-pattern scanner)
- [ ] G9: Rate Limiting (per-provider)
- [ ] G10: Memory Quality Gate (MemReader)
- [ ] G11: Age-Encrypted Vaults
- [ ] G12: Context Compression (LLM-based)

### Phase 4: Polish (5-10 days)
- [ ] G13: Trajectory Replay
- [ ] G14: PII Filter
- [ ] G15: Exfiltration Detection
- [ ] G16: Health Registry
- [ ] G17: Model Metadata Smart Routing

**Total: 30-55 engineer-days**

---

*End of Gap Analysis*
