#!/bin/bash
# =============================================================================
# J'Toye Digital - Common Library v2.1
# =============================================================================
# Shared functions and variables for all jtoye-* scripts.
# Source this file at the start of every script.
# =============================================================================

# Strict mode
set -euo pipefail

# Version
JTOYE_SCRIPTS_VERSION="2.1.0"

# =============================================================================
# Configuration (can be overridden via environment)
# =============================================================================
JTOYE_COMMAND_TIMEOUT=${JTOYE_COMMAND_TIMEOUT:-60}
JTOYE_FIND_MAXDEPTH=${JTOYE_FIND_MAXDEPTH:-15}
JTOYE_OFFLINE=${JTOYE_OFFLINE:-false}

# =============================================================================
# Error Handling
# =============================================================================
jtoye_error_handler() {
    local exit_code=$1
    local line_no=$2
    local command="$3"
    local script="${BASH_SOURCE[1]:-unknown}"
    echo -e "\033[0;31mError in $(basename "$script") line $line_no: '$command' (exit $exit_code)\033[0m" >&2
}

# Cleanup handler
jtoye_cleanup() {
    # Reset terminal colors
    printf '%b' "${NC:-\033[0m}"
}
trap jtoye_cleanup EXIT

# =============================================================================
# Project Root Detection (consistent across all scripts)
# =============================================================================
# Priority: 1) Explicit arg, 2) JTOYE_PROJECT_ROOT env, 3) Current directory
detect_project_root() {
    local arg_root="${1:-}"
    local resolved=""
    
    if [[ -n "$arg_root" ]]; then
        if [[ -d "$arg_root" ]]; then
            resolved=$(cd -- "$arg_root" && pwd -P)
        else
            echo "Error: Directory not found: $arg_root" >&2
            return 1
        fi
    elif [[ -n "${JTOYE_PROJECT_ROOT:-}" ]]; then
        if [[ -d "$JTOYE_PROJECT_ROOT" ]]; then
            resolved=$(cd -- "$JTOYE_PROJECT_ROOT" && pwd -P)
        else
            echo "Error: JTOYE_PROJECT_ROOT not found: $JTOYE_PROJECT_ROOT" >&2
            return 1
        fi
    else
        resolved=$(pwd -P)
    fi
    
    # Validate path exists and is accessible
    if [[ ! -d "$resolved" ]] || [[ ! -r "$resolved" ]]; then
        echo "Error: Cannot access directory: $resolved" >&2
        return 1
    fi
    
    echo "$resolved"
}

# =============================================================================
# Standard Exclusions (for grep and find)
# =============================================================================
# These directories are ALWAYS excluded to prevent slow scans

# For grep -r
JTOYE_GREP_EXCLUDE="--exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=vendor --exclude-dir=.cache --exclude-dir=coverage --exclude-dir=.nyc_output --exclude-dir=.pytest_cache --exclude-dir=.mypy_cache --exclude-dir=.tox --exclude-dir=.eggs --exclude-dir=*.egg-info --exclude-dir=target --exclude-dir=bin --exclude-dir=obj"

# For find (use with: ! -path pattern)
JTOYE_FIND_EXCLUDES=(
    "*/node_modules/*"
    "*/.venv/*"
    "*/venv/*"
    "*/env/*"
    "*/.git/*"
    "*/__pycache__/*"
    "*/.next/*"
    "*/dist/*"
    "*/build/*"
    "*/vendor/*"
    "*/.cache/*"
    "*/coverage/*"
    "*/.nyc_output/*"
    "*/.pytest_cache/*"
    "*/.mypy_cache/*"
    "*/.tox/*"
    "*/.eggs/*"
    "*/*.egg-info/*"
    "*/site-packages/*"
    "*/target/*"
    "*/bin/*"
    "*/obj/*"
)

# Build find exclusion string
build_find_excludes() {
    local excludes=""
    for pattern in "${JTOYE_FIND_EXCLUDES[@]}"; do
        excludes="$excludes ! -path \"$pattern\""
    done
    echo "$excludes"
}

# =============================================================================
# Colors (safe for non-terminal use)
# =============================================================================
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    BOLD=''
    NC=''
fi

# =============================================================================
# Output Helpers
# =============================================================================
jtoye_header() {
    local title="$1"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $title${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

jtoye_section() {
    local section="$1"
    echo -e "${BLUE}[$section]${NC}"
}

jtoye_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
}

jtoye_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

jtoye_fail() {
    echo -e "  ${RED}✗${NC} $1"
}

jtoye_info() {
    echo -e "  ${CYAN}ℹ${NC} $1"
}

jtoye_skip() {
    echo -e "  ${YELLOW}⊘${NC} $1"
}

# =============================================================================
# Project Detection
# =============================================================================
detect_project_type() {
    local root="$1"
    local types=""
    
    [[ -f "$root/go.mod" ]] && types="$types go"
    [[ -f "$root/package.json" ]] && types="$types node"
    [[ -f "$root/requirements.txt" ]] || [[ -f "$root/pyproject.toml" ]] || [[ -f "$root/setup.py" ]] && types="$types python"
    [[ -f "$root/Cargo.toml" ]] && types="$types rust"
    [[ -f "$root/pom.xml" ]] || [[ -f "$root/build.gradle" ]] && types="$types java"
    
    # Check service subdirectories for monorepos
    [[ -d "$root/services" ]] && {
        [[ -f "$root/services/go-api/go.mod" ]] && types="$types go"
        [[ -f "$root/services/ml-service/requirements.txt" ]] && types="$types python"
    }
    [[ -d "$root/apps" ]] && {
        [[ -f "$root/apps/web/package.json" ]] && types="$types node"
    }
    
    # Deduplicate
    echo "$types" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs
}

is_monorepo() {
    local root="$1"
    [[ -d "$root/services" ]] || [[ -d "$root/apps" ]] || [[ -d "$root/packages" ]] || [[ -f "$root/pnpm-workspace.yaml" ]] || [[ -f "$root/turbo.json" ]] || [[ -f "$root/lerna.json" ]]
}

# =============================================================================
# Safe Increment (validates variable name to prevent injection)
# =============================================================================
inc() {
    local var_name="$1"
    # Validate: only allow valid bash variable names
    if [[ ! "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "inc(): Invalid variable name '$var_name'" >&2
        return 1
    fi
    # Use nameref for safe indirect assignment (Bash 4.3+)
    local -n _ref="$var_name"
    ((_ref++)) || true
}

# =============================================================================
# Tool Availability Helpers
# =============================================================================
require_tool() {
    local tool="$1"
    local purpose="${2:-$tool}"
    if ! command -v "$tool" &>/dev/null; then
        jtoye_skip "$purpose ($tool not installed)"
        return 1
    fi
    return 0
}

# Run command with timeout (safe wrapper)
run_with_timeout() {
    local timeout_secs="${1:-$JTOYE_COMMAND_TIMEOUT}"
    shift
    if command -v timeout &>/dev/null; then
        timeout "${timeout_secs}s" "$@" 2>/dev/null || true
    else
        "$@" 2>/dev/null || true
    fi
}

# Check if offline mode is requested
skip_if_offline() {
    local desc="$1"
    if [[ "$JTOYE_OFFLINE" == "true" ]]; then
        jtoye_skip "$desc (offline mode)"
        return 0
    fi
    return 1
}

# JSON value extraction with jq fallback
json_value() {
    local json="$1"
    local key="$2"
    local default="${3:-0}"
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r "$key // \"$default\"" 2>/dev/null || echo "$default"
    else
        # Crude fallback: grep for simple key:value
        echo "$json" | grep -oE "\"${key#.}\":\s*[0-9]+" | grep -oE '[0-9]+' | head -1 || echo "$default"
    fi
}

# Check if project has content
validate_project_has_content() {
    local root="$1"
    if [[ -z "$(ls -A "$root" 2>/dev/null)" ]]; then
        jtoye_fail "Project directory is empty: $root"
        return 1
    fi
    return 0
}

# =============================================================================
# Summary Footer
# =============================================================================
jtoye_summary() {
    local errors="$1"
    local warnings="${2:-0}"
    local script_name="${3:-Check}"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}  ✓ $script_name passed${NC}"
    elif [[ $errors -eq 0 ]]; then
        echo -e "${YELLOW}  ⚠ $script_name OK with $warnings warning(s)${NC}"
    else
        echo -e "${RED}  ✗ $script_name: $errors error(s), $warnings warning(s)${NC}"
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    [[ $errors -gt 0 ]] && return 1
    return 0
}

# =============================================================================
# Exports
# =============================================================================
export JTOYE_SCRIPTS_VERSION
export JTOYE_GREP_EXCLUDE
export JTOYE_COMMAND_TIMEOUT
export JTOYE_FIND_MAXDEPTH
export JTOYE_OFFLINE
export -f detect_project_root detect_project_type is_monorepo build_find_excludes
export -f jtoye_header jtoye_section jtoye_pass jtoye_warn jtoye_fail jtoye_info jtoye_skip jtoye_summary
export -f inc require_tool run_with_timeout skip_if_offline json_value validate_project_has_content
