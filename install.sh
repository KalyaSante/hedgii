#!/bin/bash

# 🦔 Hedgii Installation Script
# The kawaii way to install your backup guardian

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/hedgii"
LOG_DIR="/var/log/hedgii"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[1;32m'
PINK='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

hedgii_log() {
    case "$1" in
        "INFO")  echo -e "${GREEN}🦔 [INFO]${NC} $2" ;;
        "KAWAII") echo -e "${PINK}✨ [HEDGII]${NC} $2" ;;
        "STEP")  echo -e "${CYAN}🔧 [STEP]${NC} $2" ;;
    esac
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

hedgii_log "KAWAII" "🦔 Welcome to Hedgii Installation! (｡◕‿◕｡)"

# Create directories
hedgii_log "STEP" "Creating directories..."
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "/var/backups/hedgii"

# Install dependencies
hedgii_log "STEP" "Installing dependencies..."
apt update && apt install -y jq gpg rsync curl

# Install rclone if not present
if ! command -v rclone >/dev/null 2>&1; then
    hedgii_log "STEP" "Installing rclone..."
    curl https://rclone.org/install.sh | bash
fi

# Copy scripts
hedgii_log "STEP" "Installing Hedgii scripts..."
cp "$SCRIPT_DIR/hedgii.sh" "$INSTALL_DIR/hedgii-backup"
cp -r "$SCRIPT_DIR/scripts" "$CONFIG_DIR/"
chmod +x "$INSTALL_DIR/hedgii-backup"
chmod +x "$CONFIG_DIR/scripts/"*.sh

# Copy config example
if [[ ! -f "$CONFIG_DIR/hedgii_config.json" ]]; then
    cp "$SCRIPT_DIR/config/hedgii_config.json.example" "$CONFIG_DIR/hedgii_config.json"
    hedgii_log "INFO" "Config file created: $CONFIG_DIR/hedgii_config.json"
fi

# Setup passphrase file
hedgii_log "STEP" "Setting up encryption..."
if [[ ! -f "$CONFIG_DIR/passphrase" ]]; then
    echo "Please enter your backup encryption passphrase:"
    read -s passphrase
    echo "$passphrase" > "$CONFIG_DIR/passphrase"
    chmod 600 "$CONFIG_DIR/passphrase"
    hedgii_log "INFO" "Passphrase file created"
fi

# Create aliases
hedgii_log "STEP" "Creating convenient aliases..."
echo "alias hedgii='$INSTALL_DIR/hedgii-backup'" >> /etc/bash.bashrc
echo "alias hedgii-decrypt='$CONFIG_DIR/scripts/decrypt.sh'" >> /etc/bash.bashrc
echo "alias hedgii-recover='$CONFIG_DIR/scripts/recover_key.sh'" >> /etc/bash.bashrc

hedgii_log "KAWAII" "✅ Hedgii installation complete! (≧◡≦)"
hedgii_log "INFO" "Next steps:"
hedgii_log "INFO" "1. Configure rclone: rclone config"
hedgii_log "INFO" "2. Edit config: nano $CONFIG_DIR/hedgii_config.json"
hedgii_log "INFO" "3. Run backup: hedgii-backup"
hedgii_log "KAWAII" "🦔 Your data guardian is ready!"
