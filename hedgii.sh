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
        # Build rsync exclusions from config
        local rsync_opts="-av --progress"
        local exclusions=$(jq -r '.exclusions[]?' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$exclusions" ]]; then
            while IFS= read -r exclusion; do
                if [[ -n "$exclusion" ]]; then
                    rsync_opts="$rsync_opts --exclude=$exclusion"
                fi
            done <<< "$exclusions"
        fi
        
        # Execute rsync with exclusions
        rsync $rsync_opts "$source/" "$dest_full/"
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

# Execute custom commands before backup
execute_custom_commands() {
    local staging_dir="$1"
    local custom_commands=$(jq -r '.custom_commands // []' "$CONFIG_FILE")
    
    if [[ "$custom_commands" == "[]" ]]; then
        hedgii_log "INFO" "No custom commands configured"
        return 0
    fi
    
    local commands_count=$(jq '.custom_commands | length' "$CONFIG_FILE")
    hedgii_log "KAWAII" "🦔 Running $commands_count custom commands to gather special data! ✨"
    
    local success_count=0
    local failed_count=0
    
    for i in $(seq 0 $((commands_count - 1))); do
        local command=$(jq -r ".custom_commands[$i].command" "$CONFIG_FILE")
        local description=$(jq -r ".custom_commands[$i].description" "$CONFIG_FILE")
        local output_file=$(jq -r ".custom_commands[$i].output_file" "$CONFIG_FILE")
        local timeout=$(jq -r ".custom_commands[$i].timeout // 300" "$CONFIG_FILE")
        local working_dir=$(jq -r ".custom_commands[$i].working_dir // \"/tmp\"" "$CONFIG_FILE")
        local continue_on_error=$(jq -r ".custom_commands[$i].continue_on_error // true" "$CONFIG_FILE")
        
        hedgii_log "INFO" "🔧 Executing: $description"
        hedgii_log "INFO" "  Command: $command"
        hedgii_log "INFO" "  Output: $output_file"
        
        # Create output directory in staging
        local output_path="$staging_dir/$(dirname "$output_file")"
        mkdir -p "$output_path"
        
        # Full output file path
        local full_output_path="$staging_dir/$output_file"
        
        # Execute command with timeout
        if execute_command_with_timeout "$command" "$working_dir" "$timeout" "$full_output_path"; then
            hedgii_log "INFO" "  ✓ Command successful"
            ((success_count++))
        else
            hedgii_log "ERROR" "  ✗ Command failed"
            ((failed_count++))
            
            if [[ "$continue_on_error" == "false" ]]; then
                hedgii_log "ERROR" "Stopping execution due to failed command"
                return 1
            fi
        fi
        
        echo "" # Spacing for readability
    done
    
    hedgii_log "INFO" "Custom commands completed: $success_count success, $failed_count failed"
    return 0
}

# Execute a command with timeout and proper error handling
execute_command_with_timeout() {
    local command="$1"
    local working_dir="$2"
    local timeout="$3"
    local output_file="$4"
    
    # Create a temporary script for the command
    local temp_script=$(mktemp)
    cat > "$temp_script" << EOF
#!/bin/bash
cd "$working_dir"
$command
EOF
    chmod +x "$temp_script"
    
    # Execute with timeout
    if timeout "$timeout" bash "$temp_script" > "$output_file" 2>&1; then
        local exit_code=$?
        rm -f "$temp_script"
        
        # Check if output file was created and has content
        if [[ -f "$output_file" && -s "$output_file" ]]; then
            local file_size=$(stat -c%s "$output_file")
            hedgii_log "INFO" "  Output size: $(numfmt --to=iec --suffix=B $file_size)"
            return 0
        else
            hedgii_log "WARN" "  Command succeeded but no output generated"
            return 0
        fi
    else
        local exit_code=$?
        rm -f "$temp_script"
        
        if [[ $exit_code -eq 124 ]]; then
            hedgii_log "ERROR" "  Command timed out after ${timeout}s"
        else
            hedgii_log "ERROR" "  Command failed with exit code $exit_code"
        fi
        
        return 1
    fi
}

# Enhanced process_sources function to include custom commands
process_sources_with_commands() {
    local staging_dir="$1"
    
    hedgii_log "KAWAII" "🦔 Hedgii is gathering all your precious data! (｡◕‿◕｡)"
    
    # Execute custom commands first
    if ! execute_custom_commands "$staging_dir"; then
        hedgii_log "ERROR" "Custom commands failed, aborting backup"
        return 1
    fi
    
    # Then process regular file sources
    local total_sources=$(jq '.backup_sources | length' "$CONFIG_FILE")
    local success_count=0
    
    for i in $(seq 0 $((total_sources - 1))); do
        local source=$(jq -r ".backup_sources[$i].source" "$CONFIG_FILE")
        local destination=$(jq -r ".backup_sources[$i].destination" "$CONFIG_FILE")
        local description=$(jq -r ".backup_sources[$i].description" "$CONFIG_FILE")
        
        if copy_resource "$source" "$destination" "$description" "$staging_dir"; then
            ((success_count++))
        fi
    done
    
    hedgii_log "INFO" "Data collection complete: $success_count/$total_sources file sources successful"
    return 0
}

# Generate a comprehensive backup report
generate_backup_report() {
    local staging_dir="$1"
    local report_file="$staging_dir/hedgii_backup_report.txt"
    
    hedgii_log "INFO" "Generating kawaii backup report..."
    
    cat > "$report_file" << EOF
🦔 ===== HEDGII BACKUP REPORT ===== 🦔
Generated: $(date)
Server: $(hostname)
User: $(whoami)
Hedgii Version: 1.0-kawaii

🎯 BACKUP SUMMARY:
Total files: $(find "$staging_dir" -type f | wc -l)
Total directories: $(find "$staging_dir" -type d | wc -l)
Total size: $(du -sh "$staging_dir" | cut -f1)

📁 BACKUP CONTENTS:
$(find "$staging_dir" -type f -exec ls -lh {} \; | head -20)

🔧 CUSTOM COMMANDS EXECUTED:
$(jq -r '.custom_commands[]? | "- " + .description + " → " + .output_file' "$CONFIG_FILE" 2>/dev/null || echo "No custom commands")

📋 CONFIGURATION USED:
$(cat "$CONFIG_FILE" | jq '.')

🦔 Hedgii says: Your data is safe and sound! ✨
EOF

    hedgii_log "INFO" "Report generated: hedgii_backup_report.txt"
}

# Process all backup sources (legacy function for compatibility)
process_sources() {
    process_sources_with_commands "$1"
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
    hedgii_log "KAWAII" "🦔 Hedgii is ready to protect your data with custom powers! ✨"
    
    check_dependencies
    
    local staging_dir=$(cleanup_staging)
    
    # Use enhanced processing with custom commands
    if ! process_sources_with_commands "$staging_dir"; then
        hedgii_log "ERROR" "Data collection failed!"
        exit 1
    fi
    
    # Generate comprehensive report
    generate_backup_report "$staging_dir"
    
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
    "test-commands")
        hedgii_log "KAWAII" "🦔 Testing custom commands without full backup..."
        check_dependencies
        local staging_dir=$(cleanup_staging)
        execute_custom_commands "$staging_dir"
        hedgii_log "INFO" "Check results in: $staging_dir"
        ;;
    "validate-config")
        hedgii_log "INFO" "🔍 Validating configuration..."
        if jq empty "$CONFIG_FILE" 2>/dev/null; then
            hedgii_log "INFO" "✓ Configuration JSON is valid"
            local custom_count=$(jq '.custom_commands | length' "$CONFIG_FILE")
            local source_count=$(jq '.backup_sources | length' "$CONFIG_FILE")
            hedgii_log "INFO" "📊 Found $custom_count custom commands, $source_count file sources"
        else
            hedgii_log "ERROR" "✗ Configuration JSON is invalid"
            exit 1
        fi
        ;;
    *)
        echo "🦔 Hedgii Commands:"
        echo "  curl           - Backup your data with custom commands (default)"
        echo "  peek           - Check backup status"
        echo "  guard          - View protection status"
        echo "  test-commands  - Test custom commands without full backup"
        echo "  validate-config - Validate configuration file"
        ;;
esac
