# Aizen Live Test Findings — 2026-05-04

Last updated: 2026-05-05
Status: CURRENT

## Purpose

This document captures verified findings from live build, install, provider integration, and runtime testing on the current host. It serves as operational evidence for decisions in `roadmap-current.md` and `done-vs-todo.md`.

---

## Host Profile

| Property | Value |
|----------|-------|
| OS | Arch Linux (CachyOS) |
| Kernel | 6.14.x |
| Zig | 0.16.0 |
| GCC | 16.1.1 |
| glibc | startup objects contain `.sframe` section |

---

## Finding 1: Native glibc `.sframe` Linker Incompatibility

**Status:** CONFIRMED

**Observation:**
Native glibc builds fail with:
```
error: fatal linker error: unhandled relocation type R_X86_64_PC64
```
Path typically points at `crt1.o:.sframe`.

**Impact:**
- Blocks `zig build` without explicit target on this host
- `-Dstatic=true` does NOT fix it; expands failure into many `libc.a` / `libm.a` objects

**Resolution:**
Use `-Dtarget=x86_64-linux-musl` as the operational build lane.

**Evidence:**
- Direct reproduction on 2026-05-04
- Documented in `aizen-core/docs/build-profiles.md`

---

## Finding 2: Provider-Focused Reduced Validation Works

**Status:** CONFIRMED

**Command:**
```bash
cd aizen-core
zig build install -Dtarget=x86_64-linux-musl -Dchannels=none
./zig-out/bin/aizen status
./zig-out/bin/aizen capabilities --json
./zig-out/bin/aizen config validate --json
```

**Result:** All pass. Binary size ~678KB. Startup <2ms.

**Impact:**
- Custom OpenAI-compatible provider onboarding can be validated without unrelated channel/web build noise
- This is now the recommended lane for provider work

---

## Finding 3: Ranus-Compatible Provider Live Smoke

**Status:** CONFIRMED — 2026-05-05

**Provider:** `custom:https://api.ranus.tech/v1`
**Model:** `ranus-reason`
**Credentials:** removed from archived note.

**Command:**
```bash
AIZEN_API_KEY="[REMOVED]" \
  ./zig-out/bin/aizen agent -m "Balas persis: smoke-ok" \
  --provider "custom:https://api.ranus.tech/v1" \
  --model "ranus-reason"
```

**Result:**
```
smoke-ok
info(memory): memory plan resolved: backend=none retrieval=keyword ...
debug(rollout): rollout decide: mode=off decision=keyword_only ...
```

**Interpretation:**
- Provider endpoint reachable
- Authentication successful
- Model responds correctly to simple prompt
- Memory backend correctly falls back to `none` in reduced build

---

## Finding 4: Provider Probe Classification Improvements

**Status:** CONFIRMED

**Kanban task:** `t_5c1e5d13`

**Observation:**
Provider probe no longer collapses all failures into generic `auth_check_failed`. Distinct states now surfaced:
- `invalid_api_key` (401)
- `forbidden` (403)
- `context_limit_exceeded` / `output_limit_exceeded`
- `payload_too_large`
- `rate_limit` (429)
- `provider_unavailable`

**Impact:**
Operators can now distinguish auth failure vs payload issue vs provider outage.

---

## Finding 5: QA Regression Matrix Created

**Status:** CONFIRMED

**Kanban task:** `t_1ae6089f`

**Evidence file:**
`/home/ahmad/.hermes/kanban/workspaces/t_1ae6089f/provider_regression_matrix.txt`

**Contents:**
Matrix of provider × model × status code × expected behavior.

---

## Finding 6: Provider-Smoke Auto-Target Script Verified

**Status:** CONFIRMED

**Script:** `aizen-core/scripts/provider-smoke.sh`

**Behavior:**
- Auto-detects risky native glibc toolchain (Zig 0.16.0 + `.sframe` objects)
- Defaults to `x86_64-linux-musl` on affected hosts
- Supports `AIZEN_BUILD_PROFILE=auto|native|musl` override
- Supports `AIZEN_TARGET` explicit override
- Live smoke is opt-in via `AIZEN_RUN_LIVE_SMOKE=1`

**Commit:** `16b17cd` (merged into `main` as `2ec1dc0`)

---

## Finding 7: `base_url` Persistence Gap in Saved Provider Flows

**Status:** CONFIRMED — STILL OUTSTANDING

**Observation:**
Saved provider CRUD and validation flows do not consistently persist `base_url`. Custom endpoints like Ranus work in wizard/config flows but may be lost in saved-provider round-trips.

**Kanban task:** `t_31e40182` (in-flight)

---

## Finding 8: Dashboard/API Validation Contract Loses Status Specificity

**Status:** CONFIRMED — STILL OUTSTANDING

**Observation:**
Upstream/provider-specific failure reasons sometimes collapse to HTTP 422 or generic fallback in dashboard/API responses.

**Kanban task:** `t_4f024aad` (in-flight)

---

## Open Questions

1. Does the musl binary run correctly on other distros (Debian, Fedora, Alpine)?
2. Is the `.sframe` issue fixed in Zig 0.16.1 or 0.17.0?
3. Can we make provider-only validation a fully automated CI lane?

---

## Changelog

- **2026-05-05**: Added Ranus live smoke confirmation (Finding 3).
- **2026-05-04**: Initial findings from build/runtime testing.
