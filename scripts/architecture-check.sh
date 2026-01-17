#!/bin/bash
# =============================================================================
# J'Toye Digital - Architecture Validator (OPTIMIZED)
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
echo "  Architecture Validator"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. Go layer architecture
echo -e "${BLUE}[1/4] Checking Go layer architecture...${NC}"
if [ -d "$PROJECT_ROOT/services/go-api/internal" ]; then
    VIOLATIONS=$(grep -rn $EXCL 'internal/handlers' "$PROJECT_ROOT/services/go-api/internal/handlers" --include="*.go" 2>/dev/null | grep -v "_test.go" | head -3 || true)
    if [ -n "$VIOLATIONS" ]; then
        echo -e "${YELLOW}  ⚠ Potential layer violations in handlers${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}  ✓ Go layer architecture looks clean${NC}"
    fi
else
    echo -e "${YELLOW}  ⊘ No Go service found${NC}"
fi

# 2. Circular imports (quick check)
echo -e "${BLUE}[2/4] Checking for circular imports...${NC}"
if [ -d "$PROJECT_ROOT/services/ml-service" ]; then
    CIRCULAR=$(grep -rn $EXCL "from \.\." "$PROJECT_ROOT/services/ml-service/app" --include="*.py" 2>/dev/null | wc -l || echo "0")
    if [ "$CIRCULAR" -gt 10 ]; then
        echo -e "${YELLOW}  ⚠ Many relative imports ($CIRCULAR) - check for circular deps${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}  ✓ No obvious circular imports${NC}"
    fi
fi

# 3. Directory structure
echo -e "${BLUE}[3/4] Validating directory structure...${NC}"
REQUIRED_DIRS=()
[ -d "$PROJECT_ROOT/services/go-api" ] && REQUIRED_DIRS+=("services/go-api/cmd" "services/go-api/internal")
[ -d "$PROJECT_ROOT/apps/web" ] && REQUIRED_DIRS+=("apps/web/app" "apps/web/components")
[ -d "$PROJECT_ROOT/services/ml-service" ] && REQUIRED_DIRS+=("services/ml-service/app")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        echo -e "${GREEN}  ✓ $dir exists${NC}"
    else
        echo -e "${YELLOW}  ⚠ Missing: $dir${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# 4. API documentation
echo -e "${BLUE}[4/4] Checking API documentation...${NC}"
OPENAPI=$(find "$PROJECT_ROOT" -name "openapi*.yaml" -o -name "openapi*.json" -o -name "swagger*.yaml" 2>/dev/null | grep -v node_modules | head -1 || true)
if [ -n "$OPENAPI" ]; then
    echo -e "${GREEN}  ✓ OpenAPI spec found: $(basename "$OPENAPI")${NC}"
else
    echo -e "${YELLOW}  ⚠ No OpenAPI/Swagger spec found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ Architecture validated${NC}"
else
    echo -e "${YELLOW}  ⚠ Architecture OK with $WARNINGS suggestion(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

exit 0
