# Aizen Docs Snapshot — Done vs Todo

Last updated: 2026-05-04
Purpose: one-file quick status snapshot derived from current docs + repo state
Primary source for detailed near-term truth: `roadmap-current.md`

## Done / confirmed

### Documentation structure
- `README.md` now acts as the docs index
- `roadmap-current.md` is established as the current roadmap-level source of truth
- `task-list.md` is explicitly marked historical
- `gap-analysis.md` is explicitly marked strategic/partially stale
- `live-test-findings-2026-05-04.md` captures current Ranus-compatible validation findings

### Provider and validation work
- Provider probe classification improved
- QA regression matrix created
- PM breakdown for custom OpenAI-compatible onboarding created
- Reduced provider smoke workflow exists:
  - `aizen-core/scripts/provider-smoke.sh`
  - `aizen-core/scripts/provider-smoke-musl.sh`
- Build profile guidance exists in `aizen-core/docs/build-profiles.md`
- Ranus-compatible CLI smoke validation succeeded and is documented

### Strategic features already present in repo/history
- Structured Output Rewriting
- DAG Task Orchestration
- Age-Encrypted Secrets Vault
- LLM-based Context Compression

## Not done / still outstanding

### Current operational blockers
- Persist `base_url` in saved-provider CRUD and validation flows
- Preserve upstream status specificity in dashboard/API validation responses
- Surface sanitized provider diagnostics clearly in frontend/operator UX
- Fix raw `408` parity between core and dashboard classifiers
- Make provider-only validation a durable CI-quality lane
- Align sqlite memory config/status/runtime with compiled capabilities

### Delivery / integration status
- Provider-smoke auto-target work exists in commit `16b17cd`
- That commit is pushed to branch `push/provider-smoke-auto-target`
- It is not yet merged/cherry-picked into `main`

### Strategic capabilities still genuinely missing or incomplete
- Self-Learning Skills
- Credential Pool / Multi-Key Rotation
- Plugin System
- TUI Dashboard
- MCP Injection Detection
- Per-provider Rate Limiting
- Memory Quality Gate
- Trajectory Replay
- PII Filter
- Exfiltration Detection
- Health Registry
- Model Metadata Smart Routing

## How to read this file
- Use this file for a fast status snapshot only.
- Use `roadmap-current.md` for current prioritization.
- Use `gap-analysis.md` for long-term strategic framing.
- Use live kanban for actual execution state.
