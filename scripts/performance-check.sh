#!/bin/bash
# =============================================================================
# J'Toye Digital - Performance Checker (OPTIMIZED)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"
fi

# Setup help
setup_help "Check for performance issues including N+1 queries, missing pagination, and large files"
handle_help "$@"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WARNINGS=0

echo "═══════════════════════════════════════════════════════════════"
echo "  Performance Checker"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. N+1 query patterns
echo -e "${BLUE}[1/4] Checking for N+1 query patterns...${NC}"
N1_PATTERNS=$(grep -rn $EXCL -E "for.*{[^}]*\.(Query|Find|Select|Get)\(" "$PROJECT_ROOT" --include="*.go" --include="*.py" 2>/dev/null | head -3 || true)

if [ -n "$N1_PATTERNS" ]; then
    echo -e "${YELLOW}  ⚠ Potential N+1 patterns found:${NC}"
    echo "$N1_PATTERNS" | head -2 | while read -r line; do
        echo "    $(echo "$line" | cut -d: -f1-2)"
    done
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}  ✓ No obvious N+1 patterns${NC}"
fi

# 2. Missing pagination
echo -e "${BLUE}[2/4] Checking pagination...${NC}"
PAGINATION=$(grep -rn $EXCL -E "limit|offset|page|cursor" "$PROJECT_ROOT" --include="*.go" --include="*.py" --include="*.ts" 2>/dev/null | wc -l || echo "0")

if [ "$PAGINATION" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Pagination patterns found ($PAGINATION references)${NC}"
else
    echo -e "${YELLOW}  ⚠ No pagination detected${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 3. Large file detection
echo -e "${BLUE}[3/4] Checking for large source files...${NC}"
LARGE=$(find "$PROJECT_ROOT" \( -name "*.go" -o -name "*.py" -o -name "*.ts" \) \
    ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
    ! -path "*/__pycache__/*" ! -path "*/.next/*" ! -path "*/dist/*" \
    -exec wc -l {} \; 2>/dev/null | awk '$1 > 500 {print $1 " " $2}' | sort -rn | head -3 || true)

if [ -n "$LARGE" ]; then
    echo -e "${YELLOW}  ⚠ Large files (>500 lines):${NC}"
    echo "$LARGE" | while read -r line; do echo "    $line lines"; done
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}  ✓ No excessively large files${NC}"
fi

# 4. Caching usage
echo -e "${BLUE}[4/4] Checking caching patterns...${NC}"
CACHE=$(grep -rn $EXCL -E "cache|Cache|redis|Redis|memo|Memo" "$PROJECT_ROOT" --include="*.go" --include="*.py" --include="*.ts" 2>/dev/null | wc -l || echo "0")

if [ "$CACHE" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Caching patterns found ($CACHE references)${NC}"
else
    echo -e "${YELLOW}  ⚠ No caching detected - consider adding caching${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ Performance patterns look good${NC}"
else
    echo -e "${YELLOW}  ⚠ Performance OK with $WARNINGS suggestion(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

exit 0
