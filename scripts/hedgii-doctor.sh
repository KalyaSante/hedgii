#!/bin/bash

# 🦔 Hedgii Doctor - Diagnostic and Repair Tool
# Kawaii troubleshooter for your backup guardian

set -euo pipefail

CONFIG_FILE="${HEDGII_CONFIG_FILE:-/etc/hedgii/hedgii_config.json}"

# Colors for kawaii output
PINK='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

# Kawaii logging function
doctor_log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")   echo -e "${GREEN}🦔 [INFO]${NC} $message" ;;
        "WARN")   echo -e "${YELLOW}⚠️  [WARN]${NC} $message" ;;
        "ERROR")  echo -e "${RED}💥 [ERROR]${NC} $message" ;;
        "OK")     echo -e "${GREEN}✅ [OK]${NC} $message" ;;
        "FAIL")   echo -e "${RED}❌ [FAIL]${NC} $message" ;;
        "KAWAII") echo -e "${PINK}✨ [DOCTOR]${NC} $message" ;;
        "FIX")    echo -e "${BLUE}🔧 [FIX]${NC} $message" ;;
    esac
}

# Show welcome
show_welcome() {
    clear
    echo -e "${PINK}"
    cat << 'EOF'
    🦔 =============================================== 🦔
    
         🩺 Hedgii Doctor - Health Check 🩺
         
         Let's diagnose your kawaii backup guardian
         and fix any problems! (｡◕‿◕｡)
         
    🦔 =============================================== 🦔
EOF
    echo -e "${NC}"
    echo ""
}

# Check system information
check_system_info() {
    doctor_log "INFO" "System Information"
    echo "   OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo 'Unknown')"
    echo "   Kernel: $(uname -r)"
    echo "   Architecture: $(uname -m)"
    echo "   Date: $(date)"
    echo "   Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo ""
}

# Check Hedgii installation
check_hedgii_installation() {
    doctor_log "KAWAII" "Checking Hedgii Installation..."
    
    local issues=0
    
    # Check main script
    if [[ -f "/usr/local/bin/hedgii" ]]; then
        doctor_log "OK" "Main script installed"
        if [[ -x "/usr/local/bin/hedgii" ]]; then
            doctor_log "OK" "Script is executable"
        else
            doctor_log "FAIL" "Script not executable"
            doctor_log "FIX" "Run: sudo chmod +x /usr/local/bin/hedgii"
            issues=$((issues + 1))
        fi
    else
        doctor_log "FAIL" "Main script not found"
        doctor_log "FIX" "Run the installer: sudo ./install.sh"
        issues=$((issues + 1))
    fi
    
    # Check symlink
    if [[ -L "/usr/bin/hedgii" ]]; then
        doctor_log "OK" "Symlink exists"
    else
        doctor_log "WARN" "Symlink missing"
        doctor_log "FIX" "Run: sudo ln -s /usr/local/bin/hedgii /usr/bin/hedgii"
    fi
    
    # Check configuration directory
    if [[ -d "/etc/hedgii" ]]; then
        doctor_log "OK" "Configuration directory exists"
        
        # Check config file
        if [[ -f "/etc/hedgii/hedgii_config.json" ]]; then
            doctor_log "OK" "Configuration file exists"
            
            # Validate JSON
            if jq empty /etc/hedgii/hedgii_config.json 2>/dev/null; then
                doctor_log "OK" "Configuration JSON is valid"
            else
                doctor_log "FAIL" "Configuration JSON is invalid"
                doctor_log "FIX" "Check syntax: jq . /etc/hedgii/hedgii_config.json"
                issues=$((issues + 1))
            fi
        else
            doctor_log "FAIL" "Configuration file missing"
            doctor_log "FIX" "Copy example config or run installer"
            issues=$((issues + 1))
        fi
        
        # Check GPG passphrase
        if [[ -f "/etc/hedgii/gpg_passphrase" ]]; then
            doctor_log "OK" "GPG passphrase file exists"
            
            local perms=$(stat -c %a /etc/hedgii/gpg_passphrase 2>/dev/null)
            if [[ "$perms" == "600" ]]; then
                doctor_log "OK" "GPG passphrase permissions correct"
            else
                doctor_log "WARN" "GPG passphrase permissions too open: $perms"
                doctor_log "FIX" "Run: sudo chmod 600 /etc/hedgii/gpg_passphrase"
            fi
        else
            doctor_log "FAIL" "GPG passphrase file missing"
            doctor_log "FIX" "Create passphrase file or run installer"
            issues=$((issues + 1))
        fi
    else
        doctor_log "FAIL" "Configuration directory missing"
        doctor_log "FIX" "Run: sudo mkdir -p /etc/hedgii"
        issues=$((issues + 1))
    fi
    
    echo ""
    return $issues
}

# Check dependencies
check_dependencies() {
    doctor_log "KAWAII" "Checking Dependencies..."
    
    local deps=("jq" "gpg" "rsync" "rclone" "cron")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            doctor_log "OK" "$dep installed"
            
            # Special checks
            case "$dep" in
                "jq")
                    local jq_version=$(jq --version 2>/dev/null || echo "unknown")
                    echo "      Version: $jq_version"
                    ;;
                "rclone")
                    local rclone_version=$(rclone version 2>/dev/null | head -1 || echo "unknown")
                    echo "      Version: $rclone_version"
                    ;;
                "gpg")
                    local gpg_version=$(gpg --version 2>/dev/null | head -1 || echo "unknown")
                    echo "      Version: $gpg_version"
                    ;;
            esac
        else
            doctor_log "FAIL" "$dep not found"
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        doctor_log "FIX" "Install missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "jq") echo "      sudo apt-get install jq" ;;
                "gpg") echo "      sudo apt-get install gpg gnupg" ;;
                "rsync") echo "      sudo apt-get install rsync" ;;
                "rclone") echo "      curl https://rclone.org/install.sh | sudo bash" ;;
                "cron") echo "      sudo apt-get install cron" ;;
            esac
        done
    fi
    
    echo ""
    return ${#missing_deps[@]}
}

# Check repositories (for Debian/Ubuntu)
check_repositories() {
    if [[ -f /etc/debian_version ]]; then
        doctor_log "KAWAII" "Checking APT Repositories..."
        
        # Check if update works
        if apt-get update >/dev/null 2>&1; then
            doctor_log "OK" "APT repositories working"
        else
            doctor_log "FAIL" "APT repositories have issues"
            
            # Check for common problems
            if grep -q "buster" /etc/apt/sources.list 2>/dev/null; then
                doctor_log "WARN" "Detected obsolete Debian 10 (buster) repositories"
                doctor_log "FIX" "Update to archive repositories:"
                echo "      sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup"
                echo "      sudo tee /etc/apt/sources.list << 'EOF'"
                echo "deb http://archive.debian.org/debian buster main contrib non-free"
                echo "deb http://archive.debian.org/debian-security buster/updates main contrib non-free"
                echo "EOF"
                echo "      sudo apt-get update"
            fi
        fi
        echo ""
    fi
}

# Check cron jobs
check_cron_jobs() {
    doctor_log "KAWAII" "Checking Scheduled Backups..."
    
    local cron_issues=0
    
    # Check cron.d file
    if [[ -f "/etc/cron.d/hedgii-backup" ]]; then
        doctor_log "OK" "Cron job file exists"
        
        # Show schedule
        local schedule=$(grep -v '^#' /etc/cron.d/hedgii-backup | grep hedgii | head -1)
        if [[ -n "$schedule" ]]; then
            doctor_log "INFO" "Schedule: $schedule"
        fi
    else
        doctor_log "FAIL" "Cron job file missing"
        doctor_log "FIX" "Re-run installer or create manually"
        cron_issues=$((cron_issues + 1))
    fi
    
    # Check cron service
    if systemctl is-active cron >/dev/null 2>&1 || systemctl is-active crond >/dev/null 2>&1; then
        doctor_log "OK" "Cron service running"
    else
        doctor_log "FAIL" "Cron service not running"
        doctor_log "FIX" "Start cron: sudo systemctl start cron"
        cron_issues=$((cron_issues + 1))
    fi
    
    echo ""
    return $cron_issues
}

# Check disk space
check_disk_space() {
    doctor_log "KAWAII" "Checking Disk Space..."
    
    local locations=("/tmp" "/var/backups" "/var/log")
    
    for location in "${locations[@]}"; do
        if [[ -d "$location" ]]; then
            local usage=$(df -h "$location" | tail -1 | awk '{print $5}' | sed 's/%//')
            local available=$(df -h "$location" | tail -1 | awk '{print $4}')
            
            if [[ $usage -lt 80 ]]; then
                doctor_log "OK" "$location: ${usage}% used, $available available"
            elif [[ $usage -lt 90 ]]; then
                doctor_log "WARN" "$location: ${usage}% used, $available available"
            else
                doctor_log "FAIL" "$location: ${usage}% used, $available available"
                doctor_log "FIX" "Clean up space in $location"
            fi
        fi
    done

    local cfg="/etc/hedgii/hedgii_config.json"
    if [[ -f "$cfg" ]] && command -v jq >/dev/null 2>&1; then
        local bdir=$(jq -r '.settings.backup_dir // "/var/backups/hedgii"' "$cfg" 2>/dev/null)
        local f
        for f in "$bdir"/hedgii_backup_*.gpg; do
            [[ -f "$f" ]] || continue
            if [[ ! -f "$f.uploaded" ]]; then
                doctor_log "WARN" "Archive never uploaded (never auto-deleted): $f"
            fi
        done
    fi

    echo ""
}

# Test sync clients (both rclone and onedrive)
test_sync_clients() {
    doctor_log "KAWAII" "Testing Sync Clients..."

    local sync_issues=0
    local available_clients=()

    # Test rclone
    if command -v rclone >/dev/null 2>&1; then
        doctor_log "OK" "rclone installed"
        available_clients+=("rclone")

        local rclone_version=$(rclone version 2>/dev/null | head -1 || echo "unknown")
        echo "      Version: $rclone_version"

        # Test the configured rclone remote (exact name, write probe)
        local rclone_cfg rclone_remote rclone_timeout remote_name
        # Same resolution as hedgii.sh get_rclone_config (legacy root config for older installs)
        rclone_cfg=$(jq -r '.settings.rclone_config // empty' "$CONFIG_FILE" 2>/dev/null || true)
        if [[ -z "$rclone_cfg" ]]; then
            rclone_cfg="/etc/hedgii/rclone.conf"
            if [[ ! -f "$rclone_cfg" && -f /root/.config/rclone/rclone.conf ]]; then
                rclone_cfg="/root/.config/rclone/rclone.conf"
                doctor_log "WARN" "Using legacy rclone config $rclone_cfg"
                doctor_log "FIX" "Migrate it: sudo hedgii setup-rclone"
            fi
        fi
        rclone_remote=$(jq -r '.settings.rclone_remote // "onedrive:hedgii-backups/"' "$CONFIG_FILE" 2>/dev/null || echo "onedrive:hedgii-backups/")
        rclone_timeout=$(jq -r '.settings.rclone_timeout // 60' "$CONFIG_FILE" 2>/dev/null || echo 60)
        [[ "$rclone_timeout" =~ ^[0-9]+$ ]] || rclone_timeout=60
        remote_name="${rclone_remote%%:*}"

        if [[ ! -f "$rclone_cfg" ]]; then
            doctor_log "WARN" "rclone config not found: $rclone_cfg"
            doctor_log "FIX" "Run: sudo hedgii setup-rclone"
            sync_issues=$((sync_issues + 1))
        elif ! rclone --config "$rclone_cfg" listremotes 2>/dev/null | grep -Fxq "${remote_name}:"; then
            doctor_log "WARN" "Configured remote '${remote_name}' not found in $rclone_cfg"
            doctor_log "FIX" "Run: sudo hedgii setup-rclone"
            sync_issues=$((sync_issues + 1))
        else
            doctor_log "OK" "rclone remote '${remote_name}' present in $rclone_cfg"
            [[ "$rclone_remote" == */ || "$rclone_remote" == *: ]] || rclone_remote="$rclone_remote/"
            local probe_name=".hedgii-probe-$(date +%Y%m%d_%H%M%S)"
            local probe_file probe_out content="hedgii-doctor-$$-$RANDOM"
            probe_file=$(mktemp)
            echo "$content" > "$probe_file"
            doctor_log "INFO" "Testing write access on $rclone_remote (timeout ${rclone_timeout}s)..."
            if probe_out=$(timeout "$rclone_timeout" rclone --config "$rclone_cfg" copyto "$probe_file" "${rclone_remote}${probe_name}" 2>&1) \
                && probe_out=$(timeout "$rclone_timeout" rclone --config "$rclone_cfg" cat "${rclone_remote}${probe_name}" 2>&1) \
                && [[ "$probe_out" == "$content" ]]; then
                doctor_log "OK" "rclone remote is readable and writable"
            else
                doctor_log "WARN" "rclone write test failed: $probe_out"
                if echo "$probe_out" | grep -Eqi 'invalid_grant|token expired|expired token|401|unauthorized'; then
                    doctor_log "FIX" "Token expired: rclone config reconnect ${remote_name}: --config $rclone_cfg"
                else
                    doctor_log "FIX" "Run: sudo hedgii setup-rclone"
                fi
                sync_issues=$((sync_issues + 1))
            fi
            timeout "$rclone_timeout" rclone --config "$rclone_cfg" deletefile "${rclone_remote}${probe_name}" >/dev/null 2>&1 || true
            rm -f "$probe_file"
        fi
    else
        doctor_log "WARN" "rclone not installed"
        doctor_log "FIX" "Install rclone: curl https://rclone.org/install.sh | sudo bash"
    fi

    # Test OneDrive client
    if command -v onedrive >/dev/null 2>&1; then
        doctor_log "OK" "OneDrive client installed"
        available_clients+=("onedrive")

        local onedrive_version=$(onedrive --version 2>/dev/null | head -1 || echo "unknown")
        echo "      Version: $onedrive_version"

        # Test OneDrive configuration
        local onedrive_config_dir="/etc/hedgii/onedrive"
        if [[ -f "$onedrive_config_dir/config" ]]; then
            doctor_log "OK" "OneDrive client configured"

            # Check sync directory
            local sync_dir="$onedrive_config_dir/sync"
            if [[ -d "$sync_dir" ]]; then
                doctor_log "OK" "OneDrive sync directory exists"
            else
                doctor_log "WARN" "OneDrive sync directory missing"
                doctor_log "FIX" "Create directory: sudo mkdir -p $sync_dir"
            fi

            # Test OneDrive connection (dry run)
            doctor_log "INFO" "Testing OneDrive connection..."
            if timeout 30 onedrive --confdir="$onedrive_config_dir" --dry-run --single-directory="hedgii-backups" >/dev/null 2>&1; then
                doctor_log "OK" "OneDrive connection successful"
            else
                doctor_log "WARN" "OneDrive connection failed"
                doctor_log "FIX" "Re-authenticate: sudo onedrive --confdir='$onedrive_config_dir' --auth-files"
                sync_issues=$((sync_issues + 1))
            fi
        else
            doctor_log "WARN" "OneDrive client not configured"
            doctor_log "FIX" "Setup OneDrive: hedgii setup-onedrive"
        fi
    else
        doctor_log "WARN" "OneDrive client not installed"
        doctor_log "FIX" "Install from: https://github.com/abraunegg/onedrive"
    fi

    # Check current sync method
    if [[ -f "/etc/hedgii/hedgii_config.json" ]]; then
        local sync_method=$(jq -r '.settings.sync_method // "auto"' "/etc/hedgii/hedgii_config.json" 2>/dev/null)
        doctor_log "INFO" "Configured sync method: $sync_method"

        if [[ "$sync_method" != "auto" ]]; then
            # Check if chosen method is available
            if [[ ! " ${available_clients[*]} " =~ " $sync_method " ]]; then
                doctor_log "FAIL" "Configured sync method '$sync_method' not available"
                doctor_log "FIX" "Change sync method: hedgii setup-sync"
                sync_issues=$((sync_issues + 1))
            fi
        fi
    fi

    # Summary
    if [[ ${#available_clients[@]} -eq 0 ]]; then
        doctor_log "FAIL" "No sync clients available"
        doctor_log "FIX" "Install at least one: rclone or OneDrive client"
        sync_issues=$((sync_issues + 1))
    else
        doctor_log "INFO" "Available sync clients: ${available_clients[*]}"
    fi

    echo ""
    return $sync_issues
}

# Quick test backup
test_backup() {
    doctor_log "KAWAII" "Testing Backup Functionality..."

    if [[ ! -f "/usr/local/bin/hedgii" ]]; then
        doctor_log "FAIL" "Hedgii not installed"
        return 1
    fi

    # Test configuration validation
    if /usr/local/bin/hedgii validate-config >/dev/null 2>&1; then
        doctor_log "OK" "Configuration validation passed"
    else
        doctor_log "FAIL" "Configuration validation failed"
        doctor_log "FIX" "Check configuration: hedgii validate-config"
        return 1
    fi

    # Test custom commands only
    doctor_log "INFO" "Testing custom commands..."
    if /usr/local/bin/hedgii test-commands >/dev/null 2>&1; then
        doctor_log "OK" "Custom commands test passed"
    else
        doctor_log "WARN" "Custom commands test failed"
        doctor_log "FIX" "Check custom commands configuration"
    fi

    echo ""
}

# Show summary and recommendations
show_summary() {
    local total_issues=$1

    doctor_log "KAWAII" "Health Check Summary"

    if [[ $total_issues -eq 0 ]]; then
        doctor_log "OK" "🎉 Hedgii is healthy and ready to protect your data!"
        echo ""
        echo "✨ Next steps:"
        echo "   • Run a test backup: hedgii curl"
        echo "   • Check logs: tail -f /var/log/hedgii/*.log"
        echo "   • Monitor automatic backups"
    else
        doctor_log "WARN" "Found $total_issues issues that need attention"
        echo ""
        echo "🔧 Please fix the issues above, then run hedgii-doctor again"
    fi

    echo ""
    doctor_log "KAWAII" "Remember: A healthy hedgehog is a happy hedgehog! 🦔💖"
}

# Main function
main() {
    show_welcome
    check_system_info

    # Each check returns its issue count: "|| ..." keeps set -e from stopping at the first issue
    local total_issues=0

    check_hedgii_installation || total_issues=$((total_issues + $?))

    check_dependencies || total_issues=$((total_issues + $?))

    check_repositories

    check_cron_jobs || total_issues=$((total_issues + $?))

    check_disk_space

    test_sync_clients || total_issues=$((total_issues + $?))
    
    test_backup || total_issues=$((total_issues + 1))
    
    show_summary $total_issues
}

# Run the doctor
main "$@"
