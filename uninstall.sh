#!/bin/bash

# 🦔 Hedgii Uninstall Script
# Safely remove your kawaii backup guardian

set -euo pipefail

# Colors for kawaii output
PINK='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

# Installation paths
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/hedgii"
LOG_DIR="/var/log/hedgii"
BACKUP_DIR="/var/backups/hedgii"
SCRIPT_NAME="hedgii"

# Kawaii logging function
hedgii_uninstall_log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")   echo -e "${GREEN}🦔 [INFO]${NC} $message" ;;
        "WARN")   echo -e "${YELLOW}⚠️  [WARN]${NC} $message" ;;
        "ERROR")  echo -e "${RED}💥 [ERROR]${NC} $message" ;;
        "KAWAII") echo -e "${PINK}✨ [HEDGII]${NC} $message" ;;
        "ASK")    echo -e "${BLUE}🤔 [INPUT]${NC} $message" ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        hedgii_uninstall_log "ERROR" "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Welcome message
show_welcome() {
    clear
    echo -e "${PINK}"
    cat << 'EOF'
    🦔 =============================================== 🦔
    
         💔 Hedgii Uninstall Script 💔
         
         Are you sure you want to remove your
         kawaii backup guardian? (｡•́︿•̀｡)
         
    🦔 =============================================== 🦔
EOF
    echo -e "${NC}"
    echo ""
}

# Confirm uninstallation
confirm_uninstall() {
    hedgii_uninstall_log "ASK" "This will remove Hedgii and all its components."
    echo ""
    echo "⚠️  WARNING: This will remove:"
    echo "   - Hedgii script and configuration"
    echo "   - Scheduled backup jobs (cron)"
    echo "   - Log files and rotation config"
    echo "   - System aliases"
    echo ""
    echo "💾 PRESERVED: Your encrypted backup files will be kept safe!"
    echo ""
    
    read -p "🤔 Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        hedgii_uninstall_log "KAWAII" "Uninstall cancelled! Hedgii is still protecting your data! (≧◡≦)"
        exit 0
    fi
}

# Ask about data removal
ask_data_removal() {
    echo ""
    hedgii_uninstall_log "ASK" "What should we do with your data?"
    echo ""
    echo "📁 Data locations:"
    echo "   Config: $CONFIG_DIR"
    echo "   Logs: $LOG_DIR"
    echo "   Backups: $BACKUP_DIR"
    echo ""
    echo "Options:"
    echo "   1) Keep all data (recommended)"
    echo "   2) Remove config and logs, keep backups"
    echo "   3) Remove everything (DANGEROUS!)"
    echo ""
    
    local choice=""
    while [[ ! "$choice" =~ ^[1-3]$ ]]; do
        read -p "🤔 Choose option (1-3): " choice
    done
    
    case "$choice" in
        1)
            hedgii_uninstall_log "INFO" "Keeping all data safe"
            REMOVE_CONFIG=false
            REMOVE_LOGS=false
            REMOVE_BACKUPS=false
            ;;
        2)
            hedgii_uninstall_log "INFO" "Removing config and logs, keeping backups"
            REMOVE_CONFIG=true
            REMOVE_LOGS=true
            REMOVE_BACKUPS=false
            ;;
        3)
            hedgii_uninstall_log "WARN" "Removing everything - I hope you know what you're doing!"
            echo ""
            read -p "🚨 Type 'DELETE ALL MY DATA' to confirm: " danger_confirm
            if [[ "$danger_confirm" == "DELETE ALL MY DATA" ]]; then
                REMOVE_CONFIG=true
                REMOVE_LOGS=true
                REMOVE_BACKUPS=true
            else
                hedgii_uninstall_log "INFO" "Dangerous option cancelled, keeping data safe"
                REMOVE_CONFIG=false
                REMOVE_LOGS=false
                REMOVE_BACKUPS=false
            fi
            ;;
    esac
}

# Remove cron jobs
remove_cron_jobs() {
    hedgii_uninstall_log "INFO" "Removing scheduled backup jobs..."
    
    # Remove cron.d file
    if [[ -f "/etc/cron.d/hedgii-backup" ]]; then
        rm -f "/etc/cron.d/hedgii-backup"
        hedgii_uninstall_log "INFO" "Removed cron job: /etc/cron.d/hedgii-backup"
    fi
    
    # Remove from root crontab if exists
    if crontab -l 2>/dev/null | grep -q hedgii; then
        crontab -l 2>/dev/null | grep -v hedgii | crontab -
        hedgii_uninstall_log "INFO" "Removed hedgii entries from root crontab"
    fi
    
    # Restart cron service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true
    else
        service cron restart 2>/dev/null || service crond restart 2>/dev/null || true
    fi
}

# Remove log rotation
remove_log_rotation() {
    hedgii_uninstall_log "INFO" "Removing log rotation configuration..."
    
    if [[ -f "/etc/logrotate.d/hedgii" ]]; then
        rm -f "/etc/logrotate.d/hedgii"
        hedgii_uninstall_log "INFO" "Removed logrotate config"
    fi
}

# Remove aliases
remove_aliases() {
    hedgii_uninstall_log "INFO" "Removing kawaii aliases..."
    
    local alias_file="/etc/bash.bashrc"
    
    if [[ -f "$alias_file" ]] && grep -q "Hedgii Kawaii Aliases" "$alias_file"; then
        # Create temporary file without hedgii aliases
        local temp_file=$(mktemp)
        
        # Remove lines between "Hedgii Kawaii Aliases" and the end of the alias block
        awk '
            /# 🦔 Hedgii Kawaii Aliases/ { skip = 1; next }
            /^alias hedgii-/ && skip { next }
            /^$/ && skip { skip = 0; next }
            !skip { print }
        ' "$alias_file" > "$temp_file"
        
        mv "$temp_file" "$alias_file"
        hedgii_uninstall_log "INFO" "Removed aliases from $alias_file"
    fi
}

# Remove script files
remove_script_files() {
    hedgii_uninstall_log "INFO" "Removing Hedgii script files..."
    
    # Remove main script
    if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        rm -f "$INSTALL_DIR/$SCRIPT_NAME"
        hedgii_uninstall_log "INFO" "Removed main script: $INSTALL_DIR/$SCRIPT_NAME"
    fi
    
    # Remove symlink
    if [[ -L "/usr/bin/hedgii" ]]; then
        rm -f "/usr/bin/hedgii"
        hedgii_uninstall_log "INFO" "Removed symlink: /usr/bin/hedgii"
    fi
}

# Remove data directories
remove_data_directories() {
    # Remove config directory
    if [[ "$REMOVE_CONFIG" == true ]] && [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        hedgii_uninstall_log "INFO" "Removed configuration directory: $CONFIG_DIR"
    elif [[ -d "$CONFIG_DIR" ]]; then
        hedgii_uninstall_log "INFO" "Preserved configuration directory: $CONFIG_DIR"
    fi
    
    # Remove log directory
    if [[ "$REMOVE_LOGS" == true ]] && [[ -d "$LOG_DIR" ]]; then
        rm -rf "$LOG_DIR"
        hedgii_uninstall_log "INFO" "Removed log directory: $LOG_DIR"
    elif [[ -d "$LOG_DIR" ]]; then
        hedgii_uninstall_log "INFO" "Preserved log directory: $LOG_DIR"
    fi
    
    # Remove backup directory
    if [[ "$REMOVE_BACKUPS" == true ]] && [[ -d "$BACKUP_DIR" ]]; then
        hedgii_uninstall_log "WARN" "Removing backup directory: $BACKUP_DIR"
        rm -rf "$BACKUP_DIR"
        hedgii_uninstall_log "WARN" "🚨 ALL YOUR LOCAL BACKUPS HAVE BEEN DELETED! 🚨"
    elif [[ -d "$BACKUP_DIR" ]]; then
        hedgii_uninstall_log "INFO" "Preserved backup directory: $BACKUP_DIR"
    fi
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${PINK}"
    cat << 'EOF'
    🦔 =============================================== 🦔
    
         💔 Hedgii Uninstall Complete 💔
         
         Your kawaii backup guardian has been
         removed, but memories remain... (｡•́︿•̀｡)
         
    🦔 =============================================== 🦔
EOF
    echo -e "${NC}"
    echo ""
    hedgii_uninstall_log "KAWAII" "Uninstall completed successfully."
    echo ""
    echo "📋 What was removed:"
    echo "   ✓ Hedgii script and symlinks"
    echo "   ✓ Scheduled backup jobs (cron)"
    echo "   ✓ Log rotation configuration"
    echo "   ✓ System aliases"
    echo ""
    
    if [[ "$REMOVE_CONFIG" == true ]]; then
        echo "   ✓ Configuration files"
    else
        echo "   ❌ Configuration files (preserved)"
    fi
    
    if [[ "$REMOVE_LOGS" == true ]]; then
        echo "   ✓ Log files"
    else
        echo "   ❌ Log files (preserved)"
    fi
    
    if [[ "$REMOVE_BACKUPS" == true ]]; then
        echo "   ✓ Local backup files"
    else
        echo "   ❌ Local backup files (preserved)"
    fi
    
    echo ""
    if [[ "$REMOVE_BACKUPS" == false ]]; then
        echo "💾 Your encrypted backup files are still safe at: $BACKUP_DIR"
        echo "🔐 Don't forget your GPG passphrase to decrypt them!"
    fi
    echo ""
    echo "🦔 To reinstall Hedgii in the future:"
    echo "   git clone https://github.com/damienmarill/hedgii.git && cd hedgii && sudo ./install.sh"
    echo ""
    hedgii_uninstall_log "KAWAII" "Thank you for using Hedgii! Stay safe! (｡◕‿◕｡)"
}

# Main uninstall function
main() {
    show_welcome
    check_root
    confirm_uninstall
    ask_data_removal
    
    hedgii_uninstall_log "INFO" "Starting Hedgii uninstall process..."
    
    remove_cron_jobs
    remove_log_rotation
    remove_aliases
    remove_script_files
    remove_data_directories
    
    show_completion
}

# Run uninstall
main "$@"
