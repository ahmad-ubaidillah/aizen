# Aizen Changelog

All notable changes to the Aizen project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Added
- Provider-focused reduced validation lane (`scripts/provider-smoke.sh`, `scripts/provider-smoke-musl.sh`)
- Build profile guidance for native glibc vs musl targets (`aizen-core/docs/build-profiles.md`)
- Auto-detection of risky native glibc toolchains (`.sframe` / `R_X86_64_PC64` linker issue)
- CI workflow for aizen-dashboard PR checks (`.github/workflows/aizen-dashboard-ci.yml`)

### Security
- Hardened SecretsVault: PBKDF2-HMAC-SHA256 key derivation (10000 rounds + random per-vault salt)
- Hardened SecretsVault: random recipient_id instead of leaking master key in recipient_pubkey
- Teams webhook: require webhook_secret for production use (returns 403 if not configured)
- Agent Card: gate `/.well-known/agent.json` behind `security.agent_card.expose` config (default: false)
- YOLO mode: restrict to loopback addresses only, remove env var bypass
- Landlock sandbox: documented as reserved future capability, clarify Firejail and Bubblewrap as production sandboxes

### Fixed
- Preserve `base_url` in saved-provider CRUD and validation flows
- Improve provider diagnostics and capability visibility
- Replace WeChat `app_id` placeholder with generic placeholder

### Documentation
- Restructured docs folder with clear authority hierarchy (`README.md` index, `roadmap-current.md` as execution truth)
- Added `done-vs-todo.md` for quick status snapshot
- Added `gap-analysis.md` with strategic vs operational framing
- Added `live-test-findings-2026-05-04.md` for verified build/test/provider findings
- Added `governance.md` for docs maintenance rules
- Added `archive-strategy.md` for document lifecycle management
- Added this `CHANGELOG.md`

---

## [2026.4.17] — 2026-05-01

### Added
- **Self-Learning Skills quality tracker** — Wilson score + Bayesian ranking for skill quality
- **MCP Injection Detection** — 17-pattern scanner for prompt injection attacks
- **Credential Pool and Rate Limiting** — multi-API-key rotation with per-provider tracking and exponential backoff
- **Flat monorepo** — all services consolidated into single repository
- **Structured Output Rewriting** — 4 RTK strategies (filter, group, truncate, dedup)
- **DAG Task Orchestration** — multi-step workflow execution with parallel/sequential steps
- **Age-Encrypted Secrets Vault** — x25519 keypair + age-encrypted JSON secret storage
- **LLM-based Context Compression** — 5 compression strategies beyond auto-compaction
- **Plugin System** — vtable-based runtime loading for extensions
- **TUI Dashboard core module** — Bubble Tea-style terminal UI

### Changed
- **Full rebrand** from NullClaw ecosystem to Aizen
- OMNI bridge integration with tool pruning and prompt caching
- Python skill bridge for Hermes-compatible skill execution

---

## [0.1.0] — 2026-04-28

### Added
- Initial fork from NullClaw ecosystem
- Core agent runtime (Zig)
- 19+ channel adapters (Telegram, Discord, Slack, WhatsApp, Matrix, IRC, etc.)
- 50+ LLM provider modules
- 42 built-in tools
- 10 memory backends (SQLite, Markdown, ClickHouse, PostgreSQL, Redis, LanceDB, etc.)
- MCP client (stdio + HTTP transport)
- Security sandbox (ChaCha20-Poly1305, Landlock, Firejail, Bubblewrap)
- Cron scheduling
- Web dashboard (aizen-dashboard)
- Kanban board (aizen-kanban)
- Monitoring (aizen-watch)
- Orchestration (aizen-orchestrate)

---

## Legend

- **Added** — new features
- **Changed** — changes to existing functionality
- **Deprecated** — soon-to-be removed features
- **Removed** — removed features
- **Fixed** — bug fixes
- **Security** — security improvements
