#!/bin/bash
# =============================================================================
# J'Toye Digital - Monitoring Checker (OPTIMIZED)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"
fi

# Setup help
setup_help "Check monitoring and observability configurations including health endpoints, metrics, and logging"
handle_help "$@"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WARNINGS=0

echo "═══════════════════════════════════════════════════════════════"
echo "  Monitoring & Observability Checker"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. Health endpoints
echo -e "${BLUE}[1/4] Checking health endpoints...${NC}"
HEALTH=$(grep -rn $EXCL -E '"/health"|"/ready"|"/live"|/health|/ready' "$PROJECT_ROOT" --include="*.go" --include="*.py" --include="*.ts" 2>/dev/null | wc -l || echo "0")

if [ "$HEALTH" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Health endpoints found ($HEALTH references)${NC}"
else
    echo -e "${YELLOW}  ⚠ No health endpoints detected${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Docker healthcheck
DOCKER_HEALTH=$(grep -rn "HEALTHCHECK\|healthcheck:" "$PROJECT_ROOT" --include="Dockerfile" --include="docker-compose*.yml" 2>/dev/null | wc -l || echo "0")
if [ "$DOCKER_HEALTH" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Docker health checks configured${NC}"
fi

# 2. Metrics
echo -e "${BLUE}[2/4] Checking metrics exposure...${NC}"
METRICS=$(grep -rn $EXCL -E "prometheus|/metrics|Counter|Gauge|Histogram" "$PROJECT_ROOT" --include="*.go" --include="*.py" 2>/dev/null | wc -l || echo "0")

if [ "$METRICS" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Metrics/Prometheus patterns found ($METRICS)${NC}"
else
    echo -e "${YELLOW}  ⚠ No metrics exposure detected${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 3. Logging
echo -e "${BLUE}[3/4] Checking logging...${NC}"
STRUCTURED=$(grep -rn $EXCL -E "zerolog|zap|logrus|slog|structlog" "$PROJECT_ROOT" --include="*.go" --include="*.py" 2>/dev/null | wc -l || echo "0")

if [ "$STRUCTURED" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Structured logging in use${NC}"
else
    BASIC_LOG=$(grep -rn $EXCL -E "log\.|logging\." "$PROJECT_ROOT" --include="*.go" --include="*.py" 2>/dev/null | wc -l || echo "0")
    if [ "$BASIC_LOG" -gt 0 ]; then
        echo -e "${YELLOW}  ⚠ Basic logging - consider structured logging${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# 4. Tracing
echo -e "${BLUE}[4/4] Checking distributed tracing...${NC}"
TRACING=$(grep -rn $EXCL -E "opentelemetry|otel|jaeger|Span|Tracer" "$PROJECT_ROOT" --include="*.go" --include="*.py" 2>/dev/null | wc -l || echo "0")

if [ "$TRACING" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Distributed tracing configured ($TRACING references)${NC}"
else
    echo -e "${YELLOW}  ⚠ No distributed tracing detected${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ Monitoring & observability excellent${NC}"
else
    echo -e "${YELLOW}  ⚠ Monitoring OK with $WARNINGS suggestion(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

exit 0
