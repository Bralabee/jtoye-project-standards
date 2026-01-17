#!/bin/bash
# =============================================================================
# Common utilities and exclusion patterns for all scripts
# =============================================================================

# Standard directories to ALWAYS exclude from grep/find
EXCLUDE_DIRS="node_modules|\.venv|venv|\.git|__pycache__|\.next|dist|build|vendor|\.cache|coverage"

# Function for safe grep that excludes heavy directories
safe_grep() {
    local pattern="$1"
    local path="${2:-.}"
    local includes="$3"
    
    if [ -n "$includes" ]; then
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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'
