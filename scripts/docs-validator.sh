#!/bin/bash
# =============================================================================
# J'Toye Digital - Documentation Validator (OPTIMIZED)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"
fi

# Setup help
setup_help "Validate project documentation including README, CHANGELOG, and API docs"
handle_help "$@"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WARNINGS=0
ERRORS=0

echo "═══════════════════════════════════════════════════════════════"
echo "  Documentation Validator"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. README check
echo -e "${BLUE}[1/4] Checking README...${NC}"
if [ -f "$PROJECT_ROOT/README.md" ]; then
    README_SIZE=$(wc -c < "$PROJECT_ROOT/README.md")
    if [ "$README_SIZE" -gt 500 ]; then
        echo -e "${GREEN}  ✓ README.md exists and has content${NC}"
        
        # Check for key sections
        for section in "install" "usage" "getting started"; do
            if grep -qi "$section" "$PROJECT_ROOT/README.md" 2>/dev/null; then
                echo -e "${GREEN}  ✓ Has '$section' section${NC}"
            fi
        done
    else
        echo -e "${YELLOW}  ⚠ README.md is sparse (< 500 bytes)${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${RED}  ✗ README.md missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 2. CHANGELOG check
echo -e "${BLUE}[2/4] Checking CHANGELOG...${NC}"
if [ -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
    CHANGELOG_SIZE=$(wc -c < "$PROJECT_ROOT/CHANGELOG.md")
    if [ "$CHANGELOG_SIZE" -gt 100 ]; then
        echo -e "${GREEN}  ✓ CHANGELOG.md exists${NC}"
    else
        echo -e "${YELLOW}  ⚠ CHANGELOG.md is empty${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}  ⚠ CHANGELOG.md missing${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 3. API documentation
echo -e "${BLUE}[3/4] Checking API documentation...${NC}"
API_DOCS=$(find "$PROJECT_ROOT/docs" -name "API*.md" -o -name "api*.md" 2>/dev/null | head -1 || true)
OPENAPI=$(find "$PROJECT_ROOT" -maxdepth 3 -name "openapi*.yaml" -o -name "swagger*.yaml" 2>/dev/null | grep -v node_modules | head -1 || true)

if [ -n "$API_DOCS" ] || [ -n "$OPENAPI" ]; then
    echo -e "${GREEN}  ✓ API documentation found${NC}"
else
    echo -e "${YELLOW}  ⚠ No API documentation found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 4. Architecture docs
echo -e "${BLUE}[4/4] Checking architecture docs...${NC}"
if [ -f "$PROJECT_ROOT/docs/ARCHITECTURE.md" ]; then
    echo -e "${GREEN}  ✓ ARCHITECTURE.md exists${NC}"
else
    echo -e "${YELLOW}  ⚠ docs/ARCHITECTURE.md missing${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ Documentation complete${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}  ⚠ Documentation OK with $WARNINGS suggestion(s)${NC}"
else
    echo -e "${RED}  ✗ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

[ $ERRORS -gt 0 ] && exit 1
exit 0
