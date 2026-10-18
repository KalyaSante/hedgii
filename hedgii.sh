#!/bin/bash

# 🦔 Hedgii - Your Kawaii Backup Guardian
# The adorable yet secure backup solution with multi-sync support

set -euo pipefail
umask 077

STAGING_DIR=""
ENCRYPTED_FILE=""
cleanup_on_exit() {
    if [[ -n "${STAGING_DIR:-}" ]]; then
        rm -rf "$STAGING_DIR" "$STAGING_DIR.lists"
    fi
}
trap cleanup_on_exit EXIT

# Exit codes
EXIT_CONFIG_ERROR=1
EXIT_COLLECT_FAILED=2
EXIT_COMPRESS_FAILED=3
EXIT_UPLOAD_FAILED=4
EXIT_ALREADY_RUNNING=5
EXIT_VERIFY_FAILED=6
EXIT_NO_SPACE=7

# Single source of truth: the version file, next to the script in a checkout,
# or in /usr/local/share/hedgii once installed by install.sh
hedgii_version() {
    local dir f
    dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
    for f in "$dir/version" /usr/local/share/hedgii/version; do
        if [[ -r "$f" ]]; then
            tr -d '[:space:]' < "$f"
            return 0
        fi
    done
    echo "unknown"
}
HEDGII_VERSION=$(hedgii_version)

# Configuration
CONFIG_FILE="${HEDGII_CONFIG_FILE:-/etc/hedgii/hedgii_config.json}"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${HEDGII_LOG_FILE:-/var/log/hedgii/hedgii_$DATE.log}"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Colors for kawaii output
PINK='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

# Kawaii logging function
# Kawaii logging function - ULTRA ROBUST VERSION
hedgii_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Message propre pour le fichier (sans couleurs)
    local clean_message="[$timestamp] 🦔 [$level] $message"

    # Message avec couleurs pour le terminal (seulement si c'est un terminal)
    if [[ -t 1 ]]; then
        case "$level" in
            "INFO")   echo -e "${GREEN}🦔 [INFO]${NC} $message" ;;
            "WARN")   echo -e "${YELLOW}⚠️  [WARN]${NC} $message" ;;
            "ERROR")  echo -e "${RED}💥 [ERROR]${NC} $message" ;;
            "KAWAII") echo -e "${PINK}✨ [HEDGII]${NC} $message" ;;
        esac
    else
        # Pas de couleurs si pas un terminal
        case "$level" in
            "INFO")   echo "🦔 [INFO] $message" ;;
            "WARN")   echo "⚠️  [WARN] $message" ;;
            "ERROR")  echo "💥 [ERROR] $message" ;;
            "KAWAII") echo "✨ [HEDGII] $message" ;;
        esac
    fi

    # Toujours écrire proprement dans le fichier log
    echo "$clean_message" >> "$LOG_FILE"
}

# Check dependencies
check_dependencies() {
    local deps=("jq" "gpg" "rsync")
    # Direct mode decodes rsync's file list with perl (perl-base is essential on Debian)
    if [[ "$(jq -r '.settings.staging_mode // "copy"' "$CONFIG_FILE" 2>/dev/null)" == "direct" ]]; then
        deps+=("perl")
    fi
    local compression_format=$(jq -r '.settings.compression_format // "tar.gz"' "$CONFIG_FILE" 2>/dev/null || echo "tar.gz")

    # Ajouter zip aux dépendances si nécessaire
    if [[ "$compression_format" == "zip" ]]; then
        deps+=("zip")
    fi

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            hedgii_log "ERROR" "Missing dependency: $dep"
            
            # Message d'aide spécifique pour zip sur différents systèmes
            if [[ "$dep" == "zip" ]]; then
                hedgii_log "INFO" "Install zip with:"
                hedgii_log "INFO" "  Debian/Ubuntu: sudo apt install zip"
                hedgii_log "INFO" "  RHEL/CentOS: sudo yum install zip"
                hedgii_log "INFO" "  Arch: sudo pacman -S zip"
            fi
            
            exit $EXIT_CONFIG_ERROR
        fi
    done

    if [[ ! -f "$CONFIG_FILE" ]]; then
        hedgii_log "ERROR" "Config file not found: $CONFIG_FILE"
        hedgii_log "INFO" "Copy config/hedgii_config.json.example to $CONFIG_FILE"
        exit $EXIT_CONFIG_ERROR
    fi
}

# Detect available sync clients
detect_sync_clients() {
    local clients=()

    if command -v rclone >/dev/null 2>&1; then
        clients+=("rclone")
    fi

    if command -v onedrive >/dev/null 2>&1; then
        clients+=("onedrive")
    fi

    echo "${clients[@]}"
}

# Get sync method from config
get_sync_method() {
    local sync_method=$(jq -r '.settings.sync_method // "auto"' "$CONFIG_FILE")

    if [[ "$sync_method" == "auto" ]]; then
        # Auto-detect best available client
        local available_clients=($(detect_sync_clients))

        if [[ ${#available_clients[@]} -eq 0 ]]; then
            hedgii_log "ERROR" "No sync clients found (rclone or onedrive)"
            return 1
        fi

        # Prefer onedrive for OneDrive, rclone for others
        local cloud_provider=$(jq -r '.settings.cloud_provider // "onedrive"' "$CONFIG_FILE")

        if [[ "$cloud_provider" == "onedrive" ]] && [[ " ${available_clients[*]} " =~ " onedrive " ]]; then
            echo "onedrive"
        elif [[ " ${available_clients[*]} " =~ " rclone " ]]; then
            echo "rclone"
        else
            echo "${available_clients[0]}"
        fi
    else
        echo "$sync_method"
    fi
}

# --- rclone helpers (single deterministic config file for every call) ---
RCLONE_DEFAULT_CONFIG="/etc/hedgii/rclone.conf"
RCLONE_LEGACY_CONFIG="/root/.config/rclone/rclone.conf"

# Explicit settings.rclone_config wins. Without it, older installs keep working on
# root's own rclone config until it is migrated to /etc/hedgii/rclone.conf.
get_rclone_config() {
    local cfg
    cfg=$(jq -r '.settings.rclone_config // empty' "$CONFIG_FILE")
    if [[ -n "$cfg" ]]; then
        echo "$cfg"
    elif [[ ! -f "$RCLONE_DEFAULT_CONFIG" && -f "$RCLONE_LEGACY_CONFIG" ]]; then
        echo "$RCLONE_LEGACY_CONFIG"
    else
        echo "$RCLONE_DEFAULT_CONFIG"
    fi
}

get_rclone_timeout() {
    local t
    t=$(jq -r '.settings.rclone_timeout // 60' "$CONFIG_FILE")
    [[ "$t" =~ ^[0-9]+$ ]] || t=60
    echo "$t"
}

get_rclone_remote() {
    jq -r '.settings.rclone_remote // "onedrive:hedgii-backups/"' "$CONFIG_FILE"
}

# Run rclone with the configured config file
hedgii_rclone() {
    rclone --config "$(get_rclone_config)" "$@"
}

# Offer to migrate /root/.config/rclone/rclone.conf to the Hedgii config
migrate_rclone_config() {
    local cfg legacy="$RCLONE_LEGACY_CONFIG"
    cfg=$(jq -r '.settings.rclone_config // empty' "$CONFIG_FILE")
    cfg="${cfg:-$RCLONE_DEFAULT_CONFIG}"
    [[ -f "$cfg" ]] && return 0
    [[ -f "$legacy" ]] || return 0

    hedgii_log "WARN" "rclone config not found at $cfg, but $legacy exists"
    if [[ -t 0 ]]; then
        local answer
        read -r -p "Copy $legacy to $cfg? [Y/n] " answer
        if [[ ! "$answer" =~ ^[Nn] ]]; then
            mkdir -p "$(dirname "$cfg")"
            cp "$legacy" "$cfg"
            chown root:root "$cfg" 2>/dev/null || true
            chmod 600 "$cfg"
            hedgii_log "INFO" "✅ rclone config copied to $cfg"
            return 0
        fi
    else
        hedgii_log "INFO" "Run interactively to migrate: sudo cp $legacy $cfg && sudo chmod 600 $cfg"
    fi
    return 0
}

# Exact remote name match (no substring / regex matching)
rclone_remote_exists() {
    local remote_name="${1%%:*}"
    hedgii_rclone listremotes 2>/dev/null | grep -Fxq "${remote_name}:"
}

# Detect expired tokens in rclone output and print the reconnect command
rclone_explain_failure() {
    local output="$1" remote="$2"
    local remote_name="${remote%%:*}"
    if echo "$output" | grep -Eqi 'invalid_grant|token expired|expired token|401|unauthorized'; then
        hedgii_log "ERROR" "🔑 The OAuth token for '$remote_name' is expired or revoked"
        hedgii_log "INFO" "Reconnect with: rclone config reconnect ${remote_name}: --config $(get_rclone_config)"
        hedgii_log "INFO" "Google Drive: apps left in 'Testing' mode expire every 7 days (see README)"
    fi
}

# Write probe: upload, read back, delete on the configured remote
rclone_write_test() {
    local remote="$1"
    local timeout_s probe_name probe_local probe_remote out rc=0 content
    timeout_s=$(get_rclone_timeout)
    [[ "$remote" == */ || "$remote" == *: ]] || remote="$remote/"
    probe_name=".hedgii-probe-$(date +%Y%m%d_%H%M%S)"
    probe_remote="${remote}${probe_name}"
    probe_local=$(mktemp)
    content="hedgii-probe-$$-$RANDOM"
    echo "$content" > "$probe_local"

    if ! out=$(timeout "$timeout_s" rclone --config "$(get_rclone_config)" copyto "$probe_local" "$probe_remote" 2>&1); then
        hedgii_log "ERROR" "❌ Cannot write to $remote: $out"
        rclone_explain_failure "$out" "$remote"
        rm -f "$probe_local"
        return 1
    fi

    if ! out=$(timeout "$timeout_s" rclone --config "$(get_rclone_config)" cat "$probe_remote" 2>&1) || [[ "$out" != "$content" ]]; then
        hedgii_log "ERROR" "❌ Probe file written but could not be read back from $remote: $out"
        rclone_explain_failure "$out" "$remote"
        rc=1
    fi

    timeout "$timeout_s" rclone --config "$(get_rclone_config)" deletefile "$probe_remote" >/dev/null 2>&1 \
        || hedgii_log "WARN" "Could not delete probe file $probe_remote"
    rm -f "$probe_local"
    return $rc
}

# Test the configured rclone remote (exact name + write access)
test_rclone_remote() {
    local remote cfg
    remote=$(get_rclone_remote)
    cfg=$(get_rclone_config)
    migrate_rclone_config

    if [[ ! -f "$cfg" ]]; then
        hedgii_log "ERROR" "rclone config not found: $cfg"
        hedgii_log "INFO" "Run: sudo hedgii setup-rclone"
        return 1
    fi
    if ! rclone_remote_exists "$remote"; then
        hedgii_log "ERROR" "rclone remote '${remote%%:*}' not found in $cfg"
        hedgii_log "INFO" "Available remotes: $(hedgii_rclone listremotes 2>/dev/null | tr '\n' ' ')"
        hedgii_log "INFO" "Run: sudo hedgii setup-rclone"
        return 1
    fi
    hedgii_log "INFO" "Testing write access on $remote (timeout $(get_rclone_timeout)s)..."
    if rclone_write_test "$remote"; then
        hedgii_log "INFO" "✅ rclone remote $remote is readable and writable"
        return 0
    fi
    return 1
}

# Guided rclone setup (headless friendly)
setup_rclone() {
    local cfg
    cfg=$(get_rclone_config)
    if ! command -v rclone >/dev/null 2>&1; then
        hedgii_log "ERROR" "rclone not installed"
        return 1
    fi
    migrate_rclone_config
    mkdir -p "$(dirname "$cfg")"

    hedgii_log "KAWAII" "🔧 rclone setup (config: $cfg)"
    echo ""
    echo "On a server WITHOUT a browser (headless):"
    echo "  1. In 'rclone config', answer 'n' to \"Use auto config?\""
    echo "  2. On a machine WITH a browser, run:  rclone authorize \"drive\"   (or \"onedrive\")"
    echo "  3. Paste the resulting token back into this terminal"
    echo "Name the remote like settings.rclone_remote (currently: $(get_rclone_remote))"
    echo ""

    rclone config --config "$cfg"
    if [[ -f "$cfg" ]]; then
        chown root:root "$cfg" 2>/dev/null || true
        chmod 600 "$cfg"
    fi
    test_rclone_remote
}

# Setup OneDrive client (abraunegg) - FIXED VERSION
setup_onedrive_client() {
    hedgii_log "KAWAII" "🔄 Setting up OneDrive client (abraunegg)..."

    local onedrive_config_dir="/etc/hedgii/onedrive"
    mkdir -p "$onedrive_config_dir"

    # Check if already configured
    if [[ -f "$onedrive_config_dir/config" ]]; then
        hedgii_log "INFO" "OneDrive client already configured"
        return 0
    fi

    hedgii_log "INFO" "Creating OneDrive configuration..."

    # Get backup directory from config
    local backup_subdir=$(jq -r '.settings.onedrive_backup_dir // "hedgii-backups"' "$CONFIG_FILE")

    cat > "$onedrive_config_dir/config" << EOF
# 🦔 Hedgii OneDrive Configuration - FIXED VERSION
# Compatible with OneDrive Client v2.5+ (abraunegg)
# Generated by Hedgii setup - $(date)

## Local directory to sync with OneDrive
sync_dir = "$onedrive_config_dir/sync"

## Skip file patterns - enhanced for better compatibility
skip_file = "~*|.~*|*.tmp|*.swp|*.partial"

## Log directory
log_dir = "/var/log/hedgii/"

## Only upload changes to OneDrive, do not download from cloud
upload_only = "true"

## Check for nomount
check_nomount = "false"

## Check for nosync
check_nosync = "false"

## Local first sync
local_first = "false"

## Download only mode
download_only = "false"

## Disable GUI notifications
disable_notifications = "true"

## Disable upload validation
disable_upload_validation = "false"

## Enable logging
enable_logging = "true"

## Monitor interval in seconds (default: 300)
monitor_interval = "300"

## Monitor log frequency - controls log message suppression
monitor_log_frequency = "12"

## Monitor fullscan frequency - DOIT RESTER STRING avec guillemets
monitor_fullscan_frequency = "12"

## Sync root files when using sync_list
sync_root_files = "false"

## Skip symbolic links
skip_symlinks = "true"

## Skip dotfiles (.files)
skip_dotfiles = "true"

## Dry run mode
dry_run = "false"

## Classification threshold for "big delete" operations
classify_as_big_delete = "1000"

## TOUTES LES OPTIONS DÉPRÉCIÉES SUPPRIMÉES:
# - min_notify_changes (dépréciée)
# - sync_business_shared_folders (dépréciée) 
# - force_http_2 (dépréciée)
# - single_directory (pas une option config, seulement CLI)
EOF

    # Create sync directory
    mkdir -p "$onedrive_config_dir/sync"

    # Create skip file for exclusions
    cat > "$onedrive_config_dir/skip_file" << 'EOF'
# Skip temporary files
*.tmp
*.temp
*.swp
*.partial
.DS_Store
Thumbs.db
~*
.~*
# Skip common temporary directories
.git/
node_modules/
.cache/
EOF

    chmod 600 "$onedrive_config_dir/config"
    hedgii_log "INFO" "OneDrive configuration created at $onedrive_config_dir"

    hedgii_log "WARN" "⚠️  Manual step required:"
    echo "   Run: sudo onedrive --confdir='$onedrive_config_dir' --auth-files"
    echo "   Then: sudo onedrive --confdir='$onedrive_config_dir' --sync --single-directory='$backup_subdir' --upload-only --dry-run"
    }

# Upload using OneDrive client
upload_with_onedrive() {
    local encrypted_file="$1"
    local onedrive_config_dir="/etc/hedgii/onedrive"
    local sync_dir="$onedrive_config_dir/sync"

    hedgii_log "INFO" "📤 Uploading with OneDrive client..."

    # Check if OneDrive is configured
    if [[ ! -f "$onedrive_config_dir/config" ]]; then
        hedgii_log "ERROR" "OneDrive client not configured"
        return 1
    fi

    # Copy file to sync directory
    local filename=$(basename "$encrypted_file")

    # Get the backup directory from config and create the full path
    local backup_subdir=$(jq -r '.settings.onedrive_backup_dir // "hedgii-backups"' "$CONFIG_FILE")
    local target_dir="$sync_dir/$backup_subdir"

    # Create target directory if it doesn't exist
    if ! mkdir -p "$target_dir"; then
        hedgii_log "ERROR" "Failed to create target directory: $target_dir"
        return 1
    fi

    local sync_file="$target_dir/$filename"
    # Always remove the sync-folder copy, whatever the outcome
    trap 'rm -f "$sync_file"; trap - RETURN' RETURN

    if cp "$encrypted_file" "$sync_file"; then
        hedgii_log "INFO" "File copied to sync directory: $sync_file"
    else
        hedgii_log "ERROR" "Failed to copy file to sync directory"
        return 1
    fi

    # Perform sync with retry
    local max_attempts=3
    for attempt in $(seq 1 $max_attempts); do
        hedgii_log "INFO" "Sync attempt $attempt/$max_attempts..."

        if timeout 300 onedrive --confdir="$onedrive_config_dir" \
            --sync --single-directory="$(jq -r '.settings.onedrive_backup_dir // "hedgii-backups"' "$CONFIG_FILE")" \
            --upload-only --no-remote-delete; then

            hedgii_log "INFO" "✅ OneDrive sync completed successfully"

            # Clean up local sync file
            rm -f "$sync_file"
            return 0
        else
            hedgii_log "WARN" "Sync attempt $attempt failed"

            if [[ $attempt -lt $max_attempts ]]; then
                hedgii_log "INFO" "Retrying in 30 seconds..."
                sleep 30
            fi
        fi
    done

    hedgii_log "ERROR" "OneDrive sync failed after $max_attempts attempts"
    return 1
}

# Upload using rclone
upload_with_rclone() {
    local encrypted_file="$1"
    local rclone_remote=$(get_rclone_remote)

    hedgii_log "INFO" "📤 Uploading with rclone..."
    if [[ "$(get_rclone_config)" == "$RCLONE_LEGACY_CONFIG" ]]; then
        hedgii_log "WARN" "Using legacy rclone config $RCLONE_LEGACY_CONFIG; migrate with: sudo hedgii setup-rclone"
    fi

    # Check if rclone remote is configured (exact match)
    if ! rclone_remote_exists "$rclone_remote"; then
        hedgii_log "ERROR" "rclone remote not configured: $rclone_remote (config: $(get_rclone_config))"
        return 1
    fi

    # Upload with retry
    local max_attempts=3
    for attempt in $(seq 1 $max_attempts); do
        hedgii_log "INFO" "Upload attempt $attempt/$max_attempts..."

        local out
        if out=$(hedgii_rclone copy "$encrypted_file" "$rclone_remote" --transfers=1 2>&1); then
            hedgii_log "INFO" "✅ rclone upload completed successfully"

            # Verify upload
            local filename=$(basename "$encrypted_file")
            if hedgii_rclone ls "${rclone_remote%/}/$filename" >/dev/null 2>&1; then
                hedgii_log "INFO" "Upload verified on remote"
                return 0
            else
                hedgii_log "WARN" "Upload verification failed"
            fi
        else
            hedgii_log "WARN" "Upload attempt $attempt failed: $out"
            rclone_explain_failure "$out" "$rclone_remote"
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            hedgii_log "INFO" "Retrying in 30 seconds..."
            sleep 30
        fi
    done

    hedgii_log "ERROR" "rclone upload failed after $max_attempts attempts"
    return 1
}

# Smart upload function that chooses the best method
smart_upload_to_cloud() {
    local encrypted_file="$1"
    local sync_method
    if ! sync_method=$(get_sync_method); then
        hedgii_log "ERROR" "Could not determine sync method: ${sync_method:-see previous error}"
        return 1
    fi

    hedgii_log "KAWAII" "🌥️ Using sync method: $sync_method"

    case "$sync_method" in
        "onedrive")
            if command -v onedrive >/dev/null 2>&1; then
                upload_with_onedrive "$encrypted_file"
            else
                hedgii_log "ERROR" "OneDrive client not installed"
                return 1
            fi
            ;;
        "rclone")
            if command -v rclone >/dev/null 2>&1; then
                upload_with_rclone "$encrypted_file"
            else
                hedgii_log "ERROR" "rclone not installed"
                return 1
            fi
            ;;
        *)
            hedgii_log "ERROR" "Unknown sync method: $sync_method"
            return 1
            ;;
    esac
}

# Test sync clients
test_sync_clients() {
    hedgii_log "KAWAII" "🧪 Testing sync clients..."

    local available_clients=($(detect_sync_clients))

    if [[ ${#available_clients[@]} -eq 0 ]]; then
        hedgii_log "ERROR" "No sync clients available"
        return 1
    fi

    hedgii_log "INFO" "Available sync clients: ${available_clients[*]}"

    local rclone_failed=0
    # Test each available client
    for client in "${available_clients[@]}"; do
        case "$client" in
            "rclone")
                hedgii_log "INFO" "Testing rclone..."
                if rclone version >/dev/null 2>&1; then
                    if ! test_rclone_remote; then
                        rclone_failed=1
                    fi
                else
                    hedgii_log "WARN" "⚠️ rclone has issues"
                    rclone_failed=1
                fi
                ;;
            "onedrive")
                hedgii_log "INFO" "Testing OneDrive client..."
                if onedrive --version >/dev/null 2>&1; then
                    hedgii_log "INFO" "✅ OneDrive client working"

                    local config_dir="/etc/hedgii/onedrive"
                    if [[ -f "$config_dir/config" ]]; then
                        hedgii_log "INFO" "✅ OneDrive configured"
                    else
                        hedgii_log "WARN" "⚠️ OneDrive not configured"
                    fi
                else
                    hedgii_log "WARN" "⚠️ OneDrive client has issues"
                fi
                ;;
        esac
    done

    return $rclone_failed
}

# Exclusive lock: only one hedgii run at a time (exit code 5 if already running)
HEDGII_LOCK_FILE="${HEDGII_LOCK_FILE:-/var/lock/hedgii.lock}"
acquire_lock() {
    if ! command -v flock >/dev/null 2>&1; then
        hedgii_log "ERROR" "flock not found (util-linux), cannot guarantee a single run"
        exit $EXIT_CONFIG_ERROR
    fi
    if ! exec 9>"$HEDGII_LOCK_FILE"; then
        hedgii_log "ERROR" "Cannot open lock file $HEDGII_LOCK_FILE"
        exit $EXIT_CONFIG_ERROR
    fi
    if ! flock -n 9; then
        hedgii_log "ERROR" "Another Hedgii run is already in progress (lock: $HEDGII_LOCK_FILE)"
        exit $EXIT_ALREADY_RUNNING
    fi
}

# Create a private (0700) staging directory unique to this run (never shared between runs)
cleanup_staging() {
    local staging_base=$(jq -r '.settings.staging_dir // "/tmp/hedgii_staging"' "$CONFIG_FILE")

    local staging_dir
    mkdir -p "$(dirname "$staging_base")"
    staging_dir=$(mktemp -d "${staging_base%/}.XXXXXX") || return 1
    chmod 700 "$staging_dir"
    hedgii_log "INFO" "Created clean staging directory: $staging_dir" >&2

    echo "$staging_dir"
}

# List effective exclusions (global + per-source when an index is given)
get_effective_exclusions() {
    local source_index="${1:-}"
    jq -r '(.exclusions // [])[]' "$CONFIG_FILE"
    if [[ -n "$source_index" ]]; then
        jq -r ".backup_sources[$source_index].exclude // [] | .[]" "$CONFIG_FILE"
    fi
}

# rsync --exclude arguments for a source (global + per-source), into the RSYNC_EXCLUDES array
build_rsync_excludes() {
    RSYNC_EXCLUDES=()
    local pattern
    while IFS= read -r pattern; do
        [[ -n "$pattern" ]] && RSYNC_EXCLUDES+=("--exclude=$pattern")
    done < <(get_effective_exclusions "${1:-}")
    return 0
}

# Dry run of a directory source with its exclusions: prints the total size in bytes.
# With $3, also writes the itemized list ("%i|%n" lines) there. -8 keeps non-ASCII bytes as
# they are; control characters (newline...) are still written as \#ooo, decoded by the caller.
source_dry_run() {
    local source="$1" index="$2" list_file="${3:-/dev/null}" empty out
    build_rsync_excludes "$index"
    empty=$(mktemp -d)
    if ! out=$(LC_ALL=C rsync -a -8 --dry-run --stats --out-format='%i|%n' \
        ${RSYNC_EXCLUDES[@]+"${RSYNC_EXCLUDES[@]}"} "$source/" "$empty/" 2>>"$LOG_FILE"); then
        rmdir "$empty"
        return 1
    fi
    rmdir "$empty"
    grep -E '^.{11}\|' <<<"$out" > "$list_file" || true
    sed -n 's/^Total file size: \([0-9,.]*\) bytes.*/\1/p' <<<"$out" | tr -d ',.'
}

get_staging_mode() {
    local mode
    mode=$(jq -r '.settings.staging_mode // "copy"' "$CONFIG_FILE")
    case "$mode" in
        copy|direct) echo "$mode" ;;
        *) hedgii_log "WARN" "Unknown staging_mode '$mode', using copy" >&2; echo "copy" ;;
    esac
}

human_size() {
    numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

# Fails if <dir> has less than <bytes> x settings.min_free_space_ratio available
require_free_space() {
    local label="$1" dir="$2" bytes="$3" ratio need avail
    ratio=$(jq -r '.settings.min_free_space_ratio // 1.2' "$CONFIG_FILE")
    need=$(awk -v b="$bytes" -v r="$ratio" 'BEGIN { printf "%.0f", b * r }')
    avail=$(df -P -B1 "$dir" | awk 'NR == 2 { print $4 }')
    # Compared in awk (floating point): a large ratio can push "need" past bash's 64-bit integers,
    # where [[ -lt ]] silently wraps around
    if awk -v a="$avail" -v n="$need" 'BEGIN { exit !(a < n) }'; then
        hedgii_log "ERROR" "Not enough free space for $label in $dir: need $(human_size "$need") ($(human_size "$bytes") x $ratio), available $(human_size "$avail")"
        return 1
    fi
    hedgii_log "INFO" "Free space for $label in $dir: $(human_size "$avail") available, $(human_size "$need") needed"
}

# Before collecting anything: estimate the size of the sources (after exclusions) and check that
# staging (copy mode) and backup_dir can hold it. Custom command outputs can't be known in
# advance: they are covered by the second check in check_space_before_archive.
preflight_free_space() {
    local staging_dir="$1" ratio
    ratio=$(jq -r '.settings.min_free_space_ratio // 1.2' "$CONFIG_FILE")
    if awk -v r="$ratio" 'BEGIN { exit !(r <= 0) }'; then
        return 0
    fi

    local total=0 count i source bytes
    count=$(jq '.backup_sources | length' "$CONFIG_FILE")
    for ((i = 0; i < count; i++)); do
        source=$(jq -r ".backup_sources[$i].source" "$CONFIG_FILE")
        if [[ -d "$source" ]]; then
            bytes=$(source_dry_run "$source" "$i") || bytes=0
        elif [[ -f "$source" ]]; then
            bytes=$(stat -c %s "$source")
        else
            bytes=0
        fi
        total=$((total + ${bytes:-0}))
    done
    hedgii_log "INFO" "📏 Estimated size of the sources: $(human_size "$total")"

    local backup_dir
    backup_dir=$(get_backup_dir)
    mkdir -p "$backup_dir"
    # The archive is assumed incompressible (worst case)
    if [[ "$(get_staging_mode)" == "copy" ]]; then
        if [[ "$(stat -c %d "$staging_dir")" == "$(stat -c %d "$backup_dir")" ]]; then
            require_free_space "staging copy + archive" "$backup_dir" $((total * 2))
        else
            require_free_space "staging copy" "$staging_dir" "$total" \
                && require_free_space "archive" "$backup_dir" "$total"
        fi
    else
        require_free_space "archive" "$backup_dir" "$total"
    fi
}

# Second check once everything is collected, with the real staging size
check_space_before_archive() {
    local staging_dir="$1" ratio staged
    ratio=$(jq -r '.settings.min_free_space_ratio // 1.2' "$CONFIG_FILE")
    if awk -v r="$ratio" 'BEGIN { exit !(r <= 0) }'; then
        return 0
    fi
    staged=$(du -sb "$staging_dir" | cut -f1)
    require_free_space "archive" "$(get_backup_dir)" $((staged + DIRECT_BYTES))
}

# staging_mode "direct": the source is not copied. A symlink in staging points to it and the
# rsync-filtered file list is kept in <staging>.lists/, so the archive reads files in place with
# the same exclusions as a copy.
DIRECT_BYTES=0
DIRECT_FILES=0
stage_direct_source() {
    local source="$1" dest_relative="$2" staging_dir="$3" source_index="$4"
    local lists_dir="$staging_dir.lists" items bytes
    mkdir -p "$lists_dir"
    items=$(mktemp "$lists_dir/items.XXXXXX")
    if ! bytes=$(source_dry_run "$source" "$source_index" "$items"); then
        return 1
    fi
    ln -s "$(realpath "$source")" "$staging_dir/$dest_relative"

    # NUL-separated list of "./<dest>/<name>": decodes rsync's \#ooo escapes, skips sockets,
    # FIFOs and devices (tar can't archive them usefully), and counts regular files for the report.
    # zip -@ reads one name per line: with zip, names containing a newline can't be archived.
    local drop_newlines=0 counts files dropped
    [[ "$(jq -r '.settings.compression_format // "tar.gz"' "$CONFIG_FILE")" == "zip" ]] && drop_newlines=1
    counts=$(perl -e '
        my ($dest, $drop_nl, $out) = @ARGV;
        open(my $fh, ">", $out) or die "$out: $!";
        my ($files, $dropped) = (0, 0);
        while (my $line = <STDIN>) {
            chomp $line;
            my ($item, $name) = split /\|/, $line, 2;
            next unless defined $name && $name ne "./";
            my $type = substr($item, 1, 1);
            next if $type eq "S" || $type eq "D";
            $name =~ s/\\#([0-7]{3})/chr(oct($1))/ge;
            if ($drop_nl && $name =~ /\n/) { $dropped++; next; }
            $files++ if $type eq "f";
            print $fh "./$dest/$name\0";
        }
        print "$files $dropped\n";
    ' "$dest_relative" "$drop_newlines" "$lists_dir/$source_index.list" < "$items") || return 1
    read -r files dropped <<<"$counts"
    if [[ "$dropped" -gt 0 ]]; then
        hedgii_log "ERROR" "  $dropped file name(s) with a newline skipped in $source: ZIP can't store them in direct mode, use tar.gz or copy mode"
    fi
    DIRECT_FILES=$((DIRECT_FILES + files))
    DIRECT_BYTES=$((DIRECT_BYTES + ${bytes:-0}))
    rm -f "$items"
}

# Copy resource intelligently
copy_resource() {
    local source="$1"
    local dest_relative="$2"
    local description="$3"
    local staging_dir="$4"
    local source_index="${5:-}"

    local dest_full="$staging_dir/$dest_relative"
    local dest_dir=$(dirname "$dest_full")

    hedgii_log "INFO" "Processing: $description"
    hedgii_log "INFO" "  Source: $source → $dest_relative"

    if [[ ! -e "$source" ]]; then
        hedgii_log "WARN" "Source not found: $source"
        return 1
    fi

    mkdir -p "$dest_dir"

    if [[ -d "$source" && "$(get_staging_mode)" == "direct" ]]; then
        stage_direct_source "$source" "$dest_relative" "$staging_dir" "$source_index"
    elif [[ -d "$source" ]]; then
        build_rsync_excludes "$source_index"
        rsync -av ${RSYNC_EXCLUDES[@]+"${RSYNC_EXCLUDES[@]}"} "$source/" "$dest_full/"
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

# Execute command with timeout and proper error handling
execute_command_with_timeout() {
    local command="$1"
    local working_dir="$2"
    local timeout="$3"
    local output_file="$4"
    local require_output="${5:-false}"
    local stderr_file="${6:-}"

    # Create a temporary script for the command
    local temp_script=$(mktemp)
    local temp_stderr=$(mktemp)
    cat > "$temp_script" << EOF
#!/bin/bash
cd "$working_dir"
$command
EOF
    chmod +x "$temp_script"

    # Execute with timeout: stdout goes to output file, stderr is captured separately
    # "|| exit_code=$?" keeps set -e from aborting if this is ever called outside an if
    local exit_code=0
    timeout "$timeout" bash "$temp_script" > "$output_file" 2> "$temp_stderr" || exit_code=$?
    rm -f "$temp_script"

    if [[ -s "$temp_stderr" ]]; then
        if [[ $exit_code -eq 0 ]]; then
            hedgii_log "WARN" "  Command wrote to stderr (last 20 lines):"
        else
            hedgii_log "ERROR" "  Command stderr (last 20 lines):"
        fi
        while IFS= read -r line; do
            hedgii_log "INFO" "    $line"
        done < <(tail -n 20 "$temp_stderr")
    fi

    if [[ -n "$stderr_file" ]]; then
        mkdir -p "$(dirname "$stderr_file")"
        cp "$temp_stderr" "$stderr_file"
    fi
    rm -f "$temp_stderr"

    if [[ $exit_code -eq 0 ]]; then
        if [[ -f "$output_file" && -s "$output_file" ]]; then
            local file_size=$(stat -c%s "$output_file")
            hedgii_log "INFO" "  Output size: $(numfmt --to=iec --suffix=B $file_size)"
            return 0
        elif [[ "$require_output" == "true" ]]; then
            hedgii_log "ERROR" "  Command succeeded but produced empty output (require_output is enabled)"
            return 1
        else
            hedgii_log "WARN" "  Command succeeded but no output generated"
            return 0
        fi
    else
        if [[ $exit_code -eq 124 ]]; then
            hedgii_log "ERROR" "  Command timed out after ${timeout}s"
        else
            hedgii_log "ERROR" "  Command failed with exit code $exit_code"
        fi

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
        # Not "// true": jq's // treats an explicit false as missing
        local continue_on_error=$(jq -r ".custom_commands[$i] | if has(\"continue_on_error\") then .continue_on_error else true end" "$CONFIG_FILE")

        local default_require="false"
        case "$output_file" in
            *.sql|*.dump|*.archive) default_require="true" ;;
        esac
        local require_output=$(jq -r --arg d "$default_require" ".custom_commands[$i] | if has(\"require_output\") then .require_output else \$d end" "$CONFIG_FILE")
        local stderr_file=$(jq -r ".custom_commands[$i].stderr_file // empty" "$CONFIG_FILE")
        [[ -n "$stderr_file" ]] && stderr_file="$staging_dir/$stderr_file"

        hedgii_log "INFO" "🔧 Executing: $description"
        hedgii_log "INFO" "  Command: $command"
        hedgii_log "INFO" "  Output: $output_file"

        # Create output directory in staging
        local output_path="$staging_dir/$(dirname "$output_file")"
        mkdir -p "$output_path"

        # Full output file path
        local full_output_path="$staging_dir/$output_file"

        # Execute command with timeout
        if execute_command_with_timeout "$command" "$working_dir" "$timeout" "$full_output_path" "$require_output" "$stderr_file"; then
            hedgii_log "INFO" "  ✓ Command successful"
            success_count=$((success_count + 1))
        else
            hedgii_log "ERROR" "  ✗ Command failed"
            failed_count=$((failed_count + 1))

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

        if copy_resource "$source" "$destination" "$description" "$staging_dir" "$i"; then
            success_count=$((success_count + 1))
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
Hedgii Version: $HEDGII_VERSION

🎯 BACKUP SUMMARY:
Staging mode: $(get_staging_mode)
Total files: $(( $(find "$staging_dir" -type f | wc -l) + DIRECT_FILES ))
Total directories: $(find "$staging_dir" -type d | wc -l)
Total size: $(human_size $(( $(du -sb "$staging_dir" | cut -f1) + DIRECT_BYTES )))

📁 BACKUP CONTENTS:
$(find "$staging_dir" -type f -exec ls -lh {} \; | head -20)

🔧 CUSTOM COMMANDS EXECUTED:
$(jq -r '.custom_commands[]? | "- " + .description + " → " + .output_file' "$CONFIG_FILE" 2>/dev/null || echo "No custom commands")

🔄 SYNC METHOD:
$(get_sync_method)

📋 CONFIGURATION USED:
$(cat "$CONFIG_FILE" | jq '.')

🦔 Hedgii says: Your data is safe and sound! ✨
EOF

    hedgii_log "INFO" "Report generated: hedgii_backup_report.txt"
}

# Encrypt the staging directory with format choice - CORRECTED VERSION
encrypt_staging() {
    local staging_dir="$1"
    local backup_dir=$(jq -r '.settings.backup_dir // "/var/backups/hedgii"' "$CONFIG_FILE")
    local passphrase_file=$(jq -r '.settings.encrypt_passphrase_file' "$CONFIG_FILE")
    local compression_format=$(jq -r '.settings.compression_format // "tar.gz"' "$CONFIG_FILE")

    mkdir -p "$backup_dir"

    local archive_extension
    case "$compression_format" in
        "zip") archive_extension="zip" ;;
        *) archive_extension="tar.gz" ;;
    esac

    ENCRYPTED_FILE=""
    local encrypted_file="$backup_dir/hedgii_backup_${DATE}.${archive_extension}.gpg"

    hedgii_log "INFO" "Curling up into a protective ball... 🦔" >&2
    hedgii_log "INFO" "Output file: $(basename "$encrypted_file")" >&2

    # Direct mode: archive an explicit file list (staging content without the source symlinks,
    # plus the filtered lists of the sources) instead of recursing into staging
    local file_list=""
    if [[ -d "$staging_dir.lists" ]]; then
        file_list="$staging_dir.lists/archive.files"   # not *.list: read by the glob below
        # NUL-separated, "./" prefix: same member names as the recursive tar of copy mode
        { (cd "$staging_dir" && find . -mindepth 1 ! -type l -print0)
          cat "$staging_dir.lists/"*.list; } > "$file_list"
    fi

    local archiver
    local -a status=()
    # PIPESTATUS tells which side failed. The { } || true keeps set -e from exiting before it is read.
    if [[ "$archive_extension" == "zip" ]]; then
        archiver="zip"
        hedgii_log "INFO" "🦔 Creating ZIP archive for Windows compatibility..." >&2
        { if [[ -n "$file_list" ]]; then
            (cd "$staging_dir" && tr '\0' '\n' < "$file_list" | zip -q - -@ 2>>"$LOG_FILE")
          else
            (cd "$staging_dir" && zip -q -r - . 2>>"$LOG_FILE")
          fi | gpg --symmetric --cipher-algo AES256 --batch --yes \
                --passphrase-file "$passphrase_file" \
                --output "$encrypted_file" 2>>"$LOG_FILE"
          status=("${PIPESTATUS[@]}"); } || true
    else
        archiver="tar"
        hedgii_log "INFO" "🦔 Creating TAR.GZ archive..." >&2
        { if [[ -n "$file_list" ]]; then
            tar -czf - -C "$staging_dir" --no-recursion --null --verbatim-files-from -T "$file_list" 2>>"$LOG_FILE"
          else
            tar -czf - -C "$staging_dir" . 2>>"$LOG_FILE"
          fi | gpg --symmetric --cipher-algo AES256 --batch --yes \
                --passphrase-file "$passphrase_file" \
                --output "$encrypted_file" 2>>"$LOG_FILE"
          status=("${PIPESTATUS[@]}"); } || true
    fi

    local archive_rc="${status[0]:-1}" gpg_rc="${status[1]:-1}"
    # tar exits 1 when a file changed while it was read (live data in direct mode): the archive
    # is complete and valid, the file is just not a consistent snapshot
    if [[ "$archiver" == "tar" && "$archive_rc" -eq 1 ]]; then
        hedgii_log "WARN" "Some files changed while they were archived (tar exit code 1), see log" >&2
        archive_rc=0
    fi
    # gpg first: when gpg dies, the archiver fails too on the broken pipe. The reverse doesn't
    # happen (gpg just sees the end of a truncated stream), so a failed archiver means its own error.
    if [[ "$gpg_rc" -ne 0 ]]; then
        hedgii_log "ERROR" "Encryption failed (gpg exit code $gpg_rc), see log for details" >&2
        rm -f "$encrypted_file"
        return 1
    fi
    if [[ "$archive_rc" -ne 0 ]]; then
        hedgii_log "ERROR" "Archive creation failed ($archiver exit code $archive_rc), see log for details" >&2
        rm -f "$encrypted_file"
        return 1
    fi

    # Full decryption to /dev/null: checks the MDC over the whole file and proves the passphrase works
    # (--list-packets alone needs the passphrase for symmetric files and fails in batch mode)
    if [[ ! -s "$encrypted_file" ]] || ! gpg --batch --quiet --passphrase-file "$passphrase_file" \
        --decrypt "$encrypted_file" >/dev/null 2>>"$LOG_FILE"; then
        hedgii_log "ERROR" "Encrypted file is missing, empty or not a valid GPG file" >&2
        rm -f "$encrypted_file"
        return 1
    fi

    hedgii_log "INFO" "Encryption successful: $encrypted_file" >&2
    ENCRYPTED_FILE="$encrypted_file"
    return 0
}

# ---- Retention / pruning ----
UPLOADED_SUFFIX=".uploaded"

get_backup_dir() {
    jq -r '.settings.backup_dir // "/var/backups/hedgii"' "$CONFIG_FILE"
}

get_retention() {
    # $1 = key, $2 = default
    jq -r --arg k "$1" --arg d "$2" '.retention[$k] // ($d | tonumber)' "$CONFIG_FILE"
}

mark_uploaded() {
    touch "$1$UPLOADED_SUFFIX"
}

# List archives in backup_dir, newest first
list_archives() {
    local backup_dir="$1"
    [[ -d "$backup_dir" ]] || return 0
    find "$backup_dir" -maxdepth 1 -type f -name 'hedgii_backup_*.gpg' -printf '%T@ %p\n' \
        | sort -rn | cut -d' ' -f2-
}

# Warn about archives that were never successfully uploaded
warn_unsent_archives() {
    local backup_dir="$1" f
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ ! -f "$f$UPLOADED_SUFFIX" ]]; then
            hedgii_log "WARN" "Archive never uploaded (kept): $f"
        fi
    done < <(list_archives "$backup_dir")
}

# Mark unmarked local archives that already exist on the rclone remote (archives made before
# markers existed, or whose post-upload check failed). Not possible with the OneDrive client.
reconcile_uploaded_markers() {
    local backup_dir="$1" f remote_list
    [[ "$(get_sync_method 2>/dev/null)" == "rclone" ]] || return 0
    local -a unmarked=()
    while IFS= read -r f; do
        [[ -n "$f" && ! -f "$f$UPLOADED_SUFFIX" ]] && unmarked+=("$f")
    done < <(list_archives "$backup_dir")
    [[ ${#unmarked[@]} -gt 0 ]] || return 0

    remote_list=$(hedgii_rclone lsf "$(get_rclone_remote)" --files-only --include 'hedgii_backup_*' 2>/dev/null) || return 0
    for f in "${unmarked[@]}"; do
        if grep -Fxq "$(basename "$f")" <<<"$remote_list"; then
            mark_uploaded "$f"
            hedgii_log "INFO" "Found on remote, marked as uploaded: $(basename "$f")"
        fi
    done
}

# Apply local retention policy. $1 = "dry-run" to only list.
prune_local() {
    local mode="${1:-}"
    local backup_dir keep_last keep_days
    backup_dir=$(get_backup_dir)
    [[ "$mode" == "dry-run" ]] || reconcile_uploaded_markers "$backup_dir"
    keep_last=$(get_retention local_keep_last 3)
    keep_days=$(get_retention local_keep_days 7)

    local count=0 removed=0 f now age_days
    now=$(date +%s)
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        # Never delete archives that were not verified as uploaded
        [[ -f "$f$UPLOADED_SUFFIX" ]] || continue
        count=$((count + 1))
        [[ $count -le $keep_last ]] && continue
        age_days=$(( (now - $(stat -c %Y "$f")) / 86400 ))
        [[ $age_days -lt $keep_days ]] && continue
        if [[ "$mode" == "dry-run" ]]; then
            hedgii_log "INFO" "[dry-run] Would delete: $f"
        else
            rm -f "$f" "$f$UPLOADED_SUFFIX"
            hedgii_log "INFO" "Deleted old local backup: $f"
        fi
        removed=$((removed + 1))
    done < <(list_archives "$backup_dir")

    hedgii_log "INFO" "Local retention (keep_last=$keep_last, keep_days=$keep_days): $removed archive(s) $([[ "$mode" == "dry-run" ]] && echo "would be " )deleted"
    warn_unsent_archives "$backup_dir"
}

# Apply optional remote retention. $1 = "dry-run" to only simulate.
prune_remote() {
    local mode="${1:-}"
    local days
    days=$(get_retention remote_keep_days 0)
    [[ "$days" -gt 0 ]] 2>/dev/null || return 0

    case "$(get_sync_method)" in
        "rclone")
            local remote
            remote=$(jq -r '.settings.rclone_remote // "onedrive:hedgii-backups/"' "$CONFIG_FILE")
            local args=(--min-age "${days}d" --include 'hedgii_backup_*')
            [[ "$mode" == "dry-run" ]] && args+=(--dry-run)
            hedgii_log "INFO" "Remote retention: deleting backups older than ${days} days on $remote"
            hedgii_rclone delete "$remote" "${args[@]}" || hedgii_log "WARN" "Remote retention failed"
            ;;
        *)
            hedgii_log "WARN" "remote_keep_days is not supported with the OneDrive client; ignoring"
            ;;
    esac
}

hedgii_prune() {
    local mode=""
    case "${1:-}" in
        "") ;;
        "--dry-run") mode="dry-run" ;;
        *) hedgii_log "ERROR" "Usage: hedgii prune [--dry-run]"; exit 1 ;;
    esac
    prune_local "$mode"
    prune_remote "$mode"
}

hedgii_peek() {
    local backup_dir count=0 sent=0 f
    backup_dir=$(get_backup_dir)
    hedgii_log "INFO" "Hedgii status: Ready to protect! 🦔"
    if [[ ! -d "$backup_dir" ]]; then
        echo "No local backups found"
        return 0
    fi
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        count=$((count + 1))
        [[ -f "$f$UPLOADED_SUFFIX" ]] && sent=$((sent + 1))
    done < <(list_archives "$backup_dir")
    hedgii_log "INFO" "📦 $count archive(s) in $backup_dir ($sent uploaded, $((count - sent)) not uploaded), using $(du -sh "$backup_dir" | cut -f1)"
    ls -la "$backup_dir" 2>/dev/null || true
    warn_unsent_archives "$backup_dir"
}

# ---------------------------------------------------------------------------
# Notifications (Discord, Telegram, ping URL / dead man's switch)
# Failures here are logged as WARN and never fail the backup.
# ---------------------------------------------------------------------------

notif_cfg() {
    jq -r "$1 // empty" "$CONFIG_FILE" 2>/dev/null || true
}

# Read a secret from a file (must not be group/world accessible)
notif_read_secret() {
    local file="$1"
    [[ -n "$file" && -r "$file" ]] || return 1
    local perms
    perms=$(stat -c '%a' "$file" 2>/dev/null || echo "")
    if [[ -n "$perms" && "${perms: -2}" != "00" ]]; then
        hedgii_log "WARN" "Secret file $file has permissions $perms (expected 600)"
    fi
    tr -d '\r\n' < "$file"
}

# Should we notify for this level (failure|warning|success)?
notif_enabled_for() {
    local level="$1"
    jq -e --arg l "$level" '(.notifications.on // ["failure","warning"]) | index($l) != null' \
        "$CONFIG_FILE" >/dev/null 2>&1
}

notif_http_post() {
    # $1=url, rest = curl args
    local url="$1"; shift
    curl -fsS -m 20 --retry 2 -o /dev/null "$@" "$url" 2>/dev/null
}

# Public: ping_url [start|fail|success]
notif_ping() {
    local kind="$1" url
    url=$(notif_cfg '.notifications.ping_url')
    [[ -n "$url" ]] || return 0
    command -v curl >/dev/null 2>&1 || return 0
    url="${url%/}"
    case "$kind" in
        start) url="$url/start" ;;
        fail)  url="$url/fail" ;;
    esac
    if ! notif_http_post "$url"; then
        hedgii_log "WARN" "Ping ($kind) failed"
    fi
    return 0
}

# Public: notify_message <message>  -> sends to Discord and Telegram
# Returns number of channels that failed (0 = all good / none configured)
notif_send() {
    local message="$1" failed=0
    command -v curl >/dev/null 2>&1 || { hedgii_log "WARN" "curl missing, notifications disabled"; return 0; }

    local webhook
    webhook=$(notif_cfg '.notifications.discord_webhook_file')
    if [[ -n "$webhook" ]]; then
        webhook=$(notif_read_secret "$webhook" || true)
    else
        webhook=$(notif_cfg '.notifications.discord_webhook')
    fi
    if [[ -n "$webhook" ]]; then
        local payload
        payload=$(jq -n --arg c "${message:0:1900}" '{content: $c}')
        if notif_http_post "$webhook" -H 'Content-Type: application/json' -d "$payload"; then
            NOTIF_SENT+=("discord")
        else
            hedgii_log "WARN" "Discord notification failed"; failed=$((failed+1))
        fi
    fi

    local tg_file tg_chat
    tg_file=$(notif_cfg '.notifications.telegram.bot_token_file')
    tg_chat=$(notif_cfg '.notifications.telegram.chat_id')
    if [[ -n "$tg_file" && -n "$tg_chat" ]]; then
        local token
        token=$(notif_read_secret "$tg_file" || true)
        if [[ -z "$token" ]]; then
            hedgii_log "WARN" "Telegram token file unreadable or empty: $tg_file"; failed=$((failed+1))
        else
            # Token passed through a curl config on stdin to keep it out of the process list
            if printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$token" \
                | curl -fsS -m 20 --retry 2 -o /dev/null -K - \
                    --data-urlencode "chat_id=$tg_chat" \
                    --data-urlencode "text=${message:0:4000}" 2>/dev/null; then
                NOTIF_SENT+=("telegram")
            else
                hedgii_log "WARN" "Telegram notification failed"; failed=$((failed+1))
            fi
        fi
    fi
    return $failed
}

# Public: notify_backup_result <level> <exit_code> <start_epoch> <archive> <destination>
notif_backup_result() {
    local level="$1" code="$2" start="$3" archive="$4" dest="$5"
    notif_enabled_for "$level" || return 0
    local duration=$(( $(date +%s) - start )) size="n/a" icon="✅"
    [[ -n "$archive" && -f "$archive" ]] && size=$(du -h "$archive" | cut -f1)
    [[ "$level" == "failure" ]] && icon="❌"
    [[ "$level" == "warning" ]] && icon="⚠️"
    local errors=""
    errors=$(grep -E '\[(ERROR|WARN)\]' "$LOG_FILE" 2>/dev/null | tail -n 5 || true)
    local msg
    msg="$icon Hedgii backup ${level} on $(hostname)
Duration: ${duration}s
Archive size: ${size}
Destination: ${dest:-n/a}
Exit code: ${code}"
    [[ -n "$errors" ]] && msg+=$'\n'"Last errors:"$'\n'"$errors"
    NOTIF_SENT=()
    notif_send "$msg" || true
    return 0
}

# hedgii test-notify
hedgii_test_notify() {
    NOTIF_SENT=()
    local configured=0
    jq -e '.notifications' "$CONFIG_FILE" >/dev/null 2>&1 || {
        hedgii_log "WARN" "No notifications block in $CONFIG_FILE"; return 1; }
    local rc=0
    notif_send "🦔 Hedgii test notification from $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')" || rc=$?
    if [[ -n "$(notif_cfg '.notifications.ping_url')" ]]; then
        configured=1
        notif_ping success
    fi
    if [[ ${#NOTIF_SENT[@]} -eq 0 && $configured -eq 0 && $rc -eq 0 ]]; then
        hedgii_log "WARN" "No notification channel configured"
        return 1
    fi
    [[ ${#NOTIF_SENT[@]} -gt 0 ]] && hedgii_log "INFO" "Test message sent to: ${NOTIF_SENT[*]}"
    [[ $rc -eq 0 ]] || return 1
    return 0
}

# Main backup function with multi-sync support
hedgii_curl_run() {
    hedgii_log "KAWAII" "🦔 Hedgii is ready to protect your data with enhanced sync powers! ✨"

    local start_time=$SECONDS

    acquire_lock
    check_dependencies

    local staging_dir
    staging_dir=$(cleanup_staging) || exit $EXIT_CONFIG_ERROR
    # Removed by cleanup_on_exit on every exit path. The trap is set again here because
    # hedgii_curl runs this function in a subshell, and subshells don't inherit EXIT traps.
    STAGING_DIR="$staging_dir"
    trap cleanup_on_exit EXIT

    if ! preflight_free_space "$staging_dir"; then
        exit $EXIT_NO_SPACE
    fi

    # Use enhanced processing with custom commands
    if ! process_sources_with_commands "$staging_dir"; then
        hedgii_log "ERROR" "Data collection failed!"
        exit $EXIT_COLLECT_FAILED
    fi

    # Generate comprehensive report
    generate_backup_report "$staging_dir"

    if ! check_space_before_archive "$staging_dir"; then
        exit $EXIT_NO_SPACE
    fi

    if ! encrypt_staging "$staging_dir" || [[ ! -f "$ENCRYPTED_FILE" ]]; then
        hedgii_log "ERROR" "Compression/encryption failed - no valid archive produced"
        exit $EXIT_COMPRESS_FAILED
    fi
    local encrypted_file="$ENCRYPTED_FILE"

    local size destination duration
    size=$(du -h "$encrypted_file" | cut -f1)
    destination=$(get_sync_method 2>/dev/null) || destination="unknown"

    if smart_upload_to_cloud "$encrypted_file"; then
        mark_uploaded "$encrypted_file"
        prune_local || true
        prune_remote || true
        duration=$((SECONDS - start_time))
        hedgii_log "KAWAII" "🎉 Backup completed successfully! Your data is safe! (≧◡≦)"
        hedgii_log "INFO" "SUMMARY status=success duration=${duration}s size=$size destination=$destination file=$(basename "$encrypted_file")"
    else
        warn_unsent_archives "$(get_backup_dir)"
        duration=$((SECONDS - start_time))
        hedgii_log "ERROR" "Upload failed, keeping local backup"
        hedgii_log "ERROR" "SUMMARY status=upload_failed duration=${duration}s size=$size destination=$destination file=$encrypted_file"
        exit $EXIT_UPLOAD_FAILED
    fi
}

# ---------------------------------------------------------------------------
# verify: prove that a backup can actually be restored
# ---------------------------------------------------------------------------

# Free disk space verify needs in <work_dir>: the download (remote) plus, for ZIP only, the
# decrypted copy (unzip needs a seekable file). TAR.GZ is checked as a stream, without a copy.
verify_require_space() {
    local work_dir="$1" archive_name="$2" archive_bytes="$3" source="$4" ratio need=0
    ratio=$(jq -r '.settings.min_free_space_ratio // 1.2' "$CONFIG_FILE")
    if awk -v r="$ratio" 'BEGIN { exit !(r <= 0) }'; then
        return 0
    fi
    [[ "$source" == "remote" ]] && need=$((need + archive_bytes))
    [[ "$archive_name" == *.zip.gpg ]] && need=$((need + archive_bytes))
    [[ "$need" -gt 0 ]] || return 0
    require_free_space "verify" "$work_dir" "$need" >&2
}

# Download (remote) or pick (local) the archive to check. Prints its path on stdout.
# Returns 1 when there is nothing to verify or the download fails, 2 when disk space is too low.
verify_fetch_archive() {
    local source="$1" name="$2" work_dir="$3"
    local backup_dir
    backup_dir=$(get_backup_dir)

    if [[ "$source" == "remote" ]]; then
        local remote
        remote=$(get_rclone_remote)
        if [[ -z "$name" ]]; then
            # Names embed the timestamp, so the last one in lexical order is the newest
            name=$(hedgii_rclone lsf "$remote" --files-only --include 'hedgii_backup_*.gpg' 2>>"$LOG_FILE" | sort | tail -n1) || name=""
            [[ -n "$name" ]] || { hedgii_log "ERROR" "No archive found on $remote" >&2; return 1; }
        fi
        local bytes
        bytes=$(hedgii_rclone lsf --format s "${remote%/}/$name" 2>>"$LOG_FILE" | head -n1) || bytes=""
        [[ "$bytes" =~ ^[0-9]+$ ]] || { hedgii_log "ERROR" "Archive not found on the remote: ${remote%/}/$name" >&2; return 1; }
        verify_require_space "$work_dir" "$name" "$bytes" remote || return 2
        hedgii_log "INFO" "📥 Downloading $name ($(human_size "$bytes")) from $remote..." >&2
        if ! hedgii_rclone copyto "${remote%/}/$name" "$work_dir/$name" 2>>"$LOG_FILE"; then
            hedgii_log "ERROR" "Download failed: ${remote%/}/$name" >&2
            return 1
        fi
        echo "$work_dir/$name"
    else
        local archive
        if [[ -n "$name" ]]; then
            archive="$backup_dir/$name"
        else
            archive=$(list_archives "$backup_dir" | head -n1)
        fi
        [[ -n "$archive" && -f "$archive" ]] || { hedgii_log "ERROR" "No local archive found${name:+: $name}" >&2; return 1; }
        verify_require_space "$work_dir" "$(basename "$archive")" "$(stat -c %s "$archive")" local || return 2
        echo "$archive"
    fi
}

# Decrypt, test the archive and compare its content with the embedded report
verify_archive() {
    local archive="$1" work_dir="$2"
    local passphrase_file listing expected actual report_file="$work_dir/report.txt"
    passphrase_file=$(jq -r '.settings.encrypt_passphrase_file' "$CONFIG_FILE")

    hedgii_log "INFO" "🔓 Decrypting and checking $(basename "$archive")..."
    case "$archive" in
        *.zip.gpg)
            command -v unzip >/dev/null 2>&1 || { hedgii_log "ERROR" "unzip is required to verify ZIP backups"; return 1; }
            # unzip needs a seekable file: the decrypted copy is written (space checked beforehand)
            if ! gpg --batch --quiet --passphrase-file "$passphrase_file" --decrypt "$archive" \
                > "$work_dir/archive" 2>>"$LOG_FILE"; then
                hedgii_log "ERROR" "Decryption failed (wrong passphrase, truncated or corrupted archive)"
                return 1
            fi
            if ! unzip -tq "$work_dir/archive" >>"$LOG_FILE" 2>&1; then
                hedgii_log "ERROR" "ZIP integrity test failed"
                return 1
            fi
            listing=$(unzip -Z1 "$work_dir/archive" | grep -v '/$' || true)
            unzip -p "$work_dir/archive" hedgii_backup_report.txt > "$report_file" 2>/dev/null || true
            rm -f "$work_dir/archive"
            ;;
        *.tar.gz.gpg)
            # Streamed: no decrypted copy on disk. Two passes (listing, then the report) cost a
            # second decryption but never more disk than the .gpg itself.
            local -a status=()
            { gpg --batch --quiet --passphrase-file "$passphrase_file" --decrypt "$archive" 2>>"$LOG_FILE" \
                | tar -tvzf - > "$work_dir/listing" 2>>"$LOG_FILE"
              status=("${PIPESTATUS[@]}"); } || true
            # gpg first: a failed decryption also breaks tar's input
            if [[ "${status[0]:-1}" -ne 0 ]]; then
                hedgii_log "ERROR" "Decryption failed (gpg exit code ${status[0]:-?}: wrong passphrase, truncated or corrupted archive)"
                return 1
            fi
            if [[ "${status[1]:-1}" -ne 0 ]]; then
                hedgii_log "ERROR" "TAR.GZ integrity test failed (tar exit code ${status[1]:-?})"
                return 1
            fi
            # Regular files and hard links: in direct mode tar stores the second name of a
            # hard-linked file (Maildir messages in two folders...) as an "h" entry
            listing=$(grep '^[-h]' "$work_dir/listing" || true)
            gpg --batch --quiet --passphrase-file "$passphrase_file" --decrypt "$archive" 2>>"$LOG_FILE" \
                | tar -xzf - -O ./hedgii_backup_report.txt > "$report_file" 2>/dev/null || true
            ;;
        *)
            hedgii_log "ERROR" "Unknown archive format: $(basename "$archive")"
            return 1
            ;;
    esac

    if [[ ! -s "$report_file" ]]; then
        hedgii_log "ERROR" "hedgii_backup_report.txt missing from the archive"
        return 1
    fi
    expected=$(sed -n 's/^Total files: *\([0-9][0-9]*\).*/\1/p' "$report_file" | head -n1)
    actual=$(grep -c . <<<"$listing" || true)
    # Fewer files than reported means data is missing. More is possible (zip follows symlinks).
    if [[ -n "$expected" && "$actual" -lt "$expected" ]]; then
        hedgii_log "ERROR" "Archive holds $actual files, report says $expected"
        return 1
    fi
    hedgii_log "INFO" "✅ Archive OK: $actual files (report: ${expected:-?})"
}

hedgii_verify() {
    local source="remote" name=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remote) source="remote"; shift ;;
            --local) source="local"; shift ;;
            --archive) name="${2:-}"; shift 2 || true ;;
            --archive=*) name="${1#*=}"; shift ;;
            *) hedgii_log "ERROR" "Usage: hedgii verify [--remote|--local] [--archive <name>]"; exit $EXIT_CONFIG_ERROR ;;
        esac
    done

    acquire_lock
    check_dependencies
    if [[ "$source" == "remote" && "$(get_sync_method 2>/dev/null)" != "rclone" ]]; then
        hedgii_log "WARN" "Remote verify needs rclone (the OneDrive client is upload-only), checking the local archive instead"
        source="local"
    fi

    local staging_base work_dir
    staging_base=$(jq -r '.settings.staging_dir // "/tmp/hedgii_staging"' "$CONFIG_FILE")
    mkdir -p "$(dirname "$staging_base")"
    # Same filesystem as staging (already sized for the data), private, removed on every exit path
    work_dir=$(mktemp -d "${staging_base%/}.verify.XXXXXX") || exit $EXIT_CONFIG_ERROR
    STAGING_DIR="$work_dir"

    hedgii_log "KAWAII" "🔍 Verifying the latest $source backup..."
    local archive="" rc=0 fetch_rc=0
    archive=$(verify_fetch_archive "$source" "$name" "$work_dir") || fetch_rc=$?
    if [[ $fetch_rc -eq 2 ]]; then
        rc=$EXIT_NO_SPACE
        archive=""
    elif [[ $fetch_rc -ne 0 ]]; then
        rc=$EXIT_VERIFY_FAILED
        archive=""
    elif ! verify_archive "$archive" "$work_dir"; then
        rc=$EXIT_VERIFY_FAILED
    fi

    local level="success" icon="✅" result="restorable"
    if [[ $rc -eq $EXIT_NO_SPACE ]]; then
        level="failure"; icon="❌"; result="not checked: not enough free disk space"
    elif [[ $rc -ne 0 ]]; then
        level="failure"; icon="❌"; result="NOT restorable"
    fi
    hedgii_log "INFO" "SUMMARY verify=$level source=$source archive=$(basename "${archive:-none}")"
    if notif_enabled_for "$level"; then
        NOTIF_SENT=()
        notif_send "$icon Hedgii verify on $(hostname): $(basename "${archive:-no archive}") ($source) is $result" || true
    fi
    return $rc
}

# Backup wrapper: ping + notifications around the actual run
hedgii_curl() {
    local start_epoch
    start_epoch=$(date +%s)
    notif_ping start

    # Not "( ... ) || rc=$?": inside an || list bash ignores set -e for the whole subshell,
    # so a failing command in the backup would no longer stop it
    local rc
    set +e
    ( set -e; hedgii_curl_run )
    rc=$?
    set -e

    local backup_dir archive dest
    backup_dir=$(jq -r '.settings.backup_dir // "/var/backups/hedgii"' "$CONFIG_FILE" 2>/dev/null || echo "")
    archive=$(ls -1 "$backup_dir"/hedgii_backup_"${DATE}".*.gpg 2>/dev/null | head -n1 || true)
    dest=$(jq -r '.settings.rclone_remote // .settings.onedrive_backup_dir // empty' "$CONFIG_FILE" 2>/dev/null || true)

    if [[ $rc -ne 0 ]]; then
        notif_ping fail
        notif_backup_result failure "$rc" "$start_epoch" "$archive" "$dest"
    else
        notif_ping success
        # A successful run that logged errors (failed non-blocking command...) or left an
        # archive behind is reported as a warning. Plain WARN lines don't count: tools like
        # mysqldump write harmless warnings to stderr on every run.
        if grep -qE '\[ERROR\]|Archive never uploaded' "$LOG_FILE" 2>/dev/null; then
            notif_backup_result warning 0 "$start_epoch" "$archive" "$dest"
        else
            notif_backup_result success 0 "$start_epoch" "$archive" "$dest"
        fi
    fi
    return $rc
}

# Interactive sync method selection
select_sync_method() {
    hedgii_log "KAWAII" "🤔 Which sync method would you like to use?"

    local available_clients=($(detect_sync_clients))

    if [[ ${#available_clients[@]} -eq 0 ]]; then
        hedgii_log "ERROR" "No sync clients available. Install rclone or onedrive first."
        return 1
    fi

    echo ""
    echo "Available options:"
    echo "  1) Auto-detect (recommended)"

    local option_number=2
    for client in "${available_clients[@]}"; do
        case "$client" in
            "rclone")   echo "  $option_number) rclone (supports multiple clouds)" ;;
            "onedrive") echo "  $option_number) OneDrive client (OneDrive optimized)" ;;
        esac
        option_number=$((option_number + 1))
    done

    echo ""
    read -p "🦔 Choose option (1-$((option_number-1))): " choice

    case "$choice" in
        1) echo "auto" ;;
        2) echo "${available_clients[0]}" ;;
        3) echo "${available_clients[1]}" ;;
        *) echo "auto" ;;
    esac
}

# Enhanced setup wizard
setup_sync_wizard() {
    hedgii_log "KAWAII" "🧙 Welcome to the Hedgii Sync Setup Wizard!"
    echo ""

    # Detect available clients
    local available_clients=($(detect_sync_clients))

    if [[ ${#available_clients[@]} -eq 0 ]]; then
        hedgii_log "WARN" "No sync clients detected. Please install rclone or onedrive first."
        return 1
    fi

    # Show available clients
    hedgii_log "INFO" "Available sync clients: ${available_clients[*]}"

    # Let user choose
    local sync_method=$(select_sync_method)
    hedgii_log "INFO" "Selected sync method: $sync_method"

    # Update configuration
    local temp_config=$(mktemp)
    jq --arg method "$sync_method" '.settings.sync_method = $method' "$CONFIG_FILE" > "$temp_config"
    mv "$temp_config" "$CONFIG_FILE"

    # Setup chosen method
    case "$sync_method" in
        "onedrive"|"auto")
            if [[ " ${available_clients[*]} " =~ " onedrive " ]]; then
                setup_onedrive_client
            fi
            ;;
    esac

    # Setup rclone if chosen or available
    if [[ "$sync_method" == "rclone" ]] || [[ "$sync_method" == "auto" && " ${available_clients[*]} " =~ " rclone " ]]; then
        setup_rclone || hedgii_log "WARN" "rclone setup incomplete, re-run: sudo hedgii setup-rclone"
    fi

    hedgii_log "KAWAII" "✨ Sync setup completed!"
}


# Edit configuration with nano
hedgii_edit_config() {
    hedgii_log "KAWAII" "🦔 Opening configuration for editing! ✨"

    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        hedgii_log "ERROR" "Configuration file not found: $CONFIG_FILE"
        hedgii_log "INFO" "Run the installer or create the config file first"
        exit 1
    fi

    # Backup current config
    local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$backup_file"
    hedgii_log "INFO" "Config backed up to: $backup_file"

    # Open nano
    hedgii_log "INFO" "Opening nano editor..."
    echo ""
    echo "💡 Tips for editing:"
    echo "   - Use Ctrl+X to save and exit"
    echo "   - Use Ctrl+G for help"
    echo "   - Configuration will be validated after editing"
    echo ""
    read -p "Press Enter to continue..."

    # Launch nano
    if nano "$CONFIG_FILE"; then
        hedgii_log "INFO" "Editor closed, validating configuration..."

        # Validate JSON after editing
        if jq empty "$CONFIG_FILE" 2>/dev/null; then
            hedgii_log "INFO" "✓ Configuration is valid!"
            hedgii_log "KAWAII" "🎉 Configuration updated successfully! (≧◡≦)"
        else
            hedgii_log "ERROR" "✗ Configuration JSON is invalid!"
            echo ""
            read -p "Do you want to fix it now? (y/n): " fix_choice
            if [[ "$fix_choice" =~ ^[Yy] ]]; then
                hedgii_edit_config  # Recursive call to re-edit
            else
                hedgii_log "WARN" "Restoring backup..."
                cp "$backup_file" "$CONFIG_FILE"
                hedgii_log "INFO" "Original configuration restored"
            fi
        fi
    else
        hedgii_log "WARN" "Editor was cancelled, no changes made"
    fi
}

# Show compression format info
show_compression_info() {
    local compression_format=$(jq -r '.settings.compression_format // "tar.gz"' "$CONFIG_FILE")
    
    hedgii_log "INFO" "📦 Current compression format: $compression_format"
    
    case "$compression_format" in
        "zip")
            hedgii_log "INFO" "   ✓ Windows-friendly ZIP format"
            hedgii_log "INFO" "   ✓ Better Windows integration"
            hedgii_log "INFO" "   ✓ Native Windows support"
            ;;
        "tar.gz")
            hedgii_log "INFO" "   ✓ Unix-standard TAR.GZ format"
            hedgii_log "INFO" "   ✓ Better compression ratio"
            hedgii_log "INFO" "   ✓ Preserves Unix permissions"
            ;;
    esac
    
    hedgii_log "INFO" "💡 Change format in config: compression_format"
}

# Change GPG passphrase
hedgii_change_passphrase() {
    hedgii_log "KAWAII" "🔐 Changing your GPG passphrase! Let's make it even more secure! ✨"

    local passphrase_file=$(jq -r '.settings.encrypt_passphrase_file // "/etc/hedgii/gpg_passphrase"' "$CONFIG_FILE")

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        hedgii_log "ERROR" "This command must be run as root (use sudo)"
        exit 1
    fi

    # Check if passphrase file exists
    if [[ ! -f "$passphrase_file" ]]; then
        hedgii_log "ERROR" "Passphrase file not found: $passphrase_file"
        hedgii_log "INFO" "Run the installer to set up the initial passphrase"
        exit 1
    fi

    # Backup current passphrase
    local backup_passphrase_file="$passphrase_file.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$passphrase_file" "$backup_passphrase_file"
    chmod 600 "$backup_passphrase_file"
    hedgii_log "INFO" "Old passphrase backed up to: $backup_passphrase_file"

    echo ""
    hedgii_log "WARN" "🚨 IMPORTANT SECURITY NOTICE 🚨"
    echo "   • Your old backups will still use the OLD passphrase"
    echo "   • Keep the old passphrase safe until you no longer need old backups"
    echo "   • Future backups will use the NEW passphrase"
    echo "   • Test the new passphrase immediately after changing it"
    echo ""

    read -p "🤔 Do you want to continue? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        hedgii_log "INFO" "Passphrase change cancelled"
        rm -f "$backup_passphrase_file"
        exit 0
    fi

    echo ""
    local new_passphrase=""
    local confirm_passphrase=""

    while [[ -z "$new_passphrase" || "$new_passphrase" != "$confirm_passphrase" ]]; do
        echo -n "🔑 Enter NEW GPG passphrase: "
        read -s new_passphrase
        echo

        if [[ -z "$new_passphrase" ]]; then
            hedgii_log "WARN" "Passphrase cannot be empty"
            continue
        fi

        if [[ ${#new_passphrase} -lt 8 ]]; then
            hedgii_log "WARN" "Passphrase should be at least 8 characters long"
            continue
        fi

        echo -n "🔑 Confirm NEW GPG passphrase: "
        read -s confirm_passphrase
        echo

        if [[ "$new_passphrase" != "$confirm_passphrase" ]]; then
            hedgii_log "WARN" "Passphrases don't match, try again"
        fi
    done

    # Update passphrase file
    echo "$new_passphrase" > "$passphrase_file"
    chmod 600 "$passphrase_file"

    hedgii_log "INFO" "✓ New passphrase saved securely"

    # Test the new passphrase with a quick encryption/decryption
    hedgii_log "INFO" "🧪 Testing new passphrase..."
    local test_file="/tmp/hedgii_test_$$.txt"
    local test_encrypted="/tmp/hedgii_test_$$.gpg"

    echo "Hedgii test data $(date)" > "$test_file"

    if gpg --symmetric --cipher-algo AES256 --batch --yes \
        --passphrase-file "$passphrase_file" \
        --output "$test_encrypted" "$test_file" 2>/dev/null; then

        if gpg --decrypt --batch --yes \
            --passphrase-file "$passphrase_file" \
            "$test_encrypted" >/dev/null 2>&1; then

            hedgii_log "INFO" "✅ New passphrase test successful!"
            hedgii_log "KAWAII" "🎉 Passphrase changed successfully! Your backups are now even more secure! (≧◡≦)"
        else
            hedgii_log "ERROR" "❌ Decryption test failed!"
            hedgii_log "WARN" "Restoring old passphrase..."
            cp "$backup_passphrase_file" "$passphrase_file"
            chmod 600 "$passphrase_file"
            hedgii_log "INFO" "Old passphrase restored"
        fi
    else
        hedgii_log "ERROR" "❌ Encryption test failed!"
        hedgii_log "WARN" "Restoring old passphrase..."
        cp "$backup_passphrase_file" "$passphrase_file"
        chmod 600 "$passphrase_file"
        hedgii_log "INFO" "Old passphrase restored"
    fi

    # Cleanup test files
    rm -f "$test_file" "$test_encrypted"

    echo ""
    hedgii_log "INFO" "📋 Next steps:"
    echo "   1. Test a backup: hedgii curl"
    echo "   2. Verify you can decrypt: hedgii test-commands"
    echo "   3. Keep the old passphrase backup safe: $backup_passphrase_file"
    echo ""
    hedgii_log "KAWAII" "Remember: A secure hedgehog is a happy hedgehog! 🦔🔐"
}

cmd_test_commands() {
    hedgii_log "KAWAII" "🦔 Testing custom commands without full backup..."
    acquire_lock
    # STAGING_DIR is deliberately not set: the results stay on disk for inspection
    local staging_dir
    staging_dir=$(cleanup_staging)
    execute_custom_commands "$staging_dir"
    hedgii_log "INFO" "Check results in: $staging_dir"
}

cmd_validate_config() {
    hedgii_log "INFO" "🔍 Validating configuration..."
    if jq empty "$CONFIG_FILE" 2>/dev/null; then
        hedgii_log "INFO" "✓ Configuration JSON is valid"
        local custom_count source_count
        custom_count=$(jq '.custom_commands | length' "$CONFIG_FILE")
        source_count=$(jq '.backup_sources | length' "$CONFIG_FILE")
        hedgii_log "INFO" "📊 Found $custom_count custom commands, $source_count file sources"
        hedgii_log "INFO" "🚫 Effective global exclusions:"
        local excl idx src_excl
        excl=$(jq -r '(.exclusions // [])[] | "   - " + .' "$CONFIG_FILE")
        echo "${excl:-   (none)}"
        for ((idx=0; idx<source_count; idx++)); do
            src_excl=$(jq -r ".backup_sources[$idx].exclude // [] | .[]" "$CONFIG_FILE" | paste -sd, -)
            if [[ -n "$src_excl" ]]; then
                echo "   • $(jq -r ".backup_sources[$idx].source" "$CONFIG_FILE"): $src_excl"
            fi
        done
    else
        hedgii_log "ERROR" "✗ Configuration JSON is invalid"
        return 1
    fi
}

cmd_sync_status() {
    hedgii_log "INFO" "📊 Sync clients status:"
    local available_clients=($(detect_sync_clients))
    local sync_method
    sync_method=$(get_sync_method 2>/dev/null) || sync_method="none"

    hedgii_log "INFO" "Available clients: ${available_clients[*]:-}"
    hedgii_log "INFO" "Current method: $sync_method"

    local client remotes
    for client in "${available_clients[@]:-}"; do
        case "$client" in
            "rclone")
                remotes=$(hedgii_rclone listremotes 2>/dev/null | wc -l)
                hedgii_log "INFO" "rclone: $remotes remotes configured"
                ;;
            "onedrive")
                if [[ -f "/etc/hedgii/onedrive/config" ]]; then
                    hedgii_log "INFO" "OneDrive: configured"
                else
                    hedgii_log "INFO" "OneDrive: not configured"
                fi
                ;;
        esac
    done
}

# Command handling with enhanced multi-sync support
case "${1:-curl}" in
    "curl")
        hedgii_curl
        ;;
    "peek")
        hedgii_peek
        ;;
    "prune")
        hedgii_prune "${2:-}"
        ;;
    "guard")
        hedgii_log "INFO" "Hedgii is guarding your data 24/7! 🛡️"
        ;;
    "test-commands")
        cmd_test_commands
        ;;
    "validate-config")
        cmd_validate_config
        ;;
    "test-sync")
        hedgii_log "KAWAII" "🧪 Testing sync clients..."
        test_sync_clients || exit 1
        ;;
    "setup-rclone")
        setup_rclone || exit 1
        ;;
    "setup-sync")
        hedgii_log "KAWAII" "🔧 Setting up sync configuration..."
        setup_sync_wizard
        ;;
    "setup-onedrive")
        hedgii_log "KAWAII" "🔄 Setting up OneDrive client..."
        setup_onedrive_client
        ;;
    "sync-status")
        cmd_sync_status
        ;;
    "edit-config")
        hedgii_edit_config
        ;;
    "change-passphrase")
        hedgii_change_passphrase
        ;;
    "compression-info")
        show_compression_info
        ;;
    "verify")
        shift
        hedgii_verify "$@"
        ;;
    "test-notify")
        hedgii_log "KAWAII" "📣 Testing notifications..."
        hedgii_test_notify
        ;;
    "version"|"--version"|"-v")
        echo "Hedgii $HEDGII_VERSION"
        ;;
    *)
        echo "🦔 Hedgii $HEDGII_VERSION - Commands:"
        echo "  curl              - Backup your data with enhanced sync (default)"
        echo "  peek              - Check backup status"
        echo "  prune [--dry-run] - Apply retention policy to local/remote backups"
        echo "  verify [--remote|--local] [--archive NAME]"
        echo "                    - Download, decrypt and test the latest backup"
        echo "  guard             - View protection status"
        echo "  test-commands     - Test custom commands without full backup"
        echo "  validate-config   - Validate configuration file"
        echo "  edit-config       - Edit configuration with nano"
        echo "  change-passphrase - Change GPG encryption passphrase"
        echo "  compression-info  - Show current compression format information"
        echo "  version           - Show the Hedgii version"
        echo "  test-notify       - Send a test message on each configured notification channel"
        echo ""
        echo "🔄 Sync Commands:"
        echo "  test-sync         - Test available sync clients"
        echo "  setup-sync        - Interactive sync setup wizard"
        echo "  setup-rclone      - Guided rclone setup + write test"
        echo "  setup-onedrive    - Setup OneDrive client specifically"
        echo "  sync-status       - Show sync clients status"
        ;;
esac
