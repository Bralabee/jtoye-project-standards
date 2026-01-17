#!/bin/bash
# =============================================================================
# J'Toye Digital - Test Coverage Analyzer
# =============================================================================
# Analyzes test coverage across all services and identifies gaps:
# - Files without corresponding tests
# - Functions/methods without tests
# - Coverage below thresholds
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Thresholds (can be overridden in project-config.sh)
GO_COVERAGE_THRESHOLD=${GO_COVERAGE_THRESHOLD:-60}
PYTHON_COVERAGE_THRESHOLD=${PYTHON_COVERAGE_THRESHOLD:-50}
NODE_COVERAGE_THRESHOLD=${NODE_COVERAGE_THRESHOLD:-40}

cd "$PROJECT_ROOT"

# Load project config if exists
[ -f "scripts/project-config.sh" ] && source "scripts/project-config.sh"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test Coverage Analyzer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

ISSUES=0

# -----------------------------------------------------------------------------
# 1. Find Files Without Tests
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/4] Finding source files without tests...${NC}"

# Go files without tests
GO_FILES=$(find . -name "*.go" -not -name "*_test.go" -not -path "*/vendor/*" -not -path "*/.git/*" -not -name "mock_*.go" -not -name "*_mock.go" 2>/dev/null || true)
GO_MISSING_TESTS=0

for file in $GO_FILES; do
    TEST_FILE="${file%.go}_test.go"
    DIR=$(dirname "$file")
    BASENAME=$(basename "$file" .go)
    
    # Skip main.go, cmd files, and generated files
    if [[ "$BASENAME" == "main" ]] || [[ "$file" == *"/cmd/"* ]] || [[ "$file" == *"_gen.go" ]]; then
        continue
    fi
    
    # Check for test file
    if [ ! -f "$TEST_FILE" ]; then
        # Check for any test in the same directory that might test this file
        DIR_TESTS=$(find "$DIR" -maxdepth 1 -name "*_test.go" 2>/dev/null | wc -l)
        if [ "$DIR_TESTS" -eq 0 ]; then
            echo -e "${YELLOW}  ⚠ No tests: $file${NC}"
            GO_MISSING_TESTS=$((GO_MISSING_TESTS + 1))
        fi
    fi
done

if [ $GO_MISSING_TESTS -gt 0 ]; then
    echo -e "${YELLOW}  → $GO_MISSING_TESTS Go files may need tests${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}  ✓ Go files have test coverage${NC}"
fi

# Python files without tests
PY_FILES=$(find . -name "*.py" -not -name "test_*.py" -not -name "*_test.py" -not -path "*/venv/*" -not -path "*/.venv/*" -not -path "*/__pycache__/*" -not -path "*/.git/*" -not -name "conftest.py" -not -name "__init__.py" 2>/dev/null || true)
PY_MISSING_TESTS=0

for file in $PY_FILES; do
    DIR=$(dirname "$file")
    BASENAME=$(basename "$file" .py)
    
    # Skip migration files, config files
    if [[ "$file" == *"/migrations/"* ]] || [[ "$BASENAME" == "config" ]] || [[ "$BASENAME" == "settings" ]]; then
        continue
    fi
    
    # Check for test file
    TEST_FILE1="$DIR/test_${BASENAME}.py"
    TEST_FILE2="$DIR/${BASENAME}_test.py"
    TEST_DIR="$DIR/tests/test_${BASENAME}.py"
    
    if [ ! -f "$TEST_FILE1" ] && [ ! -f "$TEST_FILE2" ] && [ ! -f "$TEST_DIR" ]; then
        echo -e "${YELLOW}  ⚠ No tests: $file${NC}"
        PY_MISSING_TESTS=$((PY_MISSING_TESTS + 1))
    fi
done

if [ $PY_MISSING_TESTS -gt 0 ]; then
    echo -e "${YELLOW}  → $PY_MISSING_TESTS Python files may need tests${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}  ✓ Python files have test coverage${NC}"
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Run Coverage Analysis
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[2/4] Running coverage analysis...${NC}"

# Go coverage
GO_MOD_DIRS=$(find . -name "go.mod" -not -path "*/vendor/*" -exec dirname {} \; 2>/dev/null || true)
for dir in $GO_MOD_DIRS; do
    if [ -n "$(find "$dir" -name "*_test.go" 2>/dev/null)" ]; then
        echo "  Analyzing $dir..."
        COVERAGE=$(cd "$dir" && go test -cover ./... 2>/dev/null | grep -E "coverage:" | awk '{sum += $2; count++} END {if(count>0) print sum/count; else print 0}' | tr -d '%' || echo "0")
        COVERAGE_INT=${COVERAGE%.*}
        
        if [ -n "$COVERAGE_INT" ] && [ "$COVERAGE_INT" -lt "$GO_COVERAGE_THRESHOLD" ]; then
            echo -e "${RED}  ✗ $dir: ${COVERAGE_INT}% (threshold: ${GO_COVERAGE_THRESHOLD}%)${NC}"
            ISSUES=$((ISSUES + 1))
        else
            echo -e "${GREEN}  ✓ $dir: ${COVERAGE_INT:-0}%${NC}"
        fi
    fi
done

# Python coverage
if command -v pytest &> /dev/null && [ -f "requirements.txt" ] || [ -d "services/ml-service" ]; then
    PY_DIRS=$(find . -name "pytest.ini" -o -name "pyproject.toml" -o -name "setup.py" 2>/dev/null | xargs -I {} dirname {} | sort -u || true)
    for dir in $PY_DIRS; do
        if [ -d "$dir/tests" ] || find "$dir" -name "test_*.py" 2>/dev/null | grep -q .; then
            echo "  Analyzing $dir..."
            COVERAGE=$(cd "$dir" && pytest --cov --cov-report=term-missing 2>/dev/null | grep "TOTAL" | awk '{print $NF}' | tr -d '%' || echo "0")
            COVERAGE_INT=${COVERAGE%.*}
            
            if [ -n "$COVERAGE_INT" ] && [ "$COVERAGE_INT" -lt "$PYTHON_COVERAGE_THRESHOLD" ]; then
                echo -e "${RED}  ✗ $dir: ${COVERAGE_INT}% (threshold: ${PYTHON_COVERAGE_THRESHOLD}%)${NC}"
                ISSUES=$((ISSUES + 1))
            else
                echo -e "${GREEN}  ✓ $dir: ${COVERAGE_INT:-N/A}%${NC}"
            fi
        fi
    done
fi

echo ""

# -----------------------------------------------------------------------------
# 3. Check Test Organization
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[3/4] Checking test organization...${NC}"

# Check for test utilities/helpers
if find . -name "*_test.go" 2>/dev/null | grep -q .; then
    if find . -name "testutil*.go" -o -name "test_helper*.go" -o -name "fixtures*.go" 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✓ Test utilities found${NC}"
    else
        echo -e "${YELLOW}  ⚠ Consider creating shared test utilities${NC}"
    fi
fi

# Check for test fixtures/data
if [ -d "testdata" ] || [ -d "fixtures" ] || [ -d "tests/fixtures" ]; then
    echo -e "${GREEN}  ✓ Test fixtures directory found${NC}"
else
    echo -e "${YELLOW}  ⚠ Consider creating a testdata/ or fixtures/ directory${NC}"
fi

# Check for integration tests
if find . -name "*integration*test*" -o -name "*e2e*" 2>/dev/null | grep -q .; then
    echo -e "${GREEN}  ✓ Integration/E2E tests found${NC}"
else
    echo -e "${YELLOW}  ⚠ No integration or E2E tests detected${NC}"
fi

echo ""

# -----------------------------------------------------------------------------
# 4. Generate Coverage Report
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[4/4] Coverage summary...${NC}"

echo ""
echo "  Recommended actions:"
if [ $GO_MISSING_TESTS -gt 0 ]; then
    echo "  - Add tests for $GO_MISSING_TESTS Go files"
fi
if [ $PY_MISSING_TESTS -gt 0 ]; then
    echo "  - Add tests for $PY_MISSING_TESTS Python files"
fi
echo "  - Run: go test -coverprofile=coverage.out ./..."
echo "  - Run: pytest --cov --cov-report=html"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}  ✓ Test coverage looks good!${NC}"
else
    echo -e "${YELLOW}  ⚠ Found $ISSUES coverage issue(s) to address${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
