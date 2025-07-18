#!/bin/bash

# 🦔 Hedgii Test Script
# Quick validation that everything works correctly

set -euo pipefail

# Colors for kawaii output
PINK='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# Test logging function
test_log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")   echo -e "${GREEN}🦔 [TEST]${NC} $message" ;;
        "WARN")   echo -e "${YELLOW}⚠️  [TEST]${NC} $message" ;;
        "ERROR")  echo -e "${RED}💥 [TEST]${NC} $message" ;;
        "KAWAII") echo -e "${PINK}✨ [TEST]${NC} $message" ;;
    esac
}

# Show welcome
show_welcome() {
    clear
    echo -e "${PINK}"
    cat << 'EOF'
    🦔 =============================================== 🦔
    
         🧪 Hedgii Test Suite 🧪
         
         Testing your kawaii backup guardian
         to ensure everything works perfectly! (≧◡≦)
         
    🦔 =============================================== 🦔
EOF
    echo -e "${NC}"
    echo ""
}

# Test script syntax
test_script_syntax() {
    test_log "INFO" "Testing script syntax..."
    
    local scripts=("hedgii.sh" "install.sh" "uninstall.sh" "scripts/hedgii-doctor.sh")
    local syntax_errors=0
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            test_log "INFO" "Checking $script..."
            if bash -n "$script" 2>/dev/null; then
                test_log "INFO" "  ✓ Syntax OK"
            else
                test_log "ERROR" "  ✗ Syntax error in $script"
                ((syntax_errors++))
            fi
        else
            test_log "WARN" "  Script $script not found"
        fi
    done
    
    echo ""
    return $syntax_errors
}

# Test configuration validation
test_config_validation() {
    test_log "INFO" "Testing configuration validation..."
    
    local config_file="config/hedgii_config.json.example"
    
    if [[ -f "$config_file" ]]; then
        if jq empty "$config_file" 2>/dev/null; then
            test_log "INFO" "✓ Configuration JSON is valid"
            
            # Test specific fields
            local custom_count=$(jq '.custom_commands | length' "$config_file" 2>/dev/null)
            local source_count=$(jq '.backup_sources | length' "$config_file" 2>/dev/null)
            local settings_present=$(jq 'has("settings")' "$config_file" 2>/dev/null)
            
            test_log "INFO" "  Custom commands: $custom_count"
            test_log "INFO" "  Backup sources: $source_count"
            test_log "INFO" "  Settings present: $settings_present"
            
            return 0
        else
            test_log "ERROR" "✗ Configuration JSON is invalid"
            return 1
        fi
    else
        test_log "ERROR" "Configuration example file not found"
        return 1
    fi
    
    echo ""
}

# Test dependencies check
test_dependencies() {
    test_log "INFO" "Testing dependency detection..."
    
    local deps=("jq" "gpg" "rsync" "bash")
    local available=0
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            test_log "INFO" "  ✓ $dep available"
            ((available++))
        else
            test_log "WARN" "  ⚠ $dep not available"
        fi
    done
    
    test_log "INFO" "Dependencies available: $available/${#deps[@]}"
    echo ""
    
    return 0
}

# Test file structure
test_file_structure() {
    test_log "INFO" "Testing file structure..."
    
    local required_files=(
        "hedgii.sh"
        "install.sh"
        "uninstall.sh"
        "README.md"
        "LICENSE"
        ".gitignore"
        "config/hedgii_config.json.example"
        "scripts/hedgii-doctor.sh"
    )
    
    local missing_files=0
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            test_log "INFO" "  ✓ $file present"
        else
            test_log "WARN" "  ⚠ $file missing"
            ((missing_files++))
        fi
    done
    
    echo ""
    return $missing_files
}

# Test hedgii commands (if installed)
test_hedgii_commands() {
    test_log "INFO" "Testing Hedgii commands..."
    
    if command -v hedgii >/dev/null 2>&1; then
        test_log "INFO" "Hedgii is installed, testing commands..."
        
        # Test help
        if hedgii 2>/dev/null | grep -q "Hedgii Commands"; then
            test_log "INFO" "  ✓ Help command works"
        else
            test_log "WARN" "  ⚠ Help command failed"
        fi
        
        # Test config validation
        if hedgii validate-config >/dev/null 2>&1; then
            test_log "INFO" "  ✓ Config validation works"
        else
            test_log "WARN" "  ⚠ Config validation failed"
        fi
        
    else
        test_log "WARN" "Hedgii not installed, skipping command tests"
        test_log "INFO" "Run './install.sh' to install and test commands"
    fi
    
    echo ""
}

# Show test summary
show_summary() {
    local total_errors=$1
    
    test_log "KAWAII" "Test Suite Summary"
    
    if [[ $total_errors -eq 0 ]]; then
        test_log "INFO" "🎉 All tests passed! Hedgii is ready to deploy!"
        echo ""
        echo "✨ Next steps:"
        echo "   • Run: sudo ./install.sh"
        echo "   • Configure rclone: rclone config"
        echo "   • Test backup: hedgii curl"
    else
        test_log "WARN" "Found $total_errors issues that need attention"
        echo ""
        echo "🔧 Please fix the issues above before deployment"
    fi
    
    echo ""
    test_log "KAWAII" "Remember: Tested hedgehogs are happy hedgehogs! 🦔💖"
}

# Main test function
main() {
    show_welcome
    
    local total_errors=0
    
    test_script_syntax
    total_errors=$((total_errors + $?))
    
    test_config_validation
    total_errors=$((total_errors + $?))
    
    test_dependencies
    
    test_file_structure
    total_errors=$((total_errors + $?))
    
    test_hedgii_commands
    
    show_summary $total_errors
}

# Run tests
main "$@"