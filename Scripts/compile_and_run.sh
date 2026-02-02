#!/usr/bin/env bash
# Reset SkillsBar: kill running instances, build, package, relaunch, verify.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${ROOT_DIR}/SkillsBar.app"
APP_PROCESS_PATTERN="SkillsBar.app/Contents/MacOS/SkillsBar"
DEBUG_PROCESS_PATTERN="${ROOT_DIR}/.build/debug/SkillsBar"
RELEASE_PROCESS_PATTERN="${ROOT_DIR}/.build/release/SkillsBar"
LOCK_KEY="$(printf '%s' "${ROOT_DIR}" | shasum -a 256 | cut -c1-8)"
LOCK_DIR="${TMPDIR:-/tmp}/skillsbar-compile-and-run-${LOCK_KEY}"
LOCK_PID_FILE="${LOCK_DIR}/pid"
WAIT_FOR_LOCK=0
RUN_TESTS=0
DEBUG_LLDB=0
RELEASE_ARCHES=""
SIGNING_MODE="${SKILLSBAR_SIGNING:-}"

log()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

has_signing_identity() {
  local identity="${1:-}"
  if [[ -z "${identity}" ]]; then
    return 1
  fi
  security find-identity -p codesigning -v 2>/dev/null | grep -F "${identity}" >/dev/null 2>&1
}

resolve_signing_mode() {
  if [[ -n "${SIGNING_MODE}" ]]; then
    return
  fi

  if [[ -n "${APP_IDENTITY:-}" ]]; then
    if has_signing_identity "${APP_IDENTITY}"; then
      SIGNING_MODE="identity"
      return
    fi
    log "WARN: APP_IDENTITY not found in Keychain; falling back to adhoc signing."
    SIGNING_MODE="adhoc"
    return
  fi

  SIGNING_MODE="adhoc"
}

run_step() {
  local label="$1"; shift
  log "==> ${label}"
  if ! "$@"; then
    fail "${label} failed"
  fi
}

cleanup() {
  if [[ -d "${LOCK_DIR}" ]]; then
    rm -rf "${LOCK_DIR}"
  fi
}

acquire_lock() {
  while true; do
    if mkdir "${LOCK_DIR}" 2>/dev/null; then
      echo "$$" > "${LOCK_PID_FILE}"
      return 0
    fi

    local existing_pid=""
    if [[ -f "${LOCK_PID_FILE}" ]]; then
      existing_pid="$(cat "${LOCK_PID_FILE}" 2>/dev/null || true)"
    fi

    if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
      if [[ "${WAIT_FOR_LOCK}" == "1" ]]; then
        log "==> Another agent is compiling (pid ${existing_pid}); waiting..."
        while kill -0 "${existing_pid}" 2>/dev/null; do
          sleep 1
        done
        continue
      fi
      log "==> Another agent is compiling (pid ${existing_pid}); re-run with --wait."
      exit 0
    fi

    rm -rf "${LOCK_DIR}"
  done
}

trap cleanup EXIT INT TERM

kill_all_skillsbar() {
  is_running() {
    pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 \
      || pgrep -f "${DEBUG_PROCESS_PATTERN}" >/dev/null 2>&1 \
      || pgrep -f "${RELEASE_PROCESS_PATTERN}" >/dev/null 2>&1 \
      || pgrep -x "SkillsBar" >/dev/null 2>&1
  }

  # Phase 1: request termination (give the app time to exit cleanly).
  for _ in {1..25}; do
    pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -f "${DEBUG_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -f "${RELEASE_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -x "SkillsBar" 2>/dev/null || true
    if ! is_running; then
      return 0
    fi
    sleep 0.2
  done

  # Phase 2: force kill any stragglers (avoids `open -n` creating multiple instances).
  pkill -9 -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
  pkill -9 -f "${DEBUG_PROCESS_PATTERN}" 2>/dev/null || true
  pkill -9 -f "${RELEASE_PROCESS_PATTERN}" 2>/dev/null || true
  pkill -9 -x "SkillsBar" 2>/dev/null || true

  for _ in {1..25}; do
    if ! is_running; then
      return 0
    fi
    sleep 0.2
  done

  fail "Failed to kill all SkillsBar instances."
}

# 1) Ensure a single runner instance.
for arg in "$@"; do
  case "${arg}" in
    --wait|-w) WAIT_FOR_LOCK=1 ;;
    --test|-t) RUN_TESTS=1 ;;
    --debug-lldb) DEBUG_LLDB=1 ;;
    --release-universal) RELEASE_ARCHES="arm64 x86_64" ;;
    --release-arches=*) RELEASE_ARCHES="${arg#*=}" ;;
    --help|-h)
      log "Usage: $(basename "$0") [--wait] [--test] [--debug-lldb] [--release-universal] [--release-arches=\"arm64 x86_64\"]"
      exit 0
      ;;
    *)
      ;;
  esac
done

resolve_signing_mode
if [[ "${SIGNING_MODE}" == "adhoc" ]]; then
  log "==> Signing: adhoc (set APP_IDENTITY to avoid keychain prompts)"
else
  log "==> Signing: ${APP_IDENTITY:-Developer ID Application}"
fi

acquire_lock

# 2) Kill all running SkillsBar instances (debug, release, bundled).
log "==> Killing existing SkillsBar instances"
kill_all_skillsbar

# 2.5) Delete keychain entries to avoid permission prompts with adhoc signing
# (adhoc signature changes on every build, making old keychain entries inaccessible)
if [[ "${SIGNING_MODE:-adhoc}" == "adhoc" ]]; then
  log "==> Clearing keychain entries (adhoc signing)"
  security delete-generic-password -s "com.skillsbar.app" 2>/dev/null || true
  # Clear all keychain items for the app to avoid multiple prompts
  while security delete-generic-password -s "com.skillsbar.app" 2>/dev/null; do
    :
  done
fi

# 3) Package (release build happens inside package_app.sh).
if [[ "${RUN_TESTS}" == "1" ]]; then
  run_step "swift test" swift test -q
fi
if [[ "${DEBUG_LLDB}" == "1" && -n "${RELEASE_ARCHES}" ]]; then
  fail "--release-arches is only supported for release packaging"
fi
HOST_ARCH="$(uname -m)"
ARCHES_VALUE="${HOST_ARCH}"
if [[ -n "${RELEASE_ARCHES}" ]]; then
  ARCHES_VALUE="${RELEASE_ARCHES}"
fi
if [[ "${DEBUG_LLDB}" == "1" ]]; then
  run_step "package app" env SKILLSBAR_ALLOW_LLDB=1 ARCHES="${ARCHES_VALUE}" "${ROOT_DIR}/Scripts/package_app.sh" debug
else
  if [[ -n "${SIGNING_MODE}" ]]; then
    run_step "package app" env SKILLSBAR_SIGNING="${SIGNING_MODE}" ARCHES="${ARCHES_VALUE}" "${ROOT_DIR}/Scripts/package_app.sh"
  else
    run_step "package app" env ARCHES="${ARCHES_VALUE}" "${ROOT_DIR}/Scripts/package_app.sh"
  fi
fi

# 4) Launch the packaged app.
log "==> launch app"
if ! open "${APP_BUNDLE}"; then
  log "WARN: launch app returned non-zero; falling back to direct binary launch."
  "${APP_BUNDLE}/Contents/MacOS/SkillsBar" >/dev/null 2>&1 &
  disown
fi

# 5) Verify the app stays up for at least a moment (launch can be >1s on some systems).
for _ in {1..10}; do
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
    log "OK: SkillsBar is running."
    exit 0
  fi
  sleep 0.4
done
fail "App exited immediately. Check crash logs in Console.app (User Reports)."
