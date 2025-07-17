#!/bin/bash

# 🦔 Hedgii Key Recovery - Recover your encryption key
# Usage: ./recover_key.sh

CONFIG_FILE="/etc/hedgii/hedgii_config.json"

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
PINK='\033[1;35m'
YELLOW='\033[1;33m'
NC='\033[0m'

hedgii_log() {
    case "$1" in
        "INFO")  echo -e "${GREEN}🦔 [INFO]${NC} $2" ;;
        "ERROR") echo -e "${RED}💥 [ERROR]${NC} $2" ;;
        "KAWAII") echo -e "${PINK}✨ [HEDGII]${NC} $2" ;;
        "WARN")  echo -e "${YELLOW}⚠️  [WARN]${NC} $2" ;;
    esac
}

hedgii_log "KAWAII" "🦔 Hedgii Key Recovery Tool"
hedgii_log "INFO" "This will help you recover your encryption key information"

if [[ ! -f "$CONFIG_FILE" ]]; then
    hedgii_log "ERROR" "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Get passphrase file location
PASSPHRASE_FILE=$(jq -r '.settings.encrypt_passphrase_file' "$CONFIG_FILE" 2>/dev/null)

if [[ -z "$PASSPHRASE_FILE" ]]; then
    hedgii_log "ERROR" "Passphrase file path not found in config"
    exit 1
fi

hedgii_log "INFO" "Passphrase file location: $PASSPHRASE_FILE"

if [[ -f "$PASSPHRASE_FILE" ]]; then
    hedgii_log "INFO" "Passphrase file exists and is readable"
    hedgii_log "INFO" "File permissions: $(ls -l "$PASSPHRASE_FILE")"
    hedgii_log "KAWAII" "✅ Your encryption key is safe and sound!"
else
    hedgii_log "ERROR" "Passphrase file not found!"
    hedgii_log "WARN" "You may need to recreate your passphrase file"
    
    read -p "Would you like to create a new passphrase file? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        hedgii_log "INFO" "Creating new passphrase file..."
        echo "Please enter your new passphrase:"
        read -s passphrase
        echo "$passphrase" | sudo tee "$PASSPHRASE_FILE" > /dev/null
        sudo chmod 600 "$PASSPHRASE_FILE"
        hedgii_log "KAWAII" "✅ New passphrase file created!"
    fi
fi
