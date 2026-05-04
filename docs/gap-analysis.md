# Aizen Agent — Comprehensive Gap Analysis

Status: Partially stale strategic reference
Last reviewed: 2026-05-04
Current execution source of truth:
- live kanban work
- `docs/roadmap-current.md`

This document remains useful for long-term strategic comparison and capability planning, but it should not be used as the primary source for near-term execution priorities.

Decision framing:
- Strategic capability gaps answer: what capabilities Aizen still needs to build for long-term competitiveness and platform maturity.
- Operational bottlenecks answer: what must be fixed now to ship credibly, reduce confusion, and unblock current work.
- Do not rank these in one flat list without considering time horizon.

> Generated: 2026-05-01 | Comparing: Aizen vs Hermes vs OMNI vs Zeph vs RTK

## 1. Executive Summary

Aizen is a Zig-based autonomous AI agent forked from Aizen, rebranded and enhanced with OMNI integration, tool pruning, prompt caching, and a Python skill bridge. With 319K+ lines of Zig code across 6 services, Aizen has a solid foundation. However, several critical gaps remain compared to the 5 reference systems.

**Key Finding (historical, now partially outdated)**: This document originally identified heavy stale-branding debt and several strategic feature gaps. Since that first pass, parts of the repo have moved forward materially: structured output rewriting, DAG task orchestration, age-encrypted vaults, and LLM-based context compression now exist in the codebase/history, while the immediate bottlenecks have shifted toward provider compatibility, custom OpenAI-compatible onboarding, build/profile isolation, and dashboard/API validation behavior. Branding/doc debt still exists in parts of the wider ecosystem, but the main short-term risk is now operational clarity rather than lack of foundational ideas.

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

## 4. Strategic capability gaps

Status note:
- This section is strategic, not an exact live execution board.
- Some items below were originally marked as missing but now exist at least partially in the repo/history.
- For current near-term truth, prefer `docs/roadmap-current.md`.

### CRITICAL / STILL MISSING (Must-Have)

| # | Gap | Source System | Impact | Effort |
|---|---|---|---|---|
| G1 | **Self-Learning Skills** | Zeph | Skills that evolve via Wilson score + Bayesian ranking from usage data. Aizen has SkillForge (discovery) but not self-learning. | 5-7 days |
| G2 | **Credential Pool / Multi-Key Rotation** | Hermes | Rotate multiple API keys automatically, avoiding rate limits. | 2-3 days |
| G3 | **Plugin System** | Hermes | Runtime-loadable plugins for extending agent capabilities without recompilation. | 4-5 days |
| G4 | **TUI (Terminal UI)** | Hermes/Zeph | Interactive terminal dashboard for monitoring, chat, and control. | 5-7 days |
| G5 | **Documentation Cleanup / Authority Clarity** | Internal | Shipping/readiness bottleneck: stale branding, confusing docs authority, and trust issues. Track as operational P0 work, not as a long-term strategic capability gap. | 1-2 days |

### HIGH / PARTIALLY DONE OR NEEDS HARDENING

| # | Gap | Source System | Current status | Impact | Effort |
|---|---|---|---|---|---|
| G6 | **Structured Output Rewriting** | RTK | Implemented in repo history, but operational adoption/integration status still needs validation. | Improve output filtering quality and token handling. | 1-3 days hardening/integration |
| G7 | **DAG Task Orchestration** | Zeph | Implemented in repo history, but not the current operational bottleneck. | Parallel/sequential step execution and reusable plans. | 1-3 days validation/docs |
| G8 | **MCP Injection Detection** | Zeph | Still missing as a first-class hardened feature. | Prompt-injection defense for MCP/tool surfaces. | 2-3 days |
| G9 | **Rate Limiting** | Hermes | Still missing or incomplete as explicit per-provider control. | Backoff/limit awareness for provider stability. | 2-3 days |
| G10 | **Memory Quality Gate** | Zeph | Still missing. | Scoring/pruning low-quality memory entries. | 3-4 days |
| G11 | **Age-Encrypted Secrets Vault** | Zeph | Implemented in repo history; current adoption and UX still need validation. | Better secret handling posture. | 1-2 days validation/docs |
| G12 | **Context Compression** | Hermes | Implemented in repo history; may still need integration and operator-facing validation. | Better long-context handling. | 1-3 days validation/docs |

### MEDIUM (Nice-to-Have)

| # | Gap | Source System | Impact | Effort |
|---|---|---|---|---|
| G13 | **Trajectory Replay** | Hermes | Record and replay agent execution trajectories for debugging. | 2-3 days |
| G14 | **PII Filter** | Zeph | Automatic detection and redaction of PII in agent I/O. | 1-2 days |
| G15 | **Exfiltration Detection** | Zeph | Detect when agent tries to send sensitive data externally. | 1-2 days |
| G16 | **Health Registry** | Aizen (observer) | Structured health checks beyond simple monitoring. | 1-2 days |
| G17 | **Model Metadata Smart Routing** | Hermes | Intelligent model routing based on task type, cost, speed. | 2-3 days |

---

## 5. Priority matrix by horizon

### P0 — Operational now
- Persist `base_url` correctly in saved-provider CRUD and validation flows
- Preserve upstream status specificity in dashboard/API validation responses
- Surface sanitized provider diagnostics clearly for operators
- Fix raw `408` parity between core and dashboard classifiers
- Stabilize provider-only build/test validation lane
- Align sqlite memory config/status/runtime with compiled capabilities
- Continue docs authority cleanup (README, roadmap-current, historical labels)

### P1 — Strategic next
- Credential Pool / Multi-Key Rotation
- Plugin System
- TUI Dashboard
- Rate Limiting
- MCP Injection Detection
- Build/profile matrix hardening and explicit optional-web documentation

### P2 — Strategic later
- Self-Learning Skills
- Memory Quality Gate
- Trajectory Replay / PII Filter / Exfiltration Detection / Health Registry / Model Metadata Smart Routing
- Validation and productization pass for already-implemented strategic features:
  - Structured Output Rewriting
  - DAG Task Orchestration
  - Age-Encrypted Vaults
  - Context Compression

Why this framing is better:
- separates current shipping blockers from strategic platform investments
- avoids calling implemented-but-not-yet-operationalized features “missing” in a misleading way
- matches live findings from current provider and build-profile work more closely

**Total estimated effort remains split between immediate operational stabilization and broader strategic feature maturation.**

---

## 6. Operational bottlenecks and readiness risks

Status note:
- The file/action lists below came from the first major rebrand pass.
- They are preserved as historical reference, not as a guaranteed up-to-date execution list.
- Some listed files have since been updated, while other real blockers emerged later in live provider/build testing.

### Historical rebrand/debt findings (reference only)

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
| /docs/research-report.md | Historical stale references | Rebrand/update as needed |
| /docs/architecture-design.md | Historical stale references | Rebrand/update as needed |
| /docs/pm-spec.md | Historical stale references | Rebrand/update as needed |
| /aizen-dashboard/README.md | cross-service stale naming | Rebrand/update as needed |
| /aizen-kanban/README.md | cross-service stale naming | Rebrand/update as needed |
| /aizen-kanban/AGENTS.md | cross-service stale naming | Rebrand/update as needed |
| /aizen-kanban/docs/*.md | cross-service stale naming | Rebrand all as needed |
| /aizen-orchestrate/README.md | cross-service stale naming | Rebrand/update as needed |
| /aizen-orchestrate/docs/superpowers/*.md | Old content | Rebrand + update |
| All docs/en/ & docs/zh/ | Language-specific pages | Rebrand throughout |

#### KEEP (Good as-is or minor updates)

| File | Notes |
|---|---|
| /aizen-core/docs/integration-analysis.md | Technical content, no major issue noted in original pass |
| /aizen-core/docs/integration-roadmap.md | Technical content |
| /docs/gap-analysis.md | Strategic reference |
| /aizen-core/SECURITY.md | Security docs |
| /aizen-core/SIGNAL.md | Signal protocol docs |
| /aizen-core/RELEASING.md | Release process |
| /aizen-core/CONTRIBUTING.md | Contribution guidelines |
| /aizen-core/docs/en/*.md | Content may still need selective refresh |
| /aizen-core/src/workspace_templates/*.md | Template files; branding may still need review |

### Current live operational bottlenecks (higher priority than the historical list)
- Saved-provider `base_url` persistence is still inconsistent
- Dashboard/API validation contract still loses useful upstream specificity in some paths
- Sanitized provider diagnostics need better operator-facing surfacing
- Raw `408` handling still differs between core and dashboard edge cases
- Provider-only validation is improved but not yet a fully durable CI-quality lane
- sqlite memory capability/status/runtime mismatch remains a real operator-risk item
- native glibc `.sframe` linker issue means musl remains the safer provider-validation path on some hosts

---

## 7. Implementation Roadmap

Status note:
- The checklist below is now a strategic/historical roadmap, not a live execution tracker.
- For current near-term priorities, use `docs/roadmap-current.md` and live kanban.

### Phase 1: Operational Stabilization (current)
- [ ] Persist `base_url` in saved provider CRUD and validation flows
- [ ] Preserve upstream status specificity in dashboard/API validation responses
- [ ] Surface sanitized provider diagnostics to dashboard/frontend consumers
- [ ] Fix raw `408` parity between core and dashboard classifiers
- [ ] Turn provider smoke validation into a durable CI-quality lane
- [ ] Align sqlite memory config/status/runtime with compiled capabilities
- [ ] Finish docs sync after the current provider stabilization wave

### Phase 2: Strategic capability work still missing
- [ ] G1: Self-Learning Skills (Wilson score + Bayesian ranking)
- [ ] G2: Credential Pool (multi-key rotation)
- [ ] G3: Plugin System (runtime-loadable)
- [ ] G4: TUI Dashboard
- [ ] G8: MCP Injection Detection (17-pattern scanner)
- [ ] G9: Rate Limiting (per-provider)
- [ ] G10: Memory Quality Gate (MemReader)

### Phase 3: Validate and operationalize already-implemented strategic features
- [ ] G6: Structured Output Rewriting — verify integration, docs, and real use paths
- [ ] G7: DAG Task Orchestration — verify scope, ergonomics, and practical adoption
- [ ] G11: Age-Encrypted Vaults — validate UX and docs
- [ ] G12: Context Compression — validate effectiveness and operator-facing behavior
- [ ] Build/profile matrix hardening and optional-web documentation

### Phase 4: Polish / later hardening
- [ ] G13: Trajectory Replay
- [ ] G14: PII Filter
- [ ] G15: Exfiltration Detection
- [ ] G16: Health Registry
- [ ] G17: Model Metadata Smart Routing

**This roadmap should now be read as strategic direction only, not as exact live status.**

---

*End of Gap Analysis*
