#!/bin/bash
# =============================================================================
# J'Toye Digital - Toolkit Installer v2.1
# =============================================================================
# Installs the .jtoye toolkit into any project, anywhere.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/jtoye-digital/project-standards/main/install-jtoye.sh | bash
#   OR
#   ./install-jtoye.sh [target-project-path]
#
# Options:
#   --symlink    Create symlink (only if _project_standards is nearby)
#   --copy       Copy scripts (default, works anywhere)
#   --update     Update existing installation
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Defaults
INSTALL_MODE="copy"
TARGET_DIR=""
SCRIPT_SOURCE=""
VERSION="2.1.0"

# GitHub raw URL (update this when you have a repo)
GITHUB_RAW_BASE="https://raw.githubusercontent.com/jtoye-digital/project-standards/main/.jtoye"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --symlink) INSTALL_MODE="symlink"; shift ;;
        --copy) INSTALL_MODE="copy"; shift ;;
        --update) INSTALL_MODE="update"; shift ;;
        --help|-h)
            echo "Usage: $0 [options] [target-project-path]"
            echo ""
            echo "Options:"
            echo "  --symlink    Create symlink to central _project_standards"
            echo "  --copy       Copy scripts into project (default)"
            echo "  --update     Update existing .jtoye installation"
            echo "  --help       Show this help"
            exit 0
            ;;
        -*) echo "Unknown option: $1"; exit 1 ;;
        *) TARGET_DIR="$1"; shift ;;
    esac
done

# Determine target directory
if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="$(pwd)"
fi

TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
    echo -e "${RED}Error: Target directory not found: $TARGET_DIR${NC}"
    exit 1
}

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║         J'TOYE DIGITAL - TOOLKIT INSTALLER v${VERSION}           ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Target: $TARGET_DIR${NC}"
echo -e "${BLUE}Mode:   $INSTALL_MODE${NC}"
echo ""

# Find the script source (where are WE running from?)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""

# Check for local _project_standards
find_local_source() {
    local search_paths=(
        "$SCRIPT_DIR/.jtoye"
        "$SCRIPT_DIR/../_project_standards/.jtoye"
        "$(dirname "$TARGET_DIR")/_project_standards/.jtoye"
        "$HOME/.jtoye-toolkit/.jtoye"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]] && [[ -f "$path/lib/jtoye-common.sh" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# Download from GitHub
download_from_github() {
    local dest="$1"
    
    echo -e "${BLUE}Downloading from GitHub...${NC}"
    
    # List of files to download
    local files=(
        "lib/jtoye-common.sh"
        "jtoye-audit"
        "jtoye-security"
        "jtoye-quality"
        "jtoye-coverage"
        "jtoye-architecture"
        "jtoye-docs"
        "jtoye-api"
        "jtoye-deps"
        "jtoye-performance"
        "jtoye-uiux"
        "jtoye-database"
        "jtoye-monitoring"
        "jtoye-conda"
        "jtoye-makefile"
        "README.md"
    )
    
    mkdir -p "$dest/lib"
    
    for file in "${files[@]}"; do
        local url="$GITHUB_RAW_BASE/$file"
        local target="$dest/$file"
        
        if curl -sSL -f "$url" -o "$target" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Downloaded $file"
        else
            echo -e "  ${YELLOW}⚠${NC} Failed to download $file (may not exist yet)"
        fi
    done
    
    # Make scripts executable
    chmod +x "$dest"/jtoye-* 2>/dev/null || true
}

# Copy from local source
copy_from_local() {
    local source="$1"
    local dest="$2"
    
    echo -e "${BLUE}Copying from local source: $source${NC}"
    
    mkdir -p "$dest/lib"
    
    # Copy all files
    cp -r "$source"/* "$dest/" 2>/dev/null || true
    
    # Make scripts executable
    chmod +x "$dest"/jtoye-* 2>/dev/null || true
    
    echo -e "${GREEN}✓ Copied .jtoye toolkit${NC}"
}

# Create symlink
create_symlink() {
    local source="$1"
    local dest="$2"
    
    # Calculate relative path
    local rel_source
    rel_source=$(realpath --relative-to="$(dirname "$dest")" "$source" 2>/dev/null) || {
        echo -e "${RED}Error: Cannot create relative symlink${NC}"
        return 1
    }
    
    ln -sfn "$rel_source" "$dest"
    echo -e "${GREEN}✓ Created symlink: .jtoye → $rel_source${NC}"
}

# Main installation logic
DEST_PATH="$TARGET_DIR/.jtoye"

# Check if already installed
if [[ -d "$DEST_PATH" ]] || [[ -L "$DEST_PATH" ]]; then
    if [[ "$INSTALL_MODE" != "update" ]]; then
        echo -e "${YELLOW}⚠ .jtoye already exists at $TARGET_DIR${NC}"
        read -p "  Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
    rm -rf "$DEST_PATH"
fi

# Find source
LOCAL_SOURCE=$(find_local_source) || LOCAL_SOURCE=""

case $INSTALL_MODE in
    symlink)
        if [[ -n "$LOCAL_SOURCE" ]]; then
            create_symlink "$LOCAL_SOURCE" "$DEST_PATH"
        else
            echo -e "${RED}Error: Cannot create symlink - no local _project_standards found${NC}"
            echo -e "${YELLOW}Hint: Use --copy mode or ensure _project_standards is in parent directory${NC}"
            exit 1
        fi
        ;;
    copy|update)
        if [[ -n "$LOCAL_SOURCE" ]]; then
            copy_from_local "$LOCAL_SOURCE" "$DEST_PATH"
        else
            echo -e "${YELLOW}No local source found, attempting GitHub download...${NC}"
            download_from_github "$DEST_PATH"
        fi
        ;;
esac

# Verify installation
echo ""
if [[ -f "$DEST_PATH/lib/jtoye-common.sh" ]]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✓ INSTALLATION SUCCESSFUL                        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Installed to: ${BLUE}$DEST_PATH${NC}"
    echo ""
    echo -e "${MAGENTA}Quick Start:${NC}"
    echo "  cd $TARGET_DIR"
    echo "  ./.jtoye/jtoye-audit .           # Full project audit"
    echo "  ./.jtoye/jtoye-audit . --quick   # Quick audit"
    echo "  ./.jtoye/jtoye-security .        # Security scan only"
    echo ""
    echo -e "${MAGENTA}Add to Makefile:${NC}"
    echo "  audit:"
    echo "      ./.jtoye/jtoye-audit ."
    echo ""
else
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              ✗ INSTALLATION FAILED                            ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
