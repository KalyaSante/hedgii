#!/bin/bash

# 🦔 Hedgii Decrypt - Uncurl your protected data
# Usage: ./decrypt.sh <encrypted_backup_file> [output_directory]

ENCRYPTED_FILE="$1"
OUTPUT_DIR="${2:-/tmp/hedgii_restore}"
CONFIG_FILE="/etc/hedgii/hedgii_config.json"

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
    hedgii_log "ERROR" "Usage: $0 <encrypted_backup_file> [output_directory]"
    exit 1
fi

if [[ ! -f "$ENCRYPTED_FILE" ]]; then
    hedgii_log "ERROR" "Encrypted file not found: $ENCRYPTED_FILE"
    exit 1
fi

PASSPHRASE_FILE=$(jq -r '.settings.encrypt_passphrase_file' "$CONFIG_FILE" 2>/dev/null)

if [[ -z "$PASSPHRASE_FILE" || ! -f "$PASSPHRASE_FILE" ]]; then
    hedgii_log "ERROR" "Passphrase file not found. Check your config."
    exit 1
fi

hedgii_log "KAWAII" "🦔 Uncurling your precious data..."
hedgii_log "INFO" "Decrypting: $ENCRYPTED_FILE"
hedgii_log "INFO" "Output directory: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# Decrypt and extract
if gpg --batch --yes --passphrase-file "$PASSPHRASE_FILE" \
    --decrypt "$ENCRYPTED_FILE" | tar -xzf - -C "$OUTPUT_DIR"; then
    
    hedgii_log "KAWAII" "✅ Successfully uncurled! Your data is restored to: $OUTPUT_DIR"
    hedgii_log "INFO" "Contents:"
    ls -la "$OUTPUT_DIR"
else
    hedgii_log "ERROR" "Failed to decrypt backup!"
    exit 1
fi
