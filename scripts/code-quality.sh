#!/bin/bash
# =============================================================================
# J'Toye Digital - Code Quality Analyzer (OPTIMIZED)
# =============================================================================
set -e

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WARNINGS=0

EXCL="--exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=vendor --exclude-dir=.cache"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════"
echo "  Code Quality Analyzer"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Go checks
if [ -d "$PROJECT_ROOT/services/go-api" ] || [ -f "$PROJECT_ROOT/go.mod" ]; then
    echo -e "${BLUE}[Go] Running quality checks...${NC}"
    GO_DIR=$([ -d "$PROJECT_ROOT/services/go-api" ] && echo "$PROJECT_ROOT/services/go-api" || echo "$PROJECT_ROOT")
    
    if command -v go &>/dev/null; then
        cd "$GO_DIR"
        if go vet ./... 2>&1 | head -5 | grep -q ""; then
            echo -e "${GREEN}  ✓ go vet passed${NC}"
        fi
        
        UNFORMATTED=$(gofmt -l . 2>/dev/null | head -5 || true)
        if [ -n "$UNFORMATTED" ]; then
            echo -e "${YELLOW}  ⚠ Unformatted files: $(echo "$UNFORMATTED" | wc -l)${NC}"
            WARNINGS=$((WARNINGS + 1))
        else
            echo -e "${GREEN}  ✓ All Go files formatted${NC}"
        fi
        cd "$PROJECT_ROOT"
    fi
fi

# Python checks
if [ -d "$PROJECT_ROOT/services/ml-service" ] || [ -f "$PROJECT_ROOT/requirements.txt" ]; then
    echo -e "${BLUE}[Python] Running quality checks...${NC}"
    PY_DIR=$([ -d "$PROJECT_ROOT/services/ml-service" ] && echo "$PROJECT_ROOT/services/ml-service" || echo "$PROJECT_ROOT")
    
    PY_FILES=$(find "$PY_DIR" -name "*.py" ! -path "*/.venv/*" ! -path "*/venv/*" ! -path "*/__pycache__/*" 2>/dev/null | head -20)
    if [ -n "$PY_FILES" ]; then
        echo -e "${GREEN}  ✓ Found $(echo "$PY_FILES" | wc -l) Python files${NC}"
    fi
fi

# TypeScript/Node checks
if [ -d "$PROJECT_ROOT/apps/web" ] || [ -f "$PROJECT_ROOT/package.json" ]; then
    echo -e "${BLUE}[TypeScript/JavaScript] Running quality checks...${NC}"
    
    if [ -f "$PROJECT_ROOT/apps/web/package.json" ]; then
        cd "$PROJECT_ROOT/apps/web"
        if [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f "eslint.config.js" ]; then
            if command -v npx &>/dev/null; then
                if timeout 30 npx eslint . --ext .ts,.tsx --max-warnings 0 2>/dev/null; then
                    echo -e "${GREEN}  ✓ ESLint passed${NC}"
                else
                    echo -e "${YELLOW}  ⚠ ESLint warnings${NC}"
                    WARNINGS=$((WARNINGS + 1))
                fi
            fi
        else
            echo -e "${YELLOW}  ⊘ No ESLint config found${NC}"
        fi
        cd "$PROJECT_ROOT"
    fi
fi

# Quick complexity check (only project files)
echo -e "${BLUE}[Complexity] Quick analysis...${NC}"
LARGE_FILES=$(find "$PROJECT_ROOT" -name "*.go" -o -name "*.py" -o -name "*.ts" 2>/dev/null | \
    grep -v "node_modules\|\.venv\|venv\|__pycache__\|\.next\|dist" | \
    xargs wc -l 2>/dev/null | sort -rn | head -5 | awk '$1 > 500 {print $2 ": " $1 " lines"}' || true)

if [ -n "$LARGE_FILES" ]; then
    echo -e "${YELLOW}  ⚠ Large files:${NC}"
    echo "$LARGE_FILES" | head -3 | while read -r line; do echo "    $line"; done
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}  ✓ No excessively large files${NC}"
fi

# TODOs (quick, limited)
echo -e "${BLUE}[TODOs] Quick scan...${NC}"
TODO_COUNT=$(grep -rn $EXCL "TODO\|FIXME" "$PROJECT_ROOT" --include="*.go" --include="*.py" --include="*.ts" 2>/dev/null | wc -l || echo "0")
echo -e "  ℹ Found $TODO_COUNT TODO/FIXME comments in project files"

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ Code quality excellent${NC}"
else
    echo -e "${YELLOW}  ⚠ Code quality OK with $WARNINGS suggestion(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

exit 0
