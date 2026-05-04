# Aizen Current Roadmap and Status

Last updated: 2026-05-04
Status owner: active working document synced with live build/test findings and kanban

## 1. Executive Summary

Aizen has two planning layers:
1. Strategic vision documents created during the initial ecosystem analysis
2. Live execution findings from actual build, install, provider integration, and kanban work

As of 2026-05-04, the live execution layer is the higher-priority source for short-term work.

Main conclusion:
- Long-term roadmap is still valid: self-learning, plugin system, TUI, credential pool, structured rewriting, DAG orchestration, security hardening.
- Short-term operational priorities have shifted: provider compatibility, custom OpenAI-compatible onboarding, base_url persistence, provider diagnostics, dashboard/API error contract, and provider-only validation isolation are now the real bottlenecks.

## 2. Current State of Docs

### Current / useful now
- README.md
  Master index for this docs folder.
- roadmap-current.md
  Current source of truth for execution status and near-term roadmap.
- architecture-design.md
  Good target-state architecture reference.
- research-report.md
  Good strategic comparison/reference doc.
- design/credential-pool.md
  Focused feature design doc.

### Partially stale but still useful
- pm-spec.md
  Useful as original MVP breakdown, but not current execution truth.
- gap-analysis.md
  Useful as strategic gap inventory, but missing recent operational findings.

### Stale as active tracker
- task-list.md
  Historical task list from older gap analysis. Not synced to live kanban.

## 3. Confirmed Live Findings

### Done / confirmed improvements
1. Provider probe classification improved
   Confirmed via kanban task t_5c1e5d13.
   Auth, forbidden, context/output-limit, payload-too-large, rate limit, and provider-unavailable states are no longer collapsed into a generic auth_check_failed path.

2. QA regression matrix created
   Confirmed via kanban task t_1ae6089f.
   Evidence file:
   /home/ahmad/.hermes/kanban/workspaces/t_1ae6089f/provider_regression_matrix.txt

3. PM breakdown for custom OpenAI-compatible provider onboarding created
   Confirmed via kanban task t_e4bcb73e.

4. Provider-focused reduced validation lane created and verified
   Confirmed in repo work on 2026-05-04.
   Outcome:
   - canonical helper script now exists as `aizen-core/scripts/provider-smoke.sh`
   - compatibility wrapper kept at `aizen-core/scripts/provider-smoke-musl.sh`
   - script supports `AIZEN_BUILD_PROFILE=auto|native|musl`
   - explicit `AIZEN_TARGET` override still works

5. Native glibc `.sframe` linker incompatibility documented
   Confirmed via direct reproduction on current Arch/CachyOS host.
   Outcome:
   - `aizen-core/docs/build-profiles.md` documents the `R_X86_64_PC64` / `.sframe` failure signature
   - provider validation guidance now recommends musl on risky native glibc hosts

6. Provider smoke automation safely isolated for delivery
   Current delivery state:
   - commit `16b17cd` contains the provider-smoke auto-target work
   - pushed safely to remote branch `push/provider-smoke-auto-target`
   - not yet merged/cherry-picked into `origin/main`

### Confirmed problems still relevant
1. Saved provider flow does not consistently persist base_url
   Impact: custom compatible endpoints such as Ranus are only partially supported outside wizard flows.

2. Dashboard/API validation contract loses useful status specificity
   Problem: failures often collapse to HTTP 422 or generic fallback semantics even when upstream/provider reason is known.

3. Sanitized provider diagnostics still need better surfacing
   Impact: operators cannot clearly distinguish auth failure vs payload/context issue vs provider outage.

4. Provider-only validation is blocked by unrelated baseline issues
   Confirmed blocker examples:
   - crt1.o .sframe linker relocation issue
   - non-provider WebChannel/channel-manager test breakage
   Impact: provider-focused work is harder to validate cleanly.

5. Core/dashboard parity is not fully aligned for edge cases
   Known example:
   - raw 408 handling differs between core and dashboard fallback classifiers

## 4. Current Priority Roadmap

### Phase A — Operational Stabilization (current top priority)
P0
- Persist base_url in saved provider CRUD and validation flows
- Isolate provider-only build/test path
- Surface sanitized provider error detail through dashboard/API

P1
- Preserve upstream status specificity in dashboard/API validation responses
- Improve frontend UX for provider diagnostics and custom endpoint onboarding
- Fix raw 408 rate-limit parity between core and dashboard classifiers
- Harden ReleaseSmall/build matrix and document explicit optional web path

### Phase B — Product Reliability and Execution Safety
- Turn provider regression matrix into a repeatable quality gate
- Reduce coupling between provider validation and unrelated web/channel modules
- Clarify API contract for validation failures and operator-facing diagnostics
- Finish doc sync across repo after operational priorities stabilize

### Phase C — Strategic Capability Expansion
Taken from the earlier strategic documents and still valid:
- Self-learning skills
- Credential pool / multi-key rotation
- Plugin system
- TUI dashboard
- Structured output rewriting
- DAG task orchestration
- MCP injection detection
- Per-provider rate limiting
- Memory quality gate
- Encrypted secrets vault
- Advanced context compression

## 5. Live Kanban Status Snapshot

### Previously created and completed/blocked
- t_5c1e5d13
  Done — provider probe classification improvements
- t_1ae6089f
  Done — QA regression matrix
- t_e4bcb73e
  Done — PM breakdown for custom provider onboarding
- t_7a023a6e
  Blocked — provider-focused validation blocked by unrelated baseline issues

### In-flight follow-up tasks
- t_31e40182
  backend — persist base_url in saved provider CRUD and validation flows
- t_295031d0
  backend — unblock provider validation by isolating provider-only test/build path
- t_4f024aad
  backend — preserve upstream status specificity in dashboard/API validation responses
- t_a6331138
  frontend — frontend UX for provider diagnostics and custom endpoint onboarding
- t_a4717fea
  backend — fix raw 408/rate-limit parity between core and dashboard classifiers

### Earlier in-flight tasks still relevant
- t_c4a9e9a8
  backend — surface sanitized provider error detail to dashboard/API consumers
- t_2aa6215a
  backend — harden ReleaseSmall/build matrix and document optional web channel path

## 6. What Is Already Documented vs Not Yet Fully Captured

### Already documented somewhere
- Strategic comparison against Hermes / Zeph / RTK
- Target architecture for multi-service Aizen ecosystem
- Large long-term feature backlog
- Initial MVP/fork/rebrand execution plan
- Credential pool design notes
- Reduced provider smoke workflow (`scripts/provider-smoke.sh` + build profile guidance)
- Ranus-compatible live CLI validation findings
- `.sframe` / native glibc linker issue and musl fallback guidance

### Not yet fully complete in product/repo
- Ranus-compatible/custom compatible provider onboarding gaps in saved-provider CRUD flows
- base_url persistence gap in saved provider flows
- preserving upstream status specificity end-to-end in dashboard/API responses
- sanitized provider diagnostics surfacing for operators in frontend UX
- raw 408 classification parity between core and dashboard
- merging delivered smoke-lane automation from branch `push/provider-smoke-auto-target` into `main`
- provider-only validation isolation as a durable CI-quality lane rather than a partially manual workflow
- sqlite memory capability/status/runtime contract alignment
- full doc sync across older strategic docs after current operational stabilization

## 7. Recommended Documentation Model

Use a hybrid structure:
- One master index file: README.md
- One current roadmap file: roadmap-current.md
- A few specialized reference docs only where needed:
  - architecture-design.md
  - research-report.md
  - pm-spec.md
  - gap-analysis.md
  - design/*.md

Do NOT keep multiple overlapping backlog docs with equal authority.

Recommended authority order:
1. Live kanban work
2. roadmap-current.md
3. architecture/design docs
4. older planning docs (pm-spec.md, gap-analysis.md, task-list.md)

## 8. Recommendation on “one big file vs split by phase”

Best approach:
- Do not use one giant file for everything.
- Do not scatter many overlapping backlog files either.

Recommended structure:
- README.md = index and status map
- roadmap-current.md = one current execution roadmap across phases
- architecture-design.md = target system design
- research-report.md = comparison and inspiration
- pm-spec.md = detailed original implementation spec
- gap-analysis.md = strategic gap inventory
- design/*.md = isolated deep dives per feature

Why this is better:
- One giant file becomes unreadable and mixes strategy with execution.
- Too many separate backlog docs become confusing and diverge.
- One master index + one current roadmap + specialized references is the clean middle ground.

## 9. Next Recommended Actions

1. Keep task-list.md as historical reference only; stop using it as active tracker.
2. Keep gap-analysis.md for long-term strategic planning, not immediate execution.
3. Use roadmap-current.md for all near-term prioritization decisions.
4. Continue executing live kanban tasks and update only roadmap-current.md when priorities change materially.
5. After the current provider wave is stabilized, do a second pass to either archive or compress older docs.
