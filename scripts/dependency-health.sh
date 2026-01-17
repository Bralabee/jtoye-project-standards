#!/bin/bash
# =============================================================================
# J'Toye Digital - Dependency Health Checker (OPTIMIZED)
# =============================================================================
set -e

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WARNINGS=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════"
echo "  Dependency Health Checker"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. Node.js dependencies
echo -e "${BLUE}[1/3] Checking Node.js dependencies...${NC}"
if [ -f "$PROJECT_ROOT/package.json" ]; then
    if command -v npm &>/dev/null; then
        OUTDATED=$(cd "$PROJECT_ROOT" && timeout 20 npm outdated --json 2>/dev/null | head -50 || true)
        if [ -n "$OUTDATED" ] && [ "$OUTDATED" != "{}" ]; then
            COUNT=$(echo "$OUTDATED" | grep -c '"wanted"' || echo "0")
            echo -e "${YELLOW}  ⚠ $COUNT outdated packages${NC}"
            WARNINGS=$((WARNINGS + 1))
        else
            echo -e "${GREEN}  ✓ npm packages up to date${NC}"
        fi
    fi
    
    # Lock file check
    if [ -f "$PROJECT_ROOT/package-lock.json" ]; then
        echo -e "${GREEN}  ✓ package-lock.json exists${NC}"
    else
        echo -e "${YELLOW}  ⚠ No package-lock.json${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}  ⊘ No package.json found${NC}"
fi

# 2. Python dependencies
echo -e "${BLUE}[2/3] Checking Python dependencies...${NC}"
REQ_FILE=""
[ -f "$PROJECT_ROOT/requirements.txt" ] && REQ_FILE="$PROJECT_ROOT/requirements.txt"
[ -f "$PROJECT_ROOT/services/ml-service/requirements.txt" ] && REQ_FILE="$PROJECT_ROOT/services/ml-service/requirements.txt"

if [ -n "$REQ_FILE" ]; then
    echo -e "${GREEN}  ✓ requirements.txt found${NC}"
    
    # Check for pinned versions
    UNPINNED=$(grep -E "^[a-zA-Z]" "$REQ_FILE" | grep -v "==" | wc -l || echo "0")
    if [ "$UNPINNED" -gt 0 ]; then
        echo -e "${YELLOW}  ⚠ $UNPINNED unpinned dependencies${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}  ✓ All dependencies pinned${NC}"
    fi
else
    echo -e "${YELLOW}  ⊘ No requirements.txt found${NC}"
fi

# 3. Go dependencies
echo -e "${BLUE}[3/3] Checking Go dependencies...${NC}"
GO_MOD=""
[ -f "$PROJECT_ROOT/go.mod" ] && GO_MOD="$PROJECT_ROOT/go.mod"
[ -f "$PROJECT_ROOT/services/go-api/go.mod" ] && GO_MOD="$PROJECT_ROOT/services/go-api/go.mod"

if [ -n "$GO_MOD" ]; then
    echo -e "${GREEN}  ✓ go.mod found${NC}"
    
    GO_DIR=$(dirname "$GO_MOD")
    if [ -f "$GO_DIR/go.sum" ]; then
        echo -e "${GREEN}  ✓ go.sum exists${NC}"
    else
        echo -e "${YELLOW}  ⚠ go.sum missing${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}  ⊘ No go.mod found${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ Dependencies healthy${NC}"
else
    echo -e "${YELLOW}  ⚠ Dependencies OK with $WARNINGS suggestion(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

exit 0
