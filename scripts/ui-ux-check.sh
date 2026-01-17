#!/bin/bash
# =============================================================================
# J'Toye Digital - UI/UX Checker (OPTIMIZED)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"
fi

# Setup help
setup_help "Check UI/UX best practices including accessibility, responsive design, and loading states"
handle_help "$@"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WARNINGS=0

echo "═══════════════════════════════════════════════════════════════"
echo "  UI/UX Checker"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Find frontend directory
FRONTEND_DIR=""
[ -d "$PROJECT_ROOT/apps/web" ] && FRONTEND_DIR="$PROJECT_ROOT/apps/web"
[ -d "$PROJECT_ROOT/frontend" ] && FRONTEND_DIR="$PROJECT_ROOT/frontend"
[ -d "$PROJECT_ROOT/src" ] && FRONTEND_DIR="$PROJECT_ROOT/src"

if [ -z "$FRONTEND_DIR" ]; then
    echo -e "${YELLOW}  ⊘ No frontend directory found${NC}"
    exit 0
fi

# 1. Accessibility - alt text
echo -e "${BLUE}[1/4] Checking accessibility...${NC}"
MISSING_ALT=$(grep -rn $EXCL "<img" "$FRONTEND_DIR" --include="*.tsx" --include="*.jsx" --include="*.html" 2>/dev/null | grep -v "alt=" | wc -l || echo "0")

if [ "$MISSING_ALT" -gt 0 ]; then
    echo -e "${YELLOW}  ⚠ $MISSING_ALT images may be missing alt text${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}  ✓ Images appear to have alt text${NC}"
fi

# Check for aria labels
ARIA=$(grep -rn $EXCL "aria-" "$FRONTEND_DIR" --include="*.tsx" --include="*.jsx" 2>/dev/null | wc -l || echo "0")
echo -e "  ℹ ARIA attributes found: $ARIA"

# 2. Form labels
echo -e "${BLUE}[2/4] Checking form accessibility...${NC}"
INPUTS=$(grep -rn $EXCL "<input\|<Input" "$FRONTEND_DIR" --include="*.tsx" --include="*.jsx" 2>/dev/null | wc -l || echo "0")
LABELS=$(grep -rn $EXCL "<label\|<Label\|htmlFor\|aria-label" "$FRONTEND_DIR" --include="*.tsx" --include="*.jsx" 2>/dev/null | wc -l || echo "0")

if [ "$INPUTS" -gt 0 ]; then
    RATIO=$((LABELS * 100 / INPUTS))
    if [ "$RATIO" -lt 50 ]; then
        echo -e "${YELLOW}  ⚠ Low label-to-input ratio ($RATIO%)${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}  ✓ Form labels look adequate ($RATIO%)${NC}"
    fi
fi

# 3. Loading states
echo -e "${BLUE}[3/4] Checking loading states...${NC}"
LOADING=$(grep -rn $EXCL -E "loading|isLoading|skeleton|Spinner|Loading" "$FRONTEND_DIR" --include="*.tsx" --include="*.jsx" 2>/dev/null | wc -l || echo "0")

if [ "$LOADING" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Loading states implemented ($LOADING references)${NC}"
else
    echo -e "${YELLOW}  ⚠ No loading states detected${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 4. Error handling in UI
echo -e "${BLUE}[4/4] Checking error handling...${NC}"
ERROR_UI=$(grep -rn $EXCL -E "error|Error|catch|toast|notification" "$FRONTEND_DIR" --include="*.tsx" --include="*.jsx" 2>/dev/null | wc -l || echo "0")

if [ "$ERROR_UI" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Error handling in UI ($ERROR_UI references)${NC}"
else
    echo -e "${YELLOW}  ⚠ Limited error handling in UI${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ UI/UX patterns look good${NC}"
else
    echo -e "${YELLOW}  ⚠ UI/UX OK with $WARNINGS suggestion(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

exit 0
