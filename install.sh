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

# Fix Debian repositories if needed
fix_debian_repos() {
    if [[ -f /etc/debian_version ]]; then
        local debian_version=$(cat /etc/debian_version)
        hedgii_install_log "INFO" "Debian version: $debian_version"
        
        # Check if we're on an obsolete Debian version
        if [[ "$debian_version" == "10."* ]] || grep -q "buster" /etc/os-release 2>/dev/null; then
            hedgii_install_log "WARN" "Detected Debian 10 (buster) - updating repository sources..."
            
            # Backup original sources.list
            if [[ ! -f /etc/apt/sources.list.backup ]]; then
                cp /etc/apt/sources.list /etc/apt/sources.list.backup
            fi
            
            # Update to archive repositories
            cat > /etc/apt/sources.list << 'EOF'
# Debian 10 (buster) - Archive repositories
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main contrib non-free
EOF
            hedgii_install_log "INFO" "Updated repositories to use archive.debian.org"
        fi
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
            # Fix repositories if needed
            fix_debian_repos

            # Try to update, but continue even if it fails
            hedgii_install_log "INFO" "Updating package lists..."
            if ! apt-get update; then
                hedgii_install_log "WARN" "Package update failed, trying alternative approach..."

                # Try to install packages individually
                install_packages_individually_apt
            else
                # Normal installation
                if ! apt-get install -y jq gpg rsync curl cron logrotate zip; then
                    hedgii_install_log "WARN" "Bulk installation failed, trying individual packages..."
                    install_packages_individually_apt
                fi
            fi
            ;;
        "yum"|"dnf")
            $package_manager install -y jq gnupg2 rsync curl crontabs logrotate zip
            ;;
        "pacman")
            pacman -Sy --noconfirm jq gnupg rsync curl cronie logrotate zip
            ;;
    esac

    # Install sync clients
    install_sync_clients
}

# Install sync clients (rclone and optionally onedrive)
install_sync_clients() {
    hedgii_install_log "KAWAII" "🔄 Installing sync clients..."

    # Always try to install rclone
    if ! command -v rclone >/dev/null 2>&1; then
        hedgii_install_log "INFO" "Installing rclone..."
        if ! curl -fsSL https://rclone.org/install.sh | bash; then
            hedgii_install_log "WARN" "rclone auto-install failed, you may need to install it manually"
        fi
    else
        hedgii_install_log "INFO" "rclone already installed"
    fi

    # Ask about OneDrive client
    echo ""
    hedgii_install_log "ASK" "Would you like to install the OneDrive client (abraunegg/onedrive)?"
    echo "   This provides better OneDrive integration than rclone"
    echo "   Recommended if you only use OneDrive for cloud storage"
    echo ""

    local install_onedrive=""
    read -p "🦔 Install OneDrive client? (y/N): " install_onedrive

    if [[ "$install_onedrive" =~ ^[Yy]$ ]]; then
        install_onedrive_client
    else
        hedgii_install_log "INFO" "Skipping OneDrive client installation"
    fi
}

# Install abraunegg/onedrive client
install_onedrive_client() {
    hedgii_install_log "INFO" "Installing OneDrive client (abraunegg/onedrive)..."

    # Check if already installed
    if command -v onedrive >/dev/null 2>&1; then
        hedgii_install_log "INFO" "OneDrive client already installed"
        return 0
    fi

    # Install based on distribution
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        install_onedrive_debian
    elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        # RHEL/CentOS/Fedora
        install_onedrive_rhel
    elif command -v pacman >/dev/null 2>&1; then
        # Arch Linux
        install_onedrive_arch
    else
        hedgii_install_log "WARN" "Unsupported distribution for OneDrive auto-install"
        hedgii_install_log "INFO" "Please install manually: https://github.com/abraunegg/onedrive"
        return 1
    fi
}

# Install OneDrive client on Debian/Ubuntu
install_onedrive_debian() {
    # Try package manager first
    if apt-get install -y onedrive 2>/dev/null; then
        hedgii_install_log "INFO" "✅ OneDrive installed from repository"
        return 0
    fi

    # Install build dependencies
    hedgii_install_log "INFO" "Installing OneDrive build dependencies..."
    apt-get install -y build-essential pkg-config curl libcurl4-openssl-dev \
        libsqlite3-dev liblz4-dev libphobos2-ldc-dev ldc git

    # Install from source
    install_onedrive_from_source
}

# Install OneDrive client on RHEL/CentOS/Fedora
install_onedrive_rhel() {
    local package_manager="dnf"
    if command -v yum >/dev/null 2>&1 && ! command -v dnf >/dev/null 2>&1; then
        package_manager="yum"
    fi

    # Try package manager first
    if $package_manager install -y onedrive 2>/dev/null; then
        hedgii_install_log "INFO" "✅ OneDrive installed from repository"
        return 0
    fi

    # Install build dependencies
    hedgii_install_log "INFO" "Installing OneDrive build dependencies..."
    $package_manager install -y gcc gcc-c++ pkgconfig curl-devel sqlite-devel \
        lz4-devel ldc git

    # Install from source
    install_onedrive_from_source
}

# Install OneDrive client on Arch Linux
install_onedrive_arch() {
    # Try AUR or official repo
    if pacman -S --noconfirm onedrive 2>/dev/null; then
        hedgii_install_log "INFO" "✅ OneDrive installed from repository"
        return 0
    fi

    hedgii_install_log "WARN" "OneDrive not found in repos, install from AUR:"
    hedgii_install_log "INFO" "yay -S onedrive-abraunegg"
}

# Install OneDrive from source
install_onedrive_from_source() {
    hedgii_install_log "INFO" "Compiling OneDrive from source..."

    local build_dir="/tmp/onedrive-build"
    rm -rf "$build_dir"

    if git clone https://github.com/abraunegg/onedrive.git "$build_dir"; then
        cd "$build_dir"

        if make clean && make && make install; then
            hedgii_install_log "INFO" "✅ OneDrive compiled and installed successfully"
            rm -rf "$build_dir"
            return 0
        else
            hedgii_install_log "ERROR" "OneDrive compilation failed"
            rm -rf "$build_dir"
            return 1
        fi
    else
        hedgii_install_log "ERROR" "Failed to clone OneDrive repository"
        return 1
    fi
}

# Install packages individually for problematic apt systems
install_packages_individually_apt() {
    local packages=("jq" "gpg" "rsync" "curl" "cron" "logrotate" "zip")
    local failed_packages=()

    hedgii_install_log "INFO" "Installing packages individually..."

    for package in "${packages[@]}"; do
        if command -v "$package" >/dev/null 2>&1; then
            hedgii_install_log "INFO" "✓ $package already installed"
        else
            hedgii_install_log "INFO" "Installing $package..."
            if apt-get install -y "$package" 2>/dev/null; then
                hedgii_install_log "INFO" "✓ $package installed successfully"
            else
                hedgii_install_log "WARN" "✗ Failed to install $package"
                failed_packages+=("$package")
            fi
        fi
    done

    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        hedgii_install_log "WARN" "Failed to install: ${failed_packages[*]}"
        hedgii_install_log "INFO" "You may need to install these packages manually"
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
            # Create a basic config if no example exists
            cat > "$config_file" << 'EOF'
{
  "backup_sources": [
    {
      "source": "/var/www",
      "destination": "web",
      "description": "🌐 Website files"
    },
    {
      "source": "/etc/nginx",
      "destination": "config/nginx",
      "description": "⚙️ Nginx configuration"
    }
  ],
  "custom_commands": [
    {
      "command": "mysqldump --all-databases --single-transaction --routines --triggers",
      "description": "📊 Complete MySQL database dump",
      "output_file": "databases/mysql_full_dump.sql",
      "timeout": 600,
      "working_dir": "/tmp",
      "continue_on_error": false
    }
  ],
  "settings": {
    "staging_dir": "/tmp/hedgii_staging",
    "backup_dir": "/var/backups/hedgii",
    "encrypt_passphrase_file": "/etc/hedgii/gpg_passphrase",
    "compression_format": "zip",
    "rclone_remote": "onedrive:hedgii-backups/"
  },
  "exclusions": [
    "*.tmp",
    "*.log.old",
    "node_modules",
    ".git",
    "*.cache"
  ]
}
EOF
            hedgii_install_log "INFO" "Created basic configuration file"
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

# Setup log rotation
setup_log_rotation() {
    hedgii_install_log "INFO" "Setting up log rotation..."

    local logrotate_file="/etc/logrotate.d/hedgii"
    cat > "$logrotate_file" << EOF
# 🦔 Hedgii Log Rotation Configuration
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        # Send a kawaii signal that logs were rotated
        echo "🦔 Hedgii logs rotated on \$(date)" >> $LOG_DIR/hedgii_maintenance.log
    endscript
}
EOF

    chmod 644 "$logrotate_file"
    hedgii_install_log "INFO" "Log rotation configured (30 days retention)"
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
    if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]] && [[ -x "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        hedgii_install_log "INFO" "✓ Hedgii script installed and executable"

        # Try to validate config
        if "$INSTALL_DIR/$SCRIPT_NAME" validate-config >/dev/null 2>&1; then
            hedgii_install_log "INFO" "✓ Configuration validation passed"
        else
            hedgii_install_log "WARN" "⚠ Configuration validation failed (you may need to configure rclone)"
        fi
    else
        hedgii_install_log "ERROR" "✗ Hedgii script not properly installed"
    fi

    # Test cron job
    if crontab -l 2>/dev/null | grep -q hedgii || [[ -f "/etc/cron.d/hedgii-backup" ]]; then
        hedgii_install_log "INFO" "✓ Cron job configured"
    else
        hedgii_install_log "WARN" "⚠ Cron job not found"
    fi

    # Test dependencies with fallback checks
    local deps=("jq" "gpg" "rsync" "zip" "rclone")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            hedgii_install_log "INFO" "✓ $dep installed"
        else
            hedgii_install_log "WARN" "⚠ $dep not found"
            missing_deps+=("$dep")
        fi
    done

    # Special check for essential packages
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        hedgii_install_log "WARN" "Missing dependencies: ${missing_deps[*]}"
        hedgii_install_log "INFO" "You may need to install these manually:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "jq") hedgii_install_log "INFO" "  - jq: sudo apt-get install jq (or download from https://github.com/stedolan/jq/releases)" ;;
                "gpg") hedgii_install_log "INFO" "  - gpg: sudo apt-get install gpg gnupg" ;;
                "rsync") hedgii_install_log "INFO" "  - rsync: sudo apt-get install rsync" ;;
                "zip") hedgii_install_log "INFO" "  - zip: sudo apt-get install zip" ;;
                "rclone") hedgii_install_log "INFO" "  - rclone: curl https://rclone.org/install.sh | sudo bash" ;;
            esac
        done
    fi

    # Test directories
    local dirs=("$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR")
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            hedgii_install_log "INFO" "✓ Directory exists: $dir"
        else
            hedgii_install_log "WARN" "⚠ Directory missing: $dir"
        fi
    done
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
    echo "   2. Edit your backup sources: hedgii edit-config"
    echo "   3. Test your first backup: hedgii curl"
    echo "   4. Check backup status: hedgii sync-status"
    echo ""
    echo "📋 Useful Commands:"
    echo "   hedgii curl           - Run backup manually"
    echo "   hedgii sync-status    - Show sync clients status"
    echo "   hedgii edit-config    - Edit configuration"
    echo "   hedgii test-sync      - Test custom commands"
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
    setup_log_rotation
    setup_aliases
    test_installation
    show_completion
}

# Run installation
main "$@"
