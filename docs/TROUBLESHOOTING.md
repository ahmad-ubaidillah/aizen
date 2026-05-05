# Aizen Troubleshooting Guide

Last updated: 2026-05-05
Status: CURRENT

## Build Issues

### `unhandled relocation type R_X86_64_PC64` from `crt1.o:.sframe`

**Symptom:**
```
error: fatal linker error: unhandled relocation type R_X86_64_PC64
```
Path typically points at `crt1.o:.sframe` or other glibc startup objects.

**Cause:**
Zig 0.16.0 does not support the `.sframe` section in newer glibc/GCC startup objects (observed on Arch Linux with GCC 16.1.1+).

**Fix:**
Use musl target instead of native glibc:
```bash
zig build -Dtarget=x86_64-linux-musl
```

For provider validation specifically:
```bash
zig build install -Dtarget=x86_64-linux-musl -Dchannels=none
./scripts/provider-smoke.sh
```

**See also:** `aizen-core/docs/build-profiles.md`

---

### `-Dstatic=true` does not fix `.sframe` issue

**Symptom:**
Static build fails with even more `.sframe` errors from `libc.a` and `libm.a`.

**Cause:**
Static linking pulls in even more glibc objects with `.sframe` sections.

**Fix:**
Same as above — use musl target. Static glibc is not supported on affected hosts with Zig 0.16.0.

---

## Provider Issues

### `AuthenticationFailed` during live smoke test

**Symptom:**
```
AuthenticationFailed
```
when running provider smoke with `AIZEN_RUN_LIVE_SMOKE=1`.

**Cause:**
Runtime credential/auth state is not available in the current shell session.

**Fix:**
1. Verify `AIZEN_API_KEY` is set:
   ```bash
   echo $AIZEN_API_KEY
   ```
2. Or pass it inline:
   ```bash
   AIZEN_API_KEY="sk-..." ./zig-out/bin/aizen agent -m "test" --provider "custom:https://api.ranus.tech/v1" --model "ranus-reason"
   ```
3. If using saved providers, verify the provider is configured in `~/.aizen/config.json`.

**Note:** `AuthenticationFailed` during live smoke is a runtime credential issue, not a build regression.

---

### Provider probe returns `auth_check_failed` for all failures

**Symptom:**
All provider failures collapse to generic `auth_check_failed` regardless of actual cause.

**Status:**
PARTIALLY FIXED in recent commits. Distinct states now surfaced:
- `invalid_api_key` (401)
- `forbidden` (403)
- `context_limit_exceeded` / `output_limit_exceeded`
- `payload_too_large`
- `rate_limit` (429)
- `provider_unavailable`

If you still see generic `auth_check_failed`, update to the latest `main` branch.

---

### Custom provider `base_url` not persisted

**Symptom:**
Saved provider loses `base_url` after restart or validation round-trip.

**Status:**
KNOWN ISSUE — tracked in kanban task `t_31e40182`.

**Workaround:**
Use inline provider specification instead of saved providers:
```bash
--provider "custom:https://api.ranus.tech/v1"
```

---

## Dashboard/API Issues

### Validation responses lose upstream status specificity

**Symptom:**
Dashboard shows HTTP 422 or generic error even when upstream/provider reason is known.

**Status:**
KNOWN ISSUE — tracked in kanban task `t_4f024aad`.

**Workaround:**
Check core CLI validation for detailed diagnostics:
```bash
./zig-out/bin/aizen config validate --json
```

---

### Raw `408` handling differs between core and dashboard

**Symptom:**
Core classifies `408` as one thing, dashboard classifies it as another.

**Status:**
KNOWN ISSUE — tracked in kanban task `t_a4717fea`.

---

## Runtime Issues

### `memory backend configured but unavailable`

**Symptom:**
Config specifies `memory.backend = sqlite` but binary was compiled without sqlite engine support.

**Fix:**
1. Check compiled capabilities:
   ```bash
   ./zig-out/bin/aizen capabilities --json
   ```
2. Look for `sqlite` in `memory_engines` — if `enabled_in_build: false`, rebuild with sqlite:
   ```bash
   zig build -Dengines=base,sqlite
   ```
3. Or change config to use an available backend:
   ```json
   { "memory": { "backend": "none" } }
   ```

---

### YOLO mode refused on non-local host

**Symptom:**
```
Refusing to start gateway service with autonomy.level=yolo on non-local host '0.0.0.0'.
```

**Cause:**
YOLO mode is restricted to loopback addresses only for security.

**Fix:**
1. Use loopback address:
   ```json
   { "gateway": { "host": "127.0.0.1" } }
   ```
2. Or set `AIZEN_ALLOW_YOLO=1` (not recommended for production):
   ```bash
   AIZEN_ALLOW_YOLO=1 ./zig-out/bin/aizen gateway
   ```

---

## Getting Help

1. Check `aizen-core/docs/build-profiles.md` for build guidance
2. Check `docs/roadmap-current.md` for known issues and in-flight work
3. Check `docs/live-test-findings-2026-05-04.md` for verified behavior
4. Run `./zig-out/bin/aizen status` for runtime diagnostics
5. Run `./zig-out/bin/aizen capabilities --json` for compiled feature matrix
