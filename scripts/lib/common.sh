#!/bin/bash
# =============================================================================
# Common utilities and exclusion patterns for all scripts
# J'Toye Digital - Project Standards Library
# =============================================================================

# =============================================================================
# BASH VERSION CHECK
# =============================================================================
# Requires Bash 4.3+ for associative arrays, nameref, and other features
check_bash_version() {
    local required_major=4
    local required_minor=3
    local current_major="${BASH_VERSINFO[0]}"
    local current_minor="${BASH_VERSINFO[1]}"
    
    if [[ "$current_major" -lt "$required_major" ]] || \
       [[ "$current_major" -eq "$required_major" && "$current_minor" -lt "$required_minor" ]]; then
        echo "ERROR: Bash $required_major.$required_minor+ required (current: $current_major.$current_minor)" >&2
        echo "On macOS: brew install bash && add /usr/local/bin/bash to /etc/shells" >&2
        exit 1
    fi
}

# Auto-check on source (can be disabled with SKIP_BASH_CHECK=1)
[[ "${SKIP_BASH_CHECK:-0}" != "1" ]] && check_bash_version

# =============================================================================
# LOCK FILE MANAGEMENT (prevents concurrent execution)
# =============================================================================
LOCK_DIR="${TMPDIR:-/tmp}"
LOCK_FILE=""

# Acquire a lock for a specific script
# Usage: acquire_lock "script-name"
acquire_lock() {
    local script_name="${1:-$(basename "$0")}"
    LOCK_FILE="${LOCK_DIR}/jtoye_audit_${script_name}.lock"
    
    # Check if lock exists and process is still running
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "ERROR: Another instance is running (PID: $pid)" >&2
            echo "If this is wrong, remove: $LOCK_FILE" >&2
            return 1
        fi
        # Stale lock file, remove it
        rm -f "$LOCK_FILE"
    fi
    
    # Create lock with current PID
    echo $$ > "$LOCK_FILE"
    
    # Set up cleanup trap
    trap 'release_lock' EXIT INT TERM
    return 0
}

# Release the lock
release_lock() {
    [[ -n "$LOCK_FILE" && -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
}

# =============================================================================
# TOOL REQUIREMENT CHECKING
# =============================================================================

# Check if a tool exists
# Usage: require_tool "go" "Go compiler"
# Usage: require_tool "npm" "npm package manager" "optional"
require_tool() {
    local tool="$1"
    local description="${2:-$tool}"
    local mode="${3:-required}"  # required, optional, or warn
    
    if command -v "$tool" &>/dev/null; then
        return 0
    fi
    
    case "$mode" in
        required)
            echo -e "${RED}ERROR: Required tool not found: $description ($tool)${NC}" >&2
            echo "Please install $description and try again." >&2
            exit 1
            ;;
        warn)
            echo -e "${YELLOW}WARNING: Tool not found: $description ($tool)${NC}" >&2
            return 1
            ;;
        optional)
            return 1
            ;;
    esac
}

# Check multiple tools at once
# Usage: require_tools "git,make,docker" "required"
require_tools() {
    local tools="$1"
    local mode="${2:-required}"
    local missing=()
    
    IFS=',' read -ra tool_array <<< "$tools"
    for tool in "${tool_array[@]}"; do
        tool=$(echo "$tool" | xargs)  # trim whitespace
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        if [[ "$mode" == "required" ]]; then
            echo -e "${RED}ERROR: Missing required tools: ${missing[*]}${NC}" >&2
            exit 1
        fi
        return 1
    fi
    return 0
}

# =============================================================================
# HELP HANDLER
# =============================================================================
# Standard help handler for individual scripts
# Usage: setup_help "Script description" "[options]"
#   Then: handle_help "$@"

SCRIPT_NAME=""
SCRIPT_DESC=""
SCRIPT_USAGE=""
SCRIPT_OPTIONS=()

setup_help() {
    SCRIPT_NAME="$(basename "${BASH_SOURCE[1]:-$0}")"
    SCRIPT_DESC="$1"
    SCRIPT_USAGE="${2:-[OPTIONS]}"
}

add_help_option() {
    SCRIPT_OPTIONS+=("$1")
}

show_help() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  J'Toye Digital - $SCRIPT_NAME"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "DESCRIPTION:"
    echo "  $SCRIPT_DESC"
    echo ""
    echo "USAGE:"
    echo "  $SCRIPT_NAME $SCRIPT_USAGE"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message and exit"
    for opt in "${SCRIPT_OPTIONS[@]}"; do
        echo "  $opt"
    done
    echo ""
    echo "ENVIRONMENT:"
    echo "  PROJECT_ROOT   Override the project root directory (default: pwd)"
    echo ""
    exit 0
}

# Call this to handle --help/-h
handle_help() {
    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                show_help
                ;;
        esac
    done
}

# =============================================================================
# STANDARD EXCLUSION PATTERNS
# =============================================================================
# Standard directories to ALWAYS exclude from grep/find
EXCLUDE_DIRS="node_modules|\.venv|venv|\.git|__pycache__|\.next|dist|build|vendor|\.cache|coverage"

# Grep exclusion flags as a string (for backward compatibility)
EXCL="--exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=vendor --exclude-dir=.cache --exclude-dir=coverage"

# =============================================================================
# SAFE FILE OPERATIONS (handles spaces in paths)
# =============================================================================

# Function for safe grep that excludes heavy directories
safe_grep() {
    local pattern="$1"
    local path="${2:-.}"
    local includes="$3"
    
    if [[ -n "$includes" ]]; then
        grep -rn --include="$includes" \
            --exclude-dir=node_modules \
            --exclude-dir=.venv \
            --exclude-dir=venv \
            --exclude-dir=.git \
            --exclude-dir=__pycache__ \
            --exclude-dir=.next \
            --exclude-dir=dist \
            --exclude-dir=build \
            --exclude-dir=vendor \
            --exclude-dir=.cache \
            --exclude-dir=coverage \
            "$pattern" "$path" 2>/dev/null || true
    else
        grep -rn \
            --exclude-dir=node_modules \
            --exclude-dir=.venv \
            --exclude-dir=venv \
            --exclude-dir=.git \
            --exclude-dir=__pycache__ \
            --exclude-dir=.next \
            --exclude-dir=dist \
            --exclude-dir=build \
            --exclude-dir=vendor \
            --exclude-dir=.cache \
            --exclude-dir=coverage \
            "$pattern" "$path" 2>/dev/null || true
    fi
}

# Function for safe find that excludes heavy directories
# Uses -print0 for proper handling of spaces in paths
safe_find() {
    local path="${1:-.}"
    local name_pattern="$2"
    local type="${3:-f}"
    
    find "$path" \
        -type "$type" \
        -name "$name_pattern" \
        ! -path "*/node_modules/*" \
        ! -path "*/.venv/*" \
        ! -path "*/venv/*" \
        ! -path "*/.git/*" \
        ! -path "*/__pycache__/*" \
        ! -path "*/.next/*" \
        ! -path "*/dist/*" \
        ! -path "*/build/*" \
        ! -path "*/vendor/*" \
        ! -path "*/.cache/*" \
        ! -path "*/coverage/*" \
        2>/dev/null || true
}

# Safe find with null-delimited output (for spaces in paths)
# Usage: safe_find_null "." "*.py" "f" | while IFS= read -r -d '' file; do ...; done
safe_find_null() {
    local path="${1:-.}"
    local name_pattern="$2"
    local type="${3:-f}"
    
    find "$path" \
        -type "$type" \
        -name "$name_pattern" \
        ! -path "*/node_modules/*" \
        ! -path "*/.venv/*" \
        ! -path "*/venv/*" \
        ! -path "*/.git/*" \
        ! -path "*/__pycache__/*" \
        ! -path "*/.next/*" \
        ! -path "*/dist/*" \
        ! -path "*/build/*" \
        ! -path "*/vendor/*" \
        ! -path "*/.cache/*" \
        ! -path "*/coverage/*" \
        -print0 \
        2>/dev/null || true
}

# Process files safely with spaces in paths
# Usage: process_files_safely "." "*.py" 'echo "Processing: $file"'
process_files_safely() {
    local path="${1:-.}"
    local pattern="$2"
    local callback="$3"
    
    while IFS= read -r -d '' file; do
        eval "$callback"
    done < <(safe_find_null "$path" "$pattern" "f")
}

# =============================================================================
# COLORS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# =============================================================================
# LOGGING UTILITIES
# =============================================================================
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${CYAN}DEBUG:${NC} $*"; }

# =============================================================================
# SCRIPT INITIALIZATION HELPER
# =============================================================================
# Use this at the start of each script for consistent setup
# Usage: init_script "Script Description" "$@"
init_script() {
    local description="$1"
    shift
    
    setup_help "$description"
    handle_help "$@"
    
    # Set PROJECT_ROOT if not already set
    PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
    
    # Verify we're in a valid project directory
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        log_error "PROJECT_ROOT does not exist: $PROJECT_ROOT"
        exit 1
    fi
}
