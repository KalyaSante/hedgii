#!/bin/bash
# Smoke tests for the hedgii.sh command dispatcher
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HEDGII_LOG_FILE="$TMP/hedgii.log"
export HEDGII_LOCK_FILE="$TMP/hedgii.lock"
fail=0
check() { # name expected_rc cmd...
    local name="$1" want="$2"; shift 2
    "$@" >"$TMP/out" 2>&1; local rc=$?
    if [[ $rc -eq $want ]]; then echo "ok   - $name"; else echo "FAIL - $name (rc=$rc, want $want)"; cat "$TMP/out"; fail=1; fi
}
echo '{"custom_commands":[],"backup_sources":[]}' > "$TMP/good.json"
echo '{invalid' > "$TMP/bad.json"
run() { HEDGII_CONFIG_FILE="$1" bash "$ROOT/hedgii.sh" "${@:2}"; }
check "validate-config valid" 0 run "$TMP/good.json" validate-config
check "validate-config invalid" 1 run "$TMP/bad.json" validate-config
check "sync-status" 0 run "$TMP/good.json" sync-status
check "test-commands" 0 run "$TMP/good.json" test-commands
check "peek" 0 run "$TMP/good.json" peek
check "guard" 0 run "$TMP/good.json" guard
check "help" 0 run "$TMP/good.json" help
check "version matches the version file" 0 bash -c '[[ "$(HEDGII_CONFIG_FILE="$1" bash "$2/hedgii.sh" version)" == "Hedgii $(cat "$2/version")" ]]' _ "$TMP/good.json" "$ROOT"
exit $fail
