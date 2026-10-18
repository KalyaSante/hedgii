#!/bin/bash

# 🦔 Hedgii Decrypt - Uncurl your protected data
# Usage: ./decrypt.sh [--passphrase-file FILE] <encrypted_backup_file> [output_directory]

set -o pipefail

CONFIG_FILE="/etc/hedgii/hedgii_config.json"
PASSPHRASE_FILE=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --passphrase-file) PASSPHRASE_FILE="$2"; shift 2 || { echo "Missing value for --passphrase-file" >&2; exit 1; } ;;
        --passphrase-file=*) PASSPHRASE_FILE="${1#*=}"; shift ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

ENCRYPTED_FILE="${POSITIONAL[0]}"
OUTPUT_DIR="${POSITIONAL[1]:-/tmp/hedgii_restore}"

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
PINK='\033[1;35m'
NC='\033[0m'

hedgii_log() {
    case "$1" in
        "INFO")  echo -e "${GREEN}🦔 [INFO]${NC} $2" ;;
        "ERROR") echo -e "${RED}💥 [ERROR]${NC} $2" ;;
        "KAWAII") echo -e "${PINK}✨ [HEDGII]${NC} $2" ;;
    esac
}

if [[ -z "$ENCRYPTED_FILE" ]]; then
    hedgii_log "ERROR" "Usage: $0 [--passphrase-file FILE] <encrypted_backup_file> [output_directory]"
    exit 1
fi

if [[ ! -f "$ENCRYPTED_FILE" ]]; then
    hedgii_log "ERROR" "Encrypted file not found: $ENCRYPTED_FILE"
    exit 1
fi

if [[ -z "$PASSPHRASE_FILE" && -f "$CONFIG_FILE" ]]; then
    PASSPHRASE_FILE=$(jq -r '.settings.encrypt_passphrase_file // empty' "$CONFIG_FILE" 2>/dev/null)
fi

if [[ -z "$PASSPHRASE_FILE" || ! -f "$PASSPHRASE_FILE" ]]; then
    hedgii_log "ERROR" "Passphrase file not found. Use --passphrase-file <file> or check your config."
    exit 1
fi

hedgii_log "KAWAII" "🦔 Uncurling your precious data..."
hedgii_log "INFO" "Decrypting: $ENCRYPTED_FILE"
hedgii_log "INFO" "Output directory: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR" || { hedgii_log "ERROR" "Cannot create $OUTPUT_DIR"; exit 1; }

decrypt_to() { # stdout or file
    gpg --batch --yes --quiet --passphrase-file "$PASSPHRASE_FILE" --decrypt "$ENCRYPTED_FILE"
}

# Detect format from name
FORMAT=""
case "$ENCRYPTED_FILE" in
    *.zip.gpg|*.zip) FORMAT="zip" ;;
    *.tar.gz.gpg|*.tgz.gpg|*.tar.gz|*.tgz) FORMAT="tar" ;;
esac

TMP_FILE=""
cleanup() { [[ -n "$TMP_FILE" ]] && rm -f "$TMP_FILE"; }
trap cleanup EXIT

fail() { hedgii_log "ERROR" "$1"; exit 1; }

# Fallback: decrypt to temp file and sniff the type
if [[ -z "$FORMAT" ]]; then
    TMP_FILE=$(umask 077 && mktemp) || fail "Cannot create temporary file"
    decrypt_to > "$TMP_FILE" || fail "Failed to decrypt backup (wrong passphrase or corrupted file)!"
    MAGIC=$(head -c 2 "$TMP_FILE" | od -An -tx1 | tr -d ' \n')
    case "$MAGIC" in
        504b) FORMAT="zip" ;;
        1f8b) FORMAT="tar" ;;
        *) fail "Unknown archive format after decryption" ;;
    esac
fi

if [[ "$FORMAT" == "zip" ]]; then
    command -v unzip >/dev/null 2>&1 || fail "unzip is required to restore ZIP backups"
    if [[ -z "$TMP_FILE" ]]; then
        TMP_FILE=$(umask 077 && mktemp) || fail "Cannot create temporary file"
        decrypt_to > "$TMP_FILE" || fail "Failed to decrypt backup (wrong passphrase or corrupted file)!"
    fi
    unzip -q -o "$TMP_FILE" -d "$OUTPUT_DIR" || fail "Failed to extract ZIP archive (corrupted?)"
else
    if [[ -n "$TMP_FILE" ]]; then
        tar -xzf "$TMP_FILE" -C "$OUTPUT_DIR" || fail "Failed to extract TAR.GZ archive (corrupted?)"
    else
        decrypt_to | tar -xzf - -C "$OUTPUT_DIR" || fail "Failed to decrypt or extract backup (wrong passphrase or corrupted file)!"
    fi
fi

# Verify
if [[ -z "$(find "$OUTPUT_DIR" -mindepth 1 -print -quit)" ]]; then
    fail "Extraction produced no files in $OUTPUT_DIR"
fi

REPORT=$(find "$OUTPUT_DIR" -name hedgii_backup_report.txt -print -quit)
if [[ -n "$REPORT" ]]; then
    EXPECTED=$(sed -n 's/^Total files: *\([0-9][0-9]*\).*/\1/p' "$REPORT" | head -1)
    ACTUAL=$(find "$OUTPUT_DIR" -type f | wc -l)
    if [[ -n "$EXPECTED" && "$EXPECTED" != "$ACTUAL" ]]; then
        hedgii_log "INFO" "Warning: report mentions $EXPECTED files, extracted $ACTUAL"
    fi
fi

hedgii_log "KAWAII" "✅ Successfully uncurled! Your data is restored to: $OUTPUT_DIR"
hedgii_log "INFO" "Contents:"
ls -la "$OUTPUT_DIR"
