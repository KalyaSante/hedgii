#!/bin/bash

# 🦔 Hedgii Test Script
# Local integration tests for backup and restore

set -euo pipefail

PINK='\033[1;35m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

test_log() {
    local level="$1"
    shift
    case "$level" in
        "INFO")   echo -e "${GREEN}🦔 [TEST]${NC} $*" ;;
        "ERROR")  echo -e "${RED}💥 [TEST]${NC} $*" ;;
        "KAWAII") echo -e "${PINK}✨ [TEST]${NC} $*" ;;
    esac
}

for dependency in diff gpg jq rclone rsync tar unzip zip; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        test_log "ERROR" "Missing dependency: $dependency"
        exit 1
    fi
done

REPOSITORY_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

SOURCE_ONE="$TEMP_DIR/source-one"
SOURCE_TWO="$TEMP_DIR/source-two"
mkdir -p "$SOURCE_ONE/nested" "$SOURCE_TWO" "$TEMP_DIR/remote"
printf 'first source data\n' > "$SOURCE_ONE/nested/first.txt"
printf 'second source data\n' > "$SOURCE_TWO/second.txt"
printf 'excluded data\n' > "$SOURCE_ONE/ignored.skipme"
printf 'hedgii-test-passphrase\n' > "$TEMP_DIR/passphrase"
chmod 600 "$TEMP_DIR/passphrase"

export RCLONE_CONFIG="$TEMP_DIR/rclone.conf"
cat > "$RCLONE_CONFIG" <<EOF
[test]
type = local
EOF

export HEDGII_CONFIG_FILE="$TEMP_DIR/config.json"
export HEDGII_LOG_FILE="$TEMP_DIR/hedgii.log"

write_config() {
    local format="$1"
    local remote="$2"
    jq -n \
        --arg source_one "$SOURCE_ONE" \
        --arg source_two "$SOURCE_TWO" \
        --arg staging "$TEMP_DIR/staging" \
        --arg backup "$TEMP_DIR/backups" \
        --arg passphrase "$TEMP_DIR/passphrase" \
        --arg format "$format" \
        --arg remote "$remote" \
        '{
          backup_sources: [
            {source: $source_one, destination: "first", description: "First source"},
            {source: $source_two, destination: "second", description: "Second source"}
          ],
          custom_commands: [
            {command: "printf custom-data", description: "Test custom command", output_file: "custom/output.txt", working_dir: "/tmp", timeout: 10, continue_on_error: false}
          ],
          settings: {
            staging_dir: $staging,
            backup_dir: $backup,
            encrypt_passphrase_file: $passphrase,
            compression_format: $format,
            sync_method: "rclone",
            rclone_remote: $remote,
            local_keep_last: 2
          },
          exclusions: ["*.skipme"]
        }' > "$HEDGII_CONFIG_FILE"
}

assert_restored() {
    local output_dir="$1"
    diff -r --exclude='*.skipme' "$SOURCE_ONE" "$output_dir/first"
    diff -r "$SOURCE_TWO" "$output_dir/second"
    [[ ! -e "$output_dir/first/ignored.skipme" ]]
    [[ "$(cat "$output_dir/custom/output.txt")" == "custom-data" ]]
}

run_backup_and_restore() {
    local format="$1"
    local extension="$2"
    local name="$3"
    local output_dir="$TEMP_DIR/restore-$name"
    write_config "$format" "test:$TEMP_DIR/remote/"
    test_log "INFO" "Testing $format backup and restore..."
    (cd "$REPOSITORY_ROOT" && bash ./hedgii.sh curl)

    local archive
    archive=$(find "$TEMP_DIR/backups" -maxdepth 1 -type f -name "hedgii_backup_*.$extension.gpg" | head -n 1)
    [[ -n "$archive" ]]
    bash "$REPOSITORY_ROOT/scripts/decrypt.sh" "$archive" "$output_dir"
    assert_restored "$output_dir"
}

test_log "KAWAII" "🦔 Running local backup integration tests..."
run_backup_and_restore "zip" "zip" "zip"
run_backup_and_restore "tar.gz" "tar.gz" "tar"

test_log "INFO" "Checking failed uploads return code 4..."
write_config "tar.gz" "missing:$TEMP_DIR/remote/"
set +e
(cd "$REPOSITORY_ROOT" && bash ./hedgii.sh curl)
upload_status=$?
set -e
[[ "$upload_status" -eq 4 ]]

test_log "INFO" "Checking local backup retention..."
write_config "tar.gz" "test:$TEMP_DIR/remote/"
for run in 1 2 3 4 5; do
    test_log "INFO" "Retention run $run/5"
    sleep 1
    (cd "$REPOSITORY_ROOT" && bash ./hedgii.sh curl)
done
archive_count=$(find "$TEMP_DIR/backups" -maxdepth 1 -type f -name 'hedgii_backup_*.gpg' | wc -l)
[[ "$archive_count" -eq 2 ]]

test_log "KAWAII" "🎉 All local integration tests passed!"
