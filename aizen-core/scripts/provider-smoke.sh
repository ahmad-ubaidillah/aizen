#!/usr/bin/env bash
set -euo pipefail

# Provider-focused validation lane for local dev / CI.
# Purpose: verify custom/OpenAI-compatible provider wiring without depending on
# optional channel builds or native glibc linker behavior.
#
# Defaults are tuned for the Ranus-compatible setup used in live validation, but
# can be overridden with env vars.
#
# Env overrides:
#   AIZEN_RUN_LIVE_SMOKE=1
#   AIZEN_BUILD_PROFILE=auto         # auto|native|musl
#   AIZEN_TARGET=x86_64-linux-musl   # explicit override wins over auto-detect
#   AIZEN_CHANNELS=none
#   AIZEN_PROVIDER=custom:https://api.ranus.tech/v1
#   AIZEN_MODEL=ranus-reason
#   AIZEN_SMOKE_PROMPT='Balas persis: smoke-ok'
#   AIZEN_EXPECT=smoke-ok

AIZEN_RUN_LIVE_SMOKE="${AIZEN_RUN_LIVE_SMOKE:-0}"
AIZEN_BUILD_PROFILE="${AIZEN_BUILD_PROFILE:-auto}"
AIZEN_TARGET="${AIZEN_TARGET:-}"
AIZEN_CHANNELS="${AIZEN_CHANNELS:-none}"
AIZEN_PROVIDER="${AIZEN_PROVIDER:-custom:https://api.ranus.tech/v1}"
AIZEN_MODEL="${AIZEN_MODEL:-ranus-reason}"
AIZEN_SMOKE_PROMPT="${AIZEN_SMOKE_PROMPT:-Balas persis: smoke-ok}"
AIZEN_EXPECT="${AIZEN_EXPECT:-smoke-ok}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

section() {
  printf '\n==> %s\n' "$1"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

read_os_release_field() {
  local key="$1"
  if [[ -r /etc/os-release ]]; then
    awk -F= -v k="$key" '$1 == k { gsub(/^"|"$/, "", $2); print $2; exit }' /etc/os-release
  fi
}

has_sframe_startup_objects() {
  local crt
  for crt in /usr/lib/crt1.o /usr/lib64/crt1.o /usr/lib/Scrt1.o /usr/lib64/Scrt1.o; do
    if [[ -f "$crt" ]] && have_cmd readelf; then
      if readelf -SW "$crt" 2>/dev/null | grep -q 'GNU_SFRAME\|\.sframe'; then
        return 0
      fi
    fi
  done
  return 1
}

resolve_auto_target() {
  local uname_s zig_ver distro_id distro_like machine
  uname_s="$(uname -s 2>/dev/null || printf unknown)"
  machine="$(uname -m 2>/dev/null || printf x86_64)"
  zig_ver="$(zig version 2>/dev/null || printf unknown)"
  distro_id="$(read_os_release_field ID)"
  distro_like="$(read_os_release_field ID_LIKE)"

  case "$AIZEN_BUILD_PROFILE" in
    musl)
      printf '%s-linux-musl\n' "$machine"
      return 0
      ;;
    native)
      printf '%s\n' "$machine"
      return 0
      ;;
  esac

  if [[ -n "$AIZEN_TARGET" ]]; then
    printf '%s\n' "$AIZEN_TARGET"
    return 0
  fi

  if [[ "$uname_s" != "Linux" ]]; then
    printf '%s\n' "$machine"
    return 0
  fi

  if [[ "$zig_ver" == "0.16.0" ]] && has_sframe_startup_objects; then
    printf '%s-linux-musl\n' "$machine"
    return 0
  fi

  if [[ "$distro_id" == "arch" || "$distro_like" == *arch* ]]; then
    printf '%s-linux-musl\n' "$machine"
    return 0
  fi

  printf '%s\n' "$machine"
}

TARGET_REASON="explicit AIZEN_TARGET override"
if [[ -z "$AIZEN_TARGET" ]]; then
  AIZEN_TARGET="$(resolve_auto_target)"
  case "$AIZEN_BUILD_PROFILE" in
    musl)
      TARGET_REASON="forced musl via AIZEN_BUILD_PROFILE=musl"
      ;;
    native)
      TARGET_REASON="forced native via AIZEN_BUILD_PROFILE=native"
      ;;
    *)
      if [[ "$AIZEN_TARGET" == *-linux-musl ]]; then
        TARGET_REASON="auto-detected risky native glibc toolchain; preferring musl"
      else
        TARGET_REASON="auto-detected native host path"
      fi
      ;;
  esac
fi

section "Build target selection"
printf 'target=%s\n' "$AIZEN_TARGET"
printf 'reason=%s\n' "$TARGET_REASON"
if [[ -r /etc/os-release ]]; then
  printf 'os=%s\n' "$(read_os_release_field PRETTY_NAME)"
fi
printf 'zig=%s\n' "$(zig version 2>/dev/null || printf unavailable)"

section "Build/install reduced provider profile"
zig build install -Dtarget="$AIZEN_TARGET" -Dchannels="$AIZEN_CHANNELS"

section "Status"
./zig-out/bin/aizen status

section "Capabilities JSON"
./zig-out/bin/aizen capabilities --json

section "Config validate JSON"
./zig-out/bin/aizen config validate --json

if [[ "$AIZEN_RUN_LIVE_SMOKE" != "1" ]]; then
  section "Live provider smoke skipped"
  printf 'Set AIZEN_RUN_LIVE_SMOKE=1 to execute a real provider prompt.\n'
  exit 0
fi

section "Provider smoke prompt"
SMOKE_OUTPUT="$(./zig-out/bin/aizen agent -m "$AIZEN_SMOKE_PROMPT" --provider "$AIZEN_PROVIDER" --model "$AIZEN_MODEL" 2>&1)"
printf '%s\n' "$SMOKE_OUTPUT"

if [[ "$SMOKE_OUTPUT" != *"$AIZEN_EXPECT"* ]]; then
  printf '\nERROR: live provider smoke did not contain expected token: %s\n' "$AIZEN_EXPECT" >&2
  if [[ "$SMOKE_OUTPUT" == *"AuthenticationFailed"* ]]; then
    printf 'HINT: provider auth is not available in the current runtime environment/config.\n' >&2
  fi
  exit 1
fi

section "Provider smoke passed"
printf 'Validated provider=%s model=%s target=%s channels=%s\n' \
  "$AIZEN_PROVIDER" "$AIZEN_MODEL" "$AIZEN_TARGET" "$AIZEN_CHANNELS"
