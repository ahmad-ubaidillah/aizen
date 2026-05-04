# Aizen Build Profiles

Last updated: 2026-05-04
Status: current operational reference

## Purpose

This document defines the supported build/test profiles for Aizen during the current provider-stabilization phase.

It exists to prevent confusion between:
- configured features in config.json
- features actually compiled into the current binary
- validation lanes intended for provider work vs full product validation

## Profile 1 — Full default local build

Use when:
- normal local development
- status/config/runtime parity checks
- broad feature validation

Command examples:
- `zig build`
- `zig build test`

Expected characteristics:
- default channel set enabled
- default engine set includes sqlite-backed memory support
- suitable for normal CLI usage and local smoke tests

## Profile 2 — Provider-focused validation build

Use when:
- validating OpenAI-compatible/custom endpoints such as Ranus
- debugging provider integration without unrelated channel/web failures
- reproducing onboarding issues for compatible providers

Command examples:
- `zig build test -Dtarget=x86_64-linux-musl -Dchannels=none -Dengines=base,sqlite -freference-trace`
- `zig build install -Dtarget=x86_64-linux-musl -Dchannels=none`
- `./scripts/provider-smoke.sh`
- `AIZEN_RUN_LIVE_SMOKE=1 ./scripts/provider-smoke.sh`

Expected characteristics:
- unrelated channels disabled
- sqlite memory still available
- lower dependency surface
- should be the preferred validation lane for custom provider onboarding work

Operational notes:
- `scripts/provider-smoke.sh` is the canonical reduced-profile validation lane
- default mode verifies build/install + `status` + `capabilities --json` + `config validate --json`
- live provider prompting is opt-in via `AIZEN_RUN_LIVE_SMOKE=1`
- if live smoke fails with `AuthenticationFailed`, treat it as runtime credential/auth state, not as proof the reduced build is broken
- on Arch Linux hosts with newer glibc/GCC startup objects that include `.sframe`, Zig 0.16.0 native glibc linking may fail before app code links at all
- the observed native failure signature is `unhandled relocation type R_X86_64_PC64` from `crt1.o:.sframe` (and, in static builds, many more glibc/libm `.sframe` objects)
- treat that failure as a host toolchain incompatibility, not as evidence that the Aizen source tree is broken
- for provider/debug/stabilization work on such hosts, prefer the musl profile in this document instead of spending time re-debugging the native glibc path

## Native glibc `.sframe` incompatibility note

Observed on this host profile:
- Zig `0.16.0`
- Arch Linux native glibc toolchain
- GCC `16.1.1`
- glibc startup objects (`crt1.o`, `Scrt1.o`) containing `.sframe`

Failure signature:
- `error: fatal linker error: unhandled relocation type R_X86_64_PC64`
- note path typically points at `crt1.o:.sframe`
- `-Dstatic=true` does not fix it; it usually expands the same failure into many objects from `libc.a` and `libm.a`

Operator guidance:
- do not treat this as an Aizen regression first
- do not block provider validation on native glibc success on affected hosts
- use `-Dtarget=x86_64-linux-musl` as the operational build/test lane
- if native glibc output is required, solve it via toolchain/sysroot changes or a newer Zig release rather than source-level patching in the repo

## Profile 3 — Minimal dependency-trimmed build

Use when:
- testing aggressive feature gating
- verifying optional modules do not leak assumptions into reduced builds

Command examples:
- `zig build -Dchannels=none -Dengines=none`
- `zig build test -Dchannels=none -Dengines=none`

Expected characteristics:
- no optional channels
- no durable memory backend
- useful for compile-gating checks, not representative of normal local usage

## Degraded mode expectations

A config can be syntactically valid while still being degraded relative to the compiled binary.

Current example:
- `memory.backend = sqlite`
- binary compiled without sqlite engine support

Expected operator behavior:
- `aizen config validate` should warn that configured backend is disabled in this build
- `aizen status` should show both configured memory backend and build availability
- runtime warnings should match the same diagnosis

## Recommended workflow by task type

### For normal product work
- use full default local build first
- then run targeted smoke tests

### For provider onboarding/debugging
- use provider-focused validation build first
- then run CLI smoke tests against the target endpoint
- only after that expand to broader integration coverage

### For optional-feature hardening
- use minimal dependency-trimmed build to catch hidden assumptions
- add targeted tests for gated modules

## Warning policy

Provider-focused validation should minimize unrelated warning noise.

Warnings that should not dominate provider validation lanes:
- unrelated external-service connector failures
- optional channel fixture noise
- missing integrations not part of the selected build profile

Warnings that should remain visible:
- compiled/configured capability mismatch
- provider auth/endpoint failures
- payload/response contract mismatches
- build-gating regressions

## Summary

Do not treat all successful builds as equivalent.

For current Aizen stabilization work, the most important distinction is:
- full build for broad confidence
- provider-focused build for compatible endpoint work
- minimal build for feature-gating hardening
