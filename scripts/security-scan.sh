#!/bin/bash
# =============================================================================
# J'Toye Digital - Security Scanner (OPTIMIZED)
# =============================================================================
set -e

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
ERRORS=0
WARNINGS=0

# Exclusion flags for grep - CRITICAL for performance
EXCL="--exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=vendor --exclude-dir=.cache"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════"
echo "  Security Scanner"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. Hardcoded secrets
echo -e "${BLUE}[1/6] Scanning for hardcoded secrets...${NC}"
SECRETS=$(grep -rn $EXCL -E "(password|secret|api_key|apikey|token)\s*[:=]\s*[\"'][^\"']{8,}" "$PROJECT_ROOT" --include="*.go" --include="*.py" --include="*.ts" --include="*.js" --include="*.json" 2>/dev/null | grep -v "example\|test\|mock\|sample\|placeholder\|your-\|changeme\|xxx" | head -5 || true)

if [ -n "$SECRETS" ]; then
    echo -e "${YELLOW}  ⚠ Potential secrets found:${NC}"
    echo "$SECRETS" | head -3 | while read -r line; do
        echo "    $(echo "$line" | cut -d: -f1-2)"
    done
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}  ✓ No obvious hardcoded secrets${NC}"
fi

# 2. Exposed .env files
echo -e "${BLUE}[2/6] Checking for exposed .env files...${NC}"
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    if grep -q "\.env" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
        echo -e "${GREEN}  ✓ .env files are in .gitignore${NC}"
    else
        echo -e "${RED}  ✗ .env not in .gitignore${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

ENV_TRACKED=$(git -C "$PROJECT_ROOT" ls-files "*.env" ".env*" 2>/dev/null | grep -v ".example\|.sample" | head -3 || true)
if [ -n "$ENV_TRACKED" ]; then
    echo -e "${RED}  ✗ .env files tracked in git: $ENV_TRACKED${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}  ✓ No .env files tracked in git${NC}"
fi

# 3. Insecure defaults
echo -e "${BLUE}[3/6] Checking for insecure defaults...${NC}"
INSECURE=$(grep -rn $EXCL -iE "insecure.*=.*true|verify.*=.*false|skip.*ssl|disable.*tls" "$PROJECT_ROOT" --include="*.go" --include="*.py" --include="*.ts" --include="*.yml" --include="*.yaml" 2>/dev/null | grep -v "test\|mock\|example" | head -3 || true)

if [ -n "$INSECURE" ]; then
    echo -e "${YELLOW}  ⚠ Potentially insecure patterns:${NC}"
    echo "$INSECURE" | head -2 | while read -r line; do
        echo "    $(echo "$line" | cut -d: -f1-2)"
    done
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}  ✓ No insecure defaults found${NC}"
fi

# 4. Dependency vulnerabilities (npm only, fast)
echo -e "${BLUE}[4/6] Checking dependencies...${NC}"
if [ -f "$PROJECT_ROOT/package-lock.json" ] && command -v npm &>/dev/null; then
    AUDIT=$(cd "$PROJECT_ROOT" && timeout 30 npm audit --json 2>/dev/null || true)
    if echo "$AUDIT" | grep -qE '"(high|critical)":[1-9]'; then
        echo -e "${RED}  ✗ npm: Critical vulnerabilities found${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}  ✓ npm: No critical vulnerabilities${NC}"
    fi
else
    echo -e "${YELLOW}  ⊘ npm audit skipped (no package-lock.json)${NC}"
fi

# 5. Security configs
echo -e "${BLUE}[5/6] Checking security configurations...${NC}"
SEC_HEADERS=$(grep -rn $EXCL -E "helmet|CORS|csrf|XSS|Content-Security-Policy" "$PROJECT_ROOT" --include="*.go" --include="*.ts" --include="*.js" 2>/dev/null | head -1 || true)
if [ -n "$SEC_HEADERS" ]; then
    echo -e "${GREEN}  ✓ Security headers/middleware found${NC}"
else
    echo -e "${YELLOW}  ⚠ No security middleware detected${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 6. Sensitive files
echo -e "${BLUE}[6/6] Checking for sensitive files...${NC}"
SENSITIVE=$(git -C "$PROJECT_ROOT" ls-files "*.pem" "*.key" "*credentials*" "*.p12" 2>/dev/null | head -3 || true)
if [ -n "$SENSITIVE" ]; then
    echo -e "${RED}  ✗ Sensitive files in git: $SENSITIVE${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}  ✓ No sensitive files tracked${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ Security scan passed${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}  ⚠ Security OK with $WARNINGS warning(s)${NC}"
else
    echo -e "${RED}  ✗ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

[ $ERRORS -gt 0 ] && exit 1
exit 0
