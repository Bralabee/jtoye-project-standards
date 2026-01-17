#!/bin/bash
# =============================================================================
# J'Toye Digital - Full Project Audit
# =============================================================================
# Runs ALL validation and quality scripts in sequence.
# This is the comprehensive health check for any project.
#
# Usage: ./scripts/full-audit.sh [--fix] [--ci] [--no-lock]
#   --fix      Attempt to auto-fix issues where possible
#   --ci       Run in CI mode (stricter, no prompts)
#   --no-lock  Skip lock file (allow concurrent runs)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STANDARDS_DIR="${PROJECT_STANDARDS_DIR:-$SCRIPT_DIR}"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "ERROR: common.sh not found" >&2
    exit 1
fi

# Setup help
setup_help "Comprehensive project health check that runs all validation and quality scripts"
add_help_option "--fix       Attempt to auto-fix issues where possible"
add_help_option "--ci        Run in CI mode (stricter, no prompts)"
add_help_option "--no-lock   Skip lock file (allow concurrent runs)"
handle_help "$@"

# Options
FIX_MODE=false
CI_MODE=false
NO_LOCK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_MODE=true
            shift
            ;;
        --ci)
            CI_MODE=true
            shift
            ;;
        --no-lock)
            NO_LOCK=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Acquire lock unless disabled
if [[ "$NO_LOCK" != "true" ]]; then
    if ! acquire_lock "full-audit"; then
        exit 1
    fi
fi

cd "$PROJECT_ROOT"

# Track results
declare -A RESULTS
TOTAL_ERRORS=0
TOTAL_WARNINGS=0

echo ""
echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║           J'TOYE DIGITAL - FULL PROJECT AUDIT                 ║${NC}"
echo -e "${MAGENTA}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${MAGENTA}║  Project: $(printf '%-49s' "$(basename "$PROJECT_ROOT")")║${NC}"
echo -e "${MAGENTA}║  Date:    $(printf '%-49s' "$(date '+%Y-%m-%d %H:%M:%S')")║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to run a check
run_check() {
    local name="$1"
    local script="$2"
    local required="$3"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Running: $name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -f "$script" ]; then
        chmod +x "$script"
        if "$script"; then
            RESULTS["$name"]="✓ PASS"
            echo ""
            echo -e "${GREEN}  ══► $name: PASSED${NC}"
        else
            RESULTS["$name"]="✗ FAIL"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
            echo ""
            echo -e "${RED}  ══► $name: FAILED${NC}"
            
            if [ "$CI_MODE" = true ] && [ "$required" = "required" ]; then
                echo -e "${RED}  CI mode: Stopping on required check failure${NC}"
                exit 1
            fi
        fi
    else
        RESULTS["$name"]="⊘ SKIP"
        echo -e "${YELLOW}  Script not found: $script${NC}"
    fi
    
    echo ""
}

# =============================================================================
# Run All Checks
# =============================================================================

# 1. Project Validation (version, required files)
run_check "Project Validation" "$SCRIPT_DIR/validate-project.sh" "required"

# 2. Security Scan
if [ -f "$STANDARDS_DIR/security-scan.sh" ]; then
    run_check "Security Scan" "$STANDARDS_DIR/security-scan.sh" "required"
elif [ -f "$SCRIPT_DIR/security-scan.sh" ]; then
    run_check "Security Scan" "$SCRIPT_DIR/security-scan.sh" "required"
fi

# 3. Code Quality
if [ -f "$STANDARDS_DIR/code-quality.sh" ]; then
    run_check "Code Quality" "$STANDARDS_DIR/code-quality.sh" "recommended"
elif [ -f "$SCRIPT_DIR/code-quality.sh" ]; then
    run_check "Code Quality" "$SCRIPT_DIR/code-quality.sh" "recommended"
fi

# 4. Architecture Check
if [ -f "$STANDARDS_DIR/architecture-check.sh" ]; then
    run_check "Architecture" "$STANDARDS_DIR/architecture-check.sh" "recommended"
elif [ -f "$SCRIPT_DIR/architecture-check.sh" ]; then
    run_check "Architecture" "$SCRIPT_DIR/architecture-check.sh" "recommended"
fi

# 5. Test Coverage
if [ -f "$STANDARDS_DIR/test-coverage.sh" ]; then
    run_check "Test Coverage" "$STANDARDS_DIR/test-coverage.sh" "recommended"
elif [ -f "$SCRIPT_DIR/test-coverage.sh" ]; then
    run_check "Test Coverage" "$SCRIPT_DIR/test-coverage.sh" "recommended"
fi

# 6. Documentation
if [ -f "$STANDARDS_DIR/docs-validator.sh" ]; then
    run_check "Documentation" "$STANDARDS_DIR/docs-validator.sh" "optional"
elif [ -f "$SCRIPT_DIR/docs-validator.sh" ]; then
    run_check "Documentation" "$SCRIPT_DIR/docs-validator.sh" "optional"
fi

# 7. API Contract Validation
if [ -f "$STANDARDS_DIR/api-contract.sh" ]; then
    run_check "API Contract" "$STANDARDS_DIR/api-contract.sh" "recommended"
elif [ -f "$SCRIPT_DIR/api-contract.sh" ]; then
    run_check "API Contract" "$SCRIPT_DIR/api-contract.sh" "recommended"
fi

# 8. Dependency Health
if [ -f "$STANDARDS_DIR/dependency-health.sh" ]; then
    run_check "Dependency Health" "$STANDARDS_DIR/dependency-health.sh" "recommended"
elif [ -f "$SCRIPT_DIR/dependency-health.sh" ]; then
    run_check "Dependency Health" "$SCRIPT_DIR/dependency-health.sh" "recommended"
fi

# 9. Performance Checks
if [ -f "$STANDARDS_DIR/performance-check.sh" ]; then
    run_check "Performance" "$STANDARDS_DIR/performance-check.sh" "optional"
elif [ -f "$SCRIPT_DIR/performance-check.sh" ]; then
    run_check "Performance" "$SCRIPT_DIR/performance-check.sh" "optional"
fi

# 10. UI/UX Validation
if [ -f "$STANDARDS_DIR/ui-ux-check.sh" ]; then
    run_check "UI/UX" "$STANDARDS_DIR/ui-ux-check.sh" "optional"
elif [ -f "$SCRIPT_DIR/ui-ux-check.sh" ]; then
    run_check "UI/UX" "$SCRIPT_DIR/ui-ux-check.sh" "optional"
fi

# 11. Database Schema
if [ -f "$STANDARDS_DIR/database-check.sh" ]; then
    run_check "Database Schema" "$STANDARDS_DIR/database-check.sh" "recommended"
elif [ -f "$SCRIPT_DIR/database-check.sh" ]; then
    run_check "Database Schema" "$SCRIPT_DIR/database-check.sh" "recommended"
fi

# 12. Monitoring & Observability
if [ -f "$STANDARDS_DIR/monitoring-check.sh" ]; then
    run_check "Monitoring" "$STANDARDS_DIR/monitoring-check.sh" "optional"
elif [ -f "$SCRIPT_DIR/monitoring-check.sh" ]; then
    run_check "Monitoring" "$SCRIPT_DIR/monitoring-check.sh" "optional"
fi

# 13. Conda Environment (Python projects)
if [ -f "$STANDARDS_DIR/conda-env-check.sh" ]; then
    run_check "Conda Environment" "$STANDARDS_DIR/conda-env-check.sh" "recommended"
elif [ -f "$SCRIPT_DIR/conda-env-check.sh" ]; then
    run_check "Conda Environment" "$SCRIPT_DIR/conda-env-check.sh" "recommended"
fi

# 14. Makefile Check
if [ -f "$STANDARDS_DIR/makefile-check.sh" ]; then
    run_check "Makefile" "$STANDARDS_DIR/makefile-check.sh" "recommended"
elif [ -f "$SCRIPT_DIR/makefile-check.sh" ]; then
    run_check "Makefile" "$SCRIPT_DIR/makefile-check.sh" "recommended"
fi

# =============================================================================
# Summary Report
# =============================================================================

echo ""
echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                     AUDIT SUMMARY                             ║${NC}"
echo -e "${MAGENTA}╠═══════════════════════════════════════════════════════════════╣${NC}"

for check in "Project Validation" "Security Scan" "Code Quality" "Architecture" "Test Coverage" "Documentation" "API Contract" "Dependency Health" "Performance" "UI/UX" "Database Schema" "Monitoring" "Conda Environment" "Makefile"; do
    result="${RESULTS[$check]:-⊘ SKIP}"
    
    if [[ "$result" == *"PASS"* ]]; then
        echo -e "${MAGENTA}║${NC}  ${GREEN}$result${NC}  $(printf '%-47s' "$check")${MAGENTA}║${NC}"
    elif [[ "$result" == *"FAIL"* ]]; then
        echo -e "${MAGENTA}║${NC}  ${RED}$result${NC}  $(printf '%-47s' "$check")${MAGENTA}║${NC}"
    else
        echo -e "${MAGENTA}║${NC}  ${YELLOW}$result${NC}  $(printf '%-47s' "$check")${MAGENTA}║${NC}"
    fi
done

echo -e "${MAGENTA}╠═══════════════════════════════════════════════════════════════╣${NC}"

if [ $TOTAL_ERRORS -eq 0 ]; then
    echo -e "${MAGENTA}║${NC}  ${GREEN}✓ ALL CHECKS PASSED${NC}                                       ${MAGENTA}║${NC}"
    FINAL_STATUS="HEALTHY"
else
    echo -e "${MAGENTA}║${NC}  ${RED}✗ $TOTAL_ERRORS CHECK(S) FAILED${NC}                                      ${MAGENTA}║${NC}"
    FINAL_STATUS="NEEDS ATTENTION"
fi

echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# Recommendations
# =============================================================================

if [ $TOTAL_ERRORS -gt 0 ]; then
    echo -e "${YELLOW}Recommended actions:${NC}"
    echo "  1. Review failed checks above"
    echo "  2. Run individual scripts for details:"
    echo "     ./scripts/validate-project.sh"
    echo "     ./scripts/security-scan.sh"
    echo "  3. Fix issues and re-run: ./scripts/full-audit.sh"
    echo ""
fi

# Exit code
if [ $TOTAL_ERRORS -gt 0 ]; then
    exit 1
fi
exit 0
