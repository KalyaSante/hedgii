#!/bin/bash

# 🦔 Hedgii - Your Kawaii Backup Guardian
# The adorable yet secure backup solution

# Configuration
CONFIG_FILE="/etc/hedgii/hedgii_config.json"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/hedgii/hedgii_$DATE.log"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Colors for kawaii output
PINK='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# Kawaii logging function
hedgii_log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")  echo -e "${GREEN}🦔 [INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        "WARN")  echo -e "${YELLOW}⚠️  [WARN]${NC} $message" | tee -a "$LOG_FILE" ;;
        "ERROR") echo -e "${RED}💥 [ERROR]${NC} $message" | tee -a "$LOG_FILE" ;;
        "KAWAII") echo -e "${PINK}✨ [HEDGII]${NC} $message" | tee -a "$LOG_FILE" ;;
    esac
}

# Check dependencies
check_dependencies() {
    local deps=("jq" "gpg" "rclone" "rsync")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            hedgii_log "ERROR" "Missing dependency: $dep"
            exit 1
        fi
    done
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        hedgii_log "ERROR" "Config file not found: $CONFIG_FILE"
        hedgii_log "INFO" "Copy config/hedgii_config.json.example to $CONFIG_FILE"
        exit 1
    fi
}

# Cleanup staging directory
cleanup_staging() {
    local staging_dir=$(jq -r '.settings.staging_dir // "/tmp/hedgii_staging"' "$CONFIG_FILE")
    
    hedgii_log "INFO" "Cleaning staging directory..."
    
    if [[ -d "$staging_dir" ]]; then
        rm -rf "$staging_dir"
    fi
    
    mkdir -p "$staging_dir"
    echo "$staging_dir"
}

# Copy resource intelligently
copy_resource() {
    local source="$1"
    local dest_relative="$2"
    local description="$3"
    local staging_dir="$4"
    
    local dest_full="$staging_dir/$dest_relative"
    local dest_dir=$(dirname "$dest_full")
    
    hedgii_log "INFO" "Processing: $description"
    hedgii_log "INFO" "  Source: $source → $dest_relative"
    
    if [[ ! -e "$source" ]]; then
        hedgii_log "WARN" "Source not found: $source"
        return 1
    fi
    
    mkdir -p "$dest_dir"
    
    if [[ -d "$source" ]]; then
        rsync -av --exclude="*.tmp" --exclude=".git" "$source/" "$dest_full/"
    else
        cp "$source" "$dest_full"
    fi
    
    if [[ $? -eq 0 ]]; then
        hedgii_log "INFO" "  ✓ Copy successful"
        return 0
    else
        hedgii_log "ERROR" "  ✗ Copy failed"
        return 1
    fi
}

# Process all backup sources
process_sources() {
    local staging_dir="$1"
    local total_sources=$(jq '.backup_sources | length' "$CONFIG_FILE")
    local success_count=0
    
    hedgii_log "KAWAII" "Starting to curl up your precious data! (｡◕‿◕｡)"
    
    for i in $(seq 0 $((total_sources - 1))); do
        local source=$(jq -r ".backup_sources[$i].source" "$CONFIG_FILE")
        local destination=$(jq -r ".backup_sources[$i].destination" "$CONFIG_FILE")
        local description=$(jq -r ".backup_sources[$i].description" "$CONFIG_FILE")
        
        if copy_resource "$source" "$destination" "$description" "$staging_dir"; then
            ((success_count++))
        fi
    done
    
    hedgii_log "INFO" "Data collection complete: $success_count/$total_sources successful"
}

# Encrypt the staging directory
encrypt_staging() {
    local staging_dir="$1"
    local backup_dir=$(jq -r '.settings.backup_dir // "/var/backups/hedgii"' "$CONFIG_FILE")
    local passphrase_file=$(jq -r '.settings.encrypt_passphrase_file' "$CONFIG_FILE")
    local encrypted_file="$backup_dir/hedgii_backup_$DATE.gpg"
    
    mkdir -p "$backup_dir"
    
    hedgii_log "INFO" "Curling up into a protective ball... 🦔"
    
    if tar -czf - -C "$staging_dir" . | gpg --symmetric --cipher-algo AES256 \
        --batch --yes --passphrase-file "$passphrase_file" \
        --output "$encrypted_file"; then
        
        hedgii_log "INFO" "Encryption successful: $encrypted_file"
        echo "$encrypted_file"
        return 0
    else
        hedgii_log "ERROR" "Encryption failed!"
        return 1
    fi
}

# Upload to cloud
upload_to_cloud() {
    local encrypted_file="$1"
    local remote_path=$(jq -r '.settings.rclone_remote' "$CONFIG_FILE")
    
    hedgii_log "INFO" "Uploading to cloud sanctuary..."
    
    if rclone copy "$encrypted_file" "$remote_path"; then
        hedgii_log "INFO" "Upload successful!"
        return 0
    else
        hedgii_log "ERROR" "Upload failed!"
        return 1
    fi
}

# Main backup function
hedgii_curl() {
    hedgii_log "KAWAII" "🦔 Hedgii is ready to protect your data! ✨"
    
    check_dependencies
    
    local staging_dir=$(cleanup_staging)
    process_sources "$staging_dir"
    
    local encrypted_file
    if encrypted_file=$(encrypt_staging "$staging_dir"); then
        if upload_to_cloud "$encrypted_file"; then
            hedgii_log "KAWAII" "🎉 Backup completed successfully! Your data is safe! (≧◡≦)"
            rm -rf "$staging_dir"
        else
            hedgii_log "ERROR" "Upload failed, keeping local backup"
        fi
    else
        hedgii_log "ERROR" "Backup failed!"
        exit 1
    fi
}

# Command handling
case "${1:-curl}" in
    "curl")
        hedgii_curl
        ;;
    "peek")
        hedgii_log "INFO" "Hedgii status: Ready to protect! 🦔"
        ls -la /var/backups/hedgii/ 2>/dev/null || echo "No local backups found"
        ;;
    "guard")
        hedgii_log "INFO" "Hedgii is guarding your data 24/7! 🛡️"
        ;;
    *)
        echo "🦔 Hedgii Commands:"
        echo "  curl  - Backup your data (default)"
        echo "  peek  - Check backup status"
        echo "  guard - View protection status"
        ;;
esac
