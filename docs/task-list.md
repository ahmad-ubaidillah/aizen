# Aizen Agent — Implementation Task List

> From Gap Analysis v1.0 | Total: 30-55 engineer-days

## Epic 1: Cleanup & Rebrand (1-2 days, Priority: P0)

| Task ID | Task | Est. | Status |
|---|---|---|---|
| E1-T1 | Run comprehensive rebrand script on 290 MD refs + 112 Zig refs | 2h | ☐ |
| E1-T2 | Delete 7 stale markdown files (aizen.md, docker-compose-*.md, etc.) | 30m | ☐ |
| E1-T3 | Rename aizen_web_channel.zig → aizen_web_channel.zig + update imports | 1h | ☐ |
| E1-T4 | Update docs/en/ and docs/zh/ pages — rebrand all null* references | 2h | ☐ |
| E1-T5 | Update /README.md, /aizen-core/README.md, /aizen-core/CLAUDE.md | 30m | ☐ |
| E1-T6 | Run `zig build` to verify no broken imports after rebrand | 15m | ☐ |

## Epic 2: Core Features (15-25 days, Priority: P1)

| Task ID | Task | Est. | Status |
|---|---|---|---|
| E2-T1 | Self-Learning Skills — implement Wilson score + Bayesian ranking for skill quality tracking | 5d | ☐ |
| E2-T2 | Self-Learning Skills — implement skill evolution from failure clusters (auto-patch) | 2d | ☐ |
| E2-T3 | Credential Pool — multi-API-key rotation with per-provider tracking | 2d | ☐ |
| E2-T4 | Credential Pool — automatic failover when rate-limited | 1d | ☐ |
| E2-T5 | Plugin System — define plugin interface (Zig vtable) for runtime-loadable extensions | 2d | ☐ |
| E2-T6 | Plugin System — implement plugin discovery, load, and lifecycle management | 2d | ☐ |
| E2-T7 | Plugin System — create 3 reference plugins (analytics, notification, custom-tool) | 1d | ☐ |
| E2-T8 | TUI Dashboard — implement Bubble Tea-style TUI with chat, metrics, and control panels | 5d | ☐ |
| E2-T9 | TUI Dashboard — add provider selector, skill browser, and cron viewer panels | 2d | ☐ |
| E2-T10 | Structured Output Rewriting — implement 4 RTK strategies (filter, group, truncate, dedup) | 3d | ☐ |
| E2-T11 | Structured Output Rewriting — integrate with OMNI bridge for combined token savings | 1d | ☐ |

## Epic 3: Hardening (10-18 days, Priority: P2)

| Task ID | Task | Est. | Status |
|---|---|---|---|
| E3-T1 | DAG Task Orchestration — define DAG schema (YAML/TOML) for multi-step workflows | 2d | ☐ |
| E3-T2 | DAG Task Orchestration — implement DAG executor with parallel/sequential steps | 3d | ☐ |
| E3-T3 | MCP Injection Detection — implement 17-pattern scanner from Zeph's security model | 2d | ☐ |
| E3-T4 | MCP Injection Detection — add VIGIL gate to MCP pipeline | 1d | ☐ |
| E3-T5 | Rate Limiting — per-provider rate limit tracker with exponential backoff | 2d | ☐ |
| E3-T6 | Memory Quality Gate — implement MemReader quality scoring for stored memories | 3d | ☐ |
| E3-T7 | Memory Quality Gate — auto-prune low-quality entries with configurable threshold | 1d | ☐ |
| E3-T8 | Age-Encrypted Secrets Vault — integrate age encryption for secret storage | 2d | ☐ |
| E3-T9 | Context Compression — LLM-based context compression beyond auto-compaction | 3d | ☐ |
| E3-T10 | Context Compression — implement manual compression feedback loop | 1d | ☐ |

## Epic 4: Polish (5-10 days, Priority: P3)

| Task ID | Task | Est. | Status |
|---|---|---|---|
| E4-T1 | Trajectory Replay — record and replay agent execution for debugging | 2d | ☐ |
| E4-T2 | PII Filter — automatic detection and redaction of PII in agent I/O | 1d | ☐ |
| E4-T3 | Exfiltration Detection — detect when agent sends sensitive data externally | 1d | ☐ |
| E4-T4 | Health Registry — structured health checks for all services | 1d | ☐ |
| E4-T5 | Model Metadata Smart Routing — route tasks to optimal model by type/cost/speed | 2d | ☐ |

## Summary

| Epic | Tasks | Est. Days | Priority |
|---|---|---|---|
| E1: Cleanup | 6 | 1-2 | P0 |
| E2: Core | 11 | 15-25 | P1 |
| E3: Hardening | 10 | 10-18 | P2 |
| E4: Polish | 5 | 5-10 | P3 |
| **Total** | **32** | **30-55** | — |

---

## Dependencies

```
E1 (all) → E2-T1, E2-T5, E2-T8 (must complete rebrand first)
E2-T1 → E2-T2 (self-learning foundation before evolution)
E2-T3 → E2-T4 (credential pool before failover)
E2-T5 → E2-T6 → E2-T7 (plugin interface before lifecycle before examples)
E2-T8 → E2-T9 (TUI foundation before panels)
E2-T10 → E2-T11 (strategies before OMNI integration)
E3-T1 → E3-T2 (DAG schema before executor)
E3-T3 → E3-T4 (patterns before VIGIL gate)
E3-T6 → E3-T7 (quality scoring before auto-prune)
E3-T8 (independent — age encryption)
E3-T9 → E3-T10 (compression before feedback)
E4 (all independent — can be done in any order)
```
