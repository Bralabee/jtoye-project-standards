#!/bin/bash
# =============================================================================
# J'Toye Digital - API Contract Validator (OPTIMIZED)
# =============================================================================
set -e

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WARNINGS=0

EXCL="--exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=vendor"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════"
echo "  API Contract Validator"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. OpenAPI spec
echo -e "${BLUE}[1/3] Checking OpenAPI specification...${NC}"
OPENAPI=$(find "$PROJECT_ROOT" -maxdepth 3 \( -name "openapi*.yaml" -o -name "openapi*.json" -o -name "swagger*.yaml" \) 2>/dev/null | grep -v node_modules | head -1 || true)

if [ -n "$OPENAPI" ]; then
    echo -e "${GREEN}  ✓ OpenAPI spec found: $(basename "$OPENAPI")${NC}"
    
    # Check for version
    if grep -q "version:" "$OPENAPI" 2>/dev/null; then
        VERSION=$(grep "version:" "$OPENAPI" | head -1 | awk '{print $2}' | tr -d '"')
        echo -e "${GREEN}  ✓ API version: $VERSION${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ No OpenAPI/Swagger spec found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 2. Route extraction
echo -e "${BLUE}[2/3] Analyzing API routes...${NC}"

# Go routes
GO_ROUTES=$(grep -rn $EXCL -E '\.(Get|Post|Put|Delete|Patch)\(' "$PROJECT_ROOT" --include="*.go" 2>/dev/null | wc -l || echo "0")
if [ "$GO_ROUTES" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Go API routes: $GO_ROUTES${NC}"
fi

# Python/FastAPI routes
PY_ROUTES=$(grep -rn $EXCL -E '@(app|router)\.(get|post|put|delete|patch)' "$PROJECT_ROOT" --include="*.py" 2>/dev/null | wc -l || echo "0")
if [ "$PY_ROUTES" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Python API routes: $PY_ROUTES${NC}"
fi

# Node routes
NODE_ROUTES=$(grep -rn $EXCL -E '\.(get|post|put|delete|patch)\(' "$PROJECT_ROOT" --include="*.ts" --include="*.js" 2>/dev/null | grep -v "test\|spec" | wc -l || echo "0")
if [ "$NODE_ROUTES" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Node API routes: $NODE_ROUTES${NC}"
fi

TOTAL_ROUTES=$((GO_ROUTES + PY_ROUTES + NODE_ROUTES))
echo -e "  ℹ Total routes detected: $TOTAL_ROUTES"

# 3. Versioning check
echo -e "${BLUE}[3/3] Checking API versioning...${NC}"
VERSIONED=$(grep -rn $EXCL -E "/api/v[0-9]+\|/v[0-9]+/" "$PROJECT_ROOT" --include="*.go" --include="*.py" --include="*.ts" 2>/dev/null | head -1 || true)

if [ -n "$VERSIONED" ]; then
    echo -e "${GREEN}  ✓ API versioning in use${NC}"
else
    echo -e "${YELLOW}  ⚠ Consider API versioning (/api/v1/)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ API contract validated${NC}"
else
    echo -e "${YELLOW}  ⚠ API contract OK with $WARNINGS suggestion(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

exit 0
