#!/bin/bash

# 🦔 Hedgii Installation Script
# The kawaii backup guardian setup wizard

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

# Default cron schedule (2 AM daily)
DEFAULT_CRON_HOUR="2"
DEFAULT_CRON_MINUTE="0"

# Kawaii logging function
hedgii_install_log() {
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
        hedgii_install_log "ERROR" "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Welcome message
show_welcome() {
    clear
    echo -e "${PINK}"
    cat << 'EOF'
    🦔 =============================================== 🦔
    
         ✨ Welcome to Hedgii Installation! ✨
         
         Your kawaii backup guardian is ready
         to protect your precious data! (｡◕‿◕｡)
         
    🦔 =============================================== 🦔
EOF
    echo -e "${NC}"
    echo ""
}

# Check system compatibility
check_system() {
    hedgii_install_log "INFO" "Checking system compatibility..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        hedgii_install_log "ERROR" "Unsupported operating system"
        exit 1
    fi
    
    . /etc/os-release
    hedgii_install_log "INFO" "Detected OS: $PRETTY_NAME"
    
    # Check architecture
    local arch=$(uname -m)
    hedgii_install_log "INFO" "Architecture: $arch"
    
    # Check if systemd is available (for service management)
    if command -v systemctl >/dev/null 2>&1; then
        hedgii_install_log "INFO" "Systemd detected - advanced features available"
    fi
}

# Install dependencies
install_dependencies() {
    hedgii_install_log "KAWAII" "Installing dependencies for Hedgii..."
    
    # Detect package manager
    local package_manager=""
    if command -v apt-get >/dev/null 2>&1; then
        package_manager="apt"
    elif command -v yum >/dev/null 2>&1; then
        package_manager="yum"
    elif command -v dnf >/dev/null 2>&1; then
        package_manager="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        package_manager="pacman"
    else
        hedgii_install_log "ERROR" "Unsupported package manager"
        exit 1
    fi
    
    hedgii_install_log "INFO" "Using package manager: $package_manager"
    
    # Install based on package manager
    case "$package_manager" in
        "apt")
            apt-get update
            apt-get install -y jq gpg rsync curl cron logrotate
            ;;
        "yum"|"dnf")
            $package_manager install -y jq gnupg2 rsync curl crontabs logrotate
            ;;
        "pacman")
            pacman -Sy --noconfirm jq gnupg rsync curl cronie logrotate
            ;;
    esac
    
    # Install rclone
    if ! command -v rclone >/dev/null 2>&1; then
        hedgii_install_log "INFO" "Installing rclone..."
        curl -fsSL https://rclone.org/install.sh | bash
    else
        hedgii_install_log "INFO" "rclone already installed"
    fi
}

# Create directories
create_directories() {
    hedgii_install_log "INFO" "Creating Hedgii directories..."
    
    local dirs=("$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            hedgii_install_log "INFO" "Created directory: $dir"
        fi
    done
    
    # Set proper permissions
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$LOG_DIR"
    chmod 700 "$BACKUP_DIR"  # More secure for backups
}

# Install the main script
install_hedgii_script() {
    hedgii_install_log "INFO" "Installing Hedgii script..."
    
    # Copy the main script
    if [[ -f "hedgii.sh" ]]; then
        cp "hedgii.sh" "$INSTALL_DIR/$SCRIPT_NAME"
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
        hedgii_install_log "INFO" "Hedgii script installed to $INSTALL_DIR/$SCRIPT_NAME"
    else
        hedgii_install_log "ERROR" "hedgii.sh not found in current directory"
        exit 1
    fi
    
    # Create symlink for easy access
    if [[ ! -L "/usr/bin/hedgii" ]]; then
        ln -s "$INSTALL_DIR/$SCRIPT_NAME" "/usr/bin/hedgii"
        hedgii_install_log "INFO" "Created symlink: /usr/bin/hedgii"
    fi
}

# Setup configuration
setup_configuration() {
    hedgii_install_log "INFO" "Setting up configuration..."
    
    local config_file="$CONFIG_DIR/hedgii_config.json"
    
    # Copy example config if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        if [[ -f "config/hedgii_config.json.example" ]]; then
            cp "config/hedgii_config.json.example" "$config_file"
            hedgii_install_log "INFO" "Created configuration file: $config_file"
        else
            hedgii_install_log "ERROR" "Configuration example not found"
            exit 1
        fi
    fi
    
    chmod 644 "$config_file"
}

# Setup GPG passphrase
setup_gpg_passphrase() {
    local passphrase_file="$CONFIG_DIR/gpg_passphrase"
    
    if [[ ! -f "$passphrase_file" ]]; then
        hedgii_install_log "ASK" "Setting up GPG encryption..."
        echo ""
        echo "🔐 Hedgii needs a passphrase to encrypt your backups."
        echo "   This will be stored securely and used for all future backups."
        echo ""
        
        local passphrase=""
        local confirm_passphrase=""
        
        while [[ -z "$passphrase" || "$passphrase" != "$confirm_passphrase" ]]; do
            echo -n "🔑 Enter GPG passphrase: "
            read -s passphrase
            echo
            
            echo -n "🔑 Confirm GPG passphrase: "
            read -s confirm_passphrase
            echo
            
            if [[ -z "$passphrase" ]]; then
                hedgii_install_log "WARN" "Passphrase cannot be empty"
            elif [[ "$passphrase" != "$confirm_passphrase" ]]; then
                hedgii_install_log "WARN" "Passphrases don't match, try again"
            fi
        done
        
        echo "$passphrase" > "$passphrase_file"
        chmod 600 "$passphrase_file"
        hedgii_install_log "INFO" "GPG passphrase configured securely"
    else
        hedgii_install_log "INFO" "GPG passphrase already configured"
    fi
}

# Setup cron job
setup_cron_job() {
    hedgii_install_log "KAWAII" "Setting up automatic daily backups..."
    
    # Ask for cron schedule
    local cron_hour="$DEFAULT_CRON_HOUR"
    local cron_minute="$DEFAULT_CRON_MINUTE"
    
    echo ""
    hedgii_install_log "ASK" "When would you like daily backups to run?"
    echo "   Default: ${DEFAULT_CRON_HOUR}:${DEFAULT_CRON_MINUTE} (2:00 AM)"
    echo ""
    
    read -p "🕐 Enter hour (0-23) [default: $DEFAULT_CRON_HOUR]: " input_hour
    read -p "🕐 Enter minute (0-59) [default: $DEFAULT_CRON_MINUTE]: " input_minute
    
    # Validate input
    if [[ "$input_hour" =~ ^[0-9]+$ ]] && [[ "$input_hour" -ge 0 ]] && [[ "$input_hour" -le 23 ]]; then
        cron_hour="$input_hour"
    fi
    
    if [[ "$input_minute" =~ ^[0-9]+$ ]] && [[ "$input_minute" -ge 0 ]] && [[ "$input_minute" -le 59 ]]; then
        cron_minute="$input_minute"
    fi
    
    # Create cron job
    local cron_file="/etc/cron.d/hedgii-backup"
    cat > "$cron_file" << EOF
# 🦔 Hedgii Automatic Backup - Your kawaii guardian at work!
# Generated by Hedgii installer on $(date)

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Daily backup at ${cron_hour}:${cron_minute}
${cron_minute} ${cron_hour} * * * root $INSTALL_DIR/$SCRIPT_NAME curl >> $LOG_DIR/hedgii_cron.log 2>&1

# Weekly cleanup of old logs (Sunday at 3 AM)
0 3 * * 0 root find $LOG_DIR -name "*.log" -mtime +30 -delete
EOF
    
    chmod 644 "$cron_file"
    hedgii_install_log "INFO" "Cron job created: Daily backup at ${cron_hour}:${cron_minute}"
    
    # Restart cron service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true
    else
        service cron restart 2>/dev/null || service crond restart 2>/dev/null || true
    fi
}

# Setup bash aliases
setup_aliases() {
    hedgii_install_log "INFO" "Setting up convenient aliases..."
    
    local alias_file="/etc/bash.bashrc"
    local aliases="
# 🦔 Hedgii Kawaii Aliases
alias hedgii-backup='$INSTALL_DIR/$SCRIPT_NAME curl'
alias hedgii-status='$INSTALL_DIR/$SCRIPT_NAME peek'
alias hedgii-config='nano $CONFIG_DIR/hedgii_config.json'
alias hedgii-logs='tail -f $LOG_DIR/hedgii_*.log'
alias hedgii-test='$INSTALL_DIR/$SCRIPT_NAME test-commands'
"
    
    if ! grep -q "Hedgii Kawaii Aliases" "$alias_file" 2>/dev/null; then
        echo "$aliases" >> "$alias_file"
        hedgii_install_log "INFO" "Added kawaii aliases to $alias_file"
    fi
}

# Test installation
test_installation() {
    hedgii_install_log "INFO" "Testing Hedgii installation..."
    
    # Test script execution
    if "$INSTALL_DIR/$SCRIPT_NAME" validate-config >/dev/null 2>&1; then
        hedgii_install_log "INFO" "✓ Configuration validation passed"
    else
        hedgii_install_log "WARN" "⚠ Configuration validation failed (you may need to configure rclone)"
    fi
    
    # Test cron job
    if [[ -f "/etc/cron.d/hedgii-backup" ]]; then
        hedgii_install_log "INFO" "✓ Cron job configured"
    else
        hedgii_install_log "WARN" "⚠ Cron job not found"
    fi
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${PINK}"
    cat << 'EOF'
    🦔 =============================================== 🦔
    
         ✨ Hedgii Installation Complete! ✨
         
         Your kawaii backup guardian is now
         protecting your data automatically! (≧◡≦)
         
    🦔 =============================================== 🦔
EOF
    echo -e "${NC}"
    echo ""
    hedgii_install_log "KAWAII" "Installation successful! Hedgii is ready to protect your data!"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Configure rclone for cloud storage: rclone config"
    echo "   2. Edit your backup sources: hedgii-config"
    echo "   3. Test your first backup: hedgii-backup"
    echo "   4. Check backup status: hedgii-status"
    echo ""
    echo "📋 Useful Commands:"
    echo "   hedgii-backup    - Run backup manually"
    echo "   hedgii-status    - Check backup status"
    echo "   hedgii-config    - Edit configuration"
    echo "   hedgii-logs      - View logs in real-time"
    echo "   hedgii-test      - Test custom commands"
    echo ""
    echo "🕐 Automatic Backups:"
    echo "   Daily at ${cron_hour}:${cron_minute} (configured in /etc/cron.d/hedgii-backup)"
    echo ""
    echo "📁 Important Locations:"
    echo "   Configuration: $CONFIG_DIR/hedgii_config.json"
    echo "   Logs: $LOG_DIR/"
    echo "   Backups: $BACKUP_DIR/"
    echo ""
    hedgii_install_log "KAWAII" "Remember: A backed-up hedgehog is a happy hedgehog! 🦔💖"
}

# Main installation function
main() {
    show_welcome
    check_root
    check_system
    install_dependencies
    create_directories
    install_hedgii_script
    setup_configuration
    setup_gpg_passphrase
    setup_cron_job
    setup_aliases
    test_installation
    show_completion
}

# Run installation
main "$@"
