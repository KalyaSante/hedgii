#!/bin/bash
# 🦔 Hedgii integration tests: real backup → upload (local rclone remote) → restore round trips.
# No root, no secrets: everything lives in a temp dir.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
cleanup() { [[ -n "${HTTP_PID:-}" ]] && kill "$HTTP_PID" 2>/dev/null; [[ -n "${KEEP_TMP:-}" ]] || rm -rf "$TMP"; }
trap cleanup EXIT

for dep in diff gpg jq rclone rsync tar unzip zip flock; do
    command -v "$dep" >/dev/null 2>&1 || { echo "Missing dependency: $dep" >&2; exit 1; }
done

fail=0
ok()   { echo "ok   - $*"; }
ko()   { echo "FAIL - $*"; fail=1; }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else ko "$name"; fi; }

SRC1="$TMP/src1"; SRC2="$TMP/src2"; REMOTE="$TMP/remote"; BACKUPS="$TMP/backups"
mkdir -p "$SRC1/nested" "$SRC1/node_modules/pkg" "$SRC2" "$REMOTE"
echo "first"   > "$SRC1/nested/first.txt"
echo "dep"     > "$SRC1/node_modules/pkg/index.js"
echo "skip"    > "$SRC1/ignored.skipme"
echo "per-src" > "$SRC2/local.only"
echo "second"  > "$SRC2/second.txt"
echo "hedgii-test-passphrase" > "$TMP/passphrase"
chmod 600 "$TMP/passphrase"
printf '[test]\ntype = local\n' > "$TMP/rclone.conf"

export HEDGII_CONFIG_FILE="$TMP/config.json"
export HEDGII_LOG_FILE="$TMP/hedgii.log"
export HEDGII_LOCK_FILE="$TMP/hedgii.lock"

# write_config <format> <remote> [extra jq filter]
write_config() {
    jq -n --arg s1 "$SRC1" --arg s2 "$SRC2" --arg tmp "$TMP" --arg fmt "$1" --arg remote "$2" '{
        backup_sources: [
            {source: $s1, destination: "first",  description: "First source"},
            {source: $s2, destination: "second", description: "Second source", exclude: ["local.only"]}
        ],
        custom_commands: [
            {command: "echo dump-data; echo noisy-warning >&2", description: "Fake dump",
             output_file: "databases/dump.sql", timeout: 10, continue_on_error: false}
        ],
        settings: {
            staging_dir: ($tmp + "/staging"), backup_dir: ($tmp + "/backups"),
            encrypt_passphrase_file: ($tmp + "/passphrase"), compression_format: $fmt,
            sync_method: "rclone", rclone_remote: $remote, rclone_config: ($tmp + "/rclone.conf")
        },
        exclusions: ["*.skipme", "node_modules"]
    } | '"${3:-.}" > "$HEDGII_CONFIG_FILE"
}

hedgii() { bash "$ROOT/hedgii.sh" "$@" >>"$TMP/run.out" 2>&1; }
newest_archive() { find "$BACKUPS" -maxdepth 1 -name "hedgii_backup_*.$1.gpg" -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-; }

roundtrip() { # <format> <extension> [jq filter] [label]
    local fmt="${4:-$1}" ext="$2" out="$TMP/restore-${4:-$1}" archive
    write_config "$1" "test:$REMOTE/" "${3:-.}"
    check "$fmt: curl exits 0" hedgii curl
    archive=$(newest_archive "$ext")
    check "$fmt: archive created" test -n "$archive"
    check "$fmt: archive uploaded" test -f "$REMOTE/$(basename "$archive")"
    check "$fmt: archive is not world-readable" test "$(stat -c %a "$archive")" = 600
    check "$fmt: decrypt.sh restores without a Hedgii config" \
        env HEDGII_CONFIG_FILE=/nonexistent bash "$ROOT/scripts/decrypt.sh" --passphrase-file "$TMP/passphrase" "$archive" "$out"
    check "$fmt: first source restored" diff -r "$SRC1/nested" "$out/first/nested"
    check "$fmt: global exclusions applied" test ! -e "$out/first/ignored.skipme" -a ! -e "$out/first/node_modules"
    check "$fmt: per-source exclusion applied" test ! -e "$out/second/local.only" -a -f "$out/second/second.txt"
    check "$fmt: dump contains stdout only" test "$(cat "$out/databases/dump.sql")" = "dump-data"
    check "$fmt: staging removed after run" test -z "$(find "$TMP" -maxdepth 1 -name 'staging.*' -print -quit)"
    check "$fmt: verify passes" hedgii verify --local --archive "$(basename "$archive")"
}

roundtrip zip zip
roundtrip tar.gz tar.gz
# staging_mode "direct": sources are archived in place, never copied to staging
ln -s nested/first.txt "$SRC1/link-to-first"
roundtrip zip zip '.settings.staging_mode = "direct"' direct-zip
roundtrip tar.gz tar.gz '.settings.staging_mode = "direct"' direct-tar
check "direct-tar: internal symlink kept as a symlink" test -L "$TMP/restore-direct-tar/first/link-to-first"
check "direct mode: report counts the source files" grep -q '^Total files: 4$' "$TMP/restore-direct-tar/hedgii_backup_report.txt"
rm -f "$SRC1/link-to-first"

# Not enough free space: stops before copying anything, with sizes in the message
write_config tar.gz "test:$REMOTE/" '.settings.min_free_space_ratio = 1e18'
before=$(find "$BACKUPS" -name 'hedgii_backup_*.gpg' | wc -l)
runs_before=$(grep -c 'Executing: Fake dump' "$HEDGII_LOG_FILE")
rc=0; hedgii curl || rc=$?
check "full disk exits 7 (got $rc)" test "$rc" -eq 7
check "full disk message has needed and available sizes" grep -q "Not enough free space.*need .*available" "$TMP/run.out"
check "full disk: no copy and no archive" test "$(find "$BACKUPS" -name 'hedgii_backup_*.gpg' | wc -l)" -eq "$before" -a -z "$(find "$TMP" -maxdepth 1 -name 'staging.*' -print -quit)"
check "full disk: stopped before the custom commands" test "$(grep -c 'Executing: Fake dump' "$HEDGII_LOG_FILE")" -eq "$runs_before"

# Upload failure: exit code 4, archive kept locally and flagged as not uploaded
write_config tar.gz "missing:$REMOTE/"
rc=0; hedgii curl || rc=$?
check "upload failure exits 4 (got $rc)" test "$rc" -eq 4
check "failed archive has no .uploaded marker" test ! -f "$(newest_archive tar.gz).uploaded"

# Collection failure: blocking custom command fails → exit 2
write_config tar.gz "test:$REMOTE/" '.custom_commands[0].command = "exit 3"'
rc=0; hedgii curl || rc=$?
check "blocking custom command failure exits 2 (got $rc)" test "$rc" -eq 2

# Empty .sql dump fails by default (require_output)
write_config tar.gz "test:$REMOTE/" '.custom_commands[0].command = "true"'
rc=0; hedgii curl || rc=$?
check "empty .sql dump is rejected (got $rc)" test "$rc" -eq 2

# Concurrent run: lock held → exit 5
write_config tar.gz "test:$REMOTE/"
rc=0
( exec 9>"$HEDGII_LOCK_FILE"; flock 9; rc=0; bash "$ROOT/hedgii.sh" curl >>"$TMP/run.out" 2>&1 || rc=$?; exit "$rc" ) || rc=$?
check "concurrent run exits 5 (got $rc)" test "$rc" -eq 5

# Retention: keep the 2 newest uploaded archives, never touch the non-uploaded one
write_config tar.gz "test:$REMOTE/" '.retention = {local_keep_last: 2, local_keep_days: 0}'
for _ in 1 2 3; do sleep 1; hedgii curl || ko "retention run"; done
uploaded=$(find "$BACKUPS" -name 'hedgii_backup_*.gpg.uploaded' | wc -l)
total=$(find "$BACKUPS" -name 'hedgii_backup_*.gpg' | wc -l)
check "retention keeps 2 uploaded archives (got $uploaded)" test "$uploaded" -eq 2
check "retention keeps the non-uploaded archive (got $total total)" test "$total" -eq 3

# verify: healthy archive passes, truncated archive fails
check "verify --local passes on a healthy archive" hedgii verify --local
latest=$(newest_archive tar.gz)
head -c 200 "$latest" > "$BACKUPS/hedgii_backup_99999999_999999.tar.gz.gpg"
rc=0; hedgii verify --local --archive hedgii_backup_99999999_999999.tar.gz.gpg || rc=$?
check "verify fails on a truncated archive (got $rc)" test "$rc" -ne 0
rm -f "$BACKUPS/hedgii_backup_99999999_999999.tar.gz.gpg"
check "verify --remote passes" hedgii verify --remote
check "verify removes its temp dir" test -z "$(find "$TMP" -maxdepth 1 -name 'staging.verify.*' -print -quit)"

# Markers: an unmarked archive that exists on the remote gets marked on the next run
latest=$(newest_archive tar.gz)
rm -f "$latest.uploaded"
hedgii curl || ko "reconcile run"
check "unmarked archive found on remote is re-marked" test -f "$latest.uploaded"

# Notifications: fake webhook + ping endpoint on localhost
PORT=$((20000 + RANDOM % 20000))
python3 - "$PORT" "$TMP/http.log" <<'PY' &
import http.server, sys
log = open(sys.argv[2], "a", buffering=1)
class H(http.server.BaseHTTPRequestHandler):
    def _ok(self):
        n = int(self.headers.get("Content-Length") or 0)
        log.write(self.command + " " + self.path + " " + self.rfile.read(n).decode(errors="replace").replace("\n", " ") + "\n")
        self.send_response(204); self.end_headers()
    do_GET = do_POST = do_HEAD = _ok
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
HTTP_PID=$!
for _ in $(seq 50); do curl -s -o /dev/null "http://127.0.0.1:$PORT/ready" && break; sleep 0.1; done
notif='.notifications = {on: ["failure", "warning", "success"], discord_webhook: "http://127.0.0.1:'"$PORT"'/discord", ping_url: "http://127.0.0.1:'"$PORT"'/ping"}'
write_config tar.gz "test:$REMOTE/" "$notif"
: > "$TMP/http.log"
: > "$HEDGII_LOG_FILE"   # one log per run in production; the warning level reads it
hedgii curl || ko "notified backup run"
check "ping /start sent" grep -q "/ping/start" "$TMP/http.log"
check "success ping sent" grep -q "/ping " "$TMP/http.log"
check "run with a leftover unsent archive is reported as a warning" grep -q "POST /discord .*backup warning.*Archive never uploaded" "$TMP/http.log"
write_config tar.gz "missing:$REMOTE/" "$notif"
: > "$TMP/http.log"
hedgii curl || true
check "failure ping sent" grep -q "/ping/fail" "$TMP/http.log"
check "failure message has exit code 4" grep -q "POST /discord .*backup failure.*Exit code: 4" "$TMP/http.log"
write_config tar.gz "test:$REMOTE/" "$notif"
check "test-notify succeeds" hedgii test-notify

if [[ $fail -ne 0 ]]; then
    echo "---- hedgii output ----"; tail -n 80 "$TMP/run.out"
fi
exit $fail
