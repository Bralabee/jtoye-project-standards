#!/bin/bash
# =============================================================================
# J'Toye Digital - Database Schema Checker (OPTIMIZED)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"
fi

# Setup help
setup_help "Check database migrations, schema consistency, and data integrity"
handle_help "$@"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WARNINGS=0

echo "═══════════════════════════════════════════════════════════════"
echo "  Database Schema Checker"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Find migrations directory
MIGRATIONS_DIR=""
[ -d "$PROJECT_ROOT/migrations" ] && MIGRATIONS_DIR="$PROJECT_ROOT/migrations"
[ -d "$PROJECT_ROOT/db/migrations" ] && MIGRATIONS_DIR="$PROJECT_ROOT/db/migrations"
[ -d "$PROJECT_ROOT/database/migrations" ] && MIGRATIONS_DIR="$PROJECT_ROOT/database/migrations"

# 1. Migration files
echo -e "${BLUE}[1/4] Checking migration files...${NC}"
if [ -n "$MIGRATIONS_DIR" ] && [ -d "$MIGRATIONS_DIR" ]; then
    MIGRATION_COUNT=$(find "$MIGRATIONS_DIR" -name "*.sql" -o -name "*.go" -o -name "*.py" 2>/dev/null | wc -l || echo "0")
    echo -e "${GREEN}  ✓ Found $MIGRATION_COUNT migration files${NC}"
    
    # Check numbering
    SQL_FILES=$(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | head -10 || true)
    if [ -n "$SQL_FILES" ]; then
        echo -e "${GREEN}  ✓ SQL migrations present${NC}"
    fi
else
    echo -e "${YELLOW}  ⊘ No migrations directory found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 2. Index usage
echo -e "${BLUE}[2/4] Checking for indexes...${NC}"
if [ -n "$MIGRATIONS_DIR" ]; then
    INDEXES=$(grep -rn "CREATE INDEX\|ADD INDEX\|idx_" "$MIGRATIONS_DIR" 2>/dev/null | wc -l || echo "0")
    if [ "$INDEXES" -gt 0 ]; then
        echo -e "${GREEN}  ✓ Index definitions found ($INDEXES)${NC}"
    else
        echo -e "${YELLOW}  ⚠ No index definitions found${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# 3. Foreign keys
echo -e "${BLUE}[3/4] Checking foreign keys...${NC}"
if [ -n "$MIGRATIONS_DIR" ]; then
    FK=$(grep -rn "FOREIGN KEY\|REFERENCES\|fk_" "$MIGRATIONS_DIR" 2>/dev/null | wc -l || echo "0")
    if [ "$FK" -gt 0 ]; then
        echo -e "${GREEN}  ✓ Foreign key constraints found ($FK)${NC}"
    else
        echo -e "${YELLOW}  ⚠ No foreign keys defined${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# 4. Schema documentation
echo -e "${BLUE}[4/4] Checking schema documentation...${NC}"
SCHEMA_DOC=$(find "$PROJECT_ROOT/docs" -name "*schema*" -o -name "*database*" -o -name "*erd*" 2>/dev/null | head -1 || true)
if [ -n "$SCHEMA_DOC" ]; then
    echo -e "${GREEN}  ✓ Schema documentation found${NC}"
else
    echo -e "${YELLOW}  ⚠ No schema documentation found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ Database schema looks good${NC}"
else
    echo -e "${YELLOW}  ⚠ Database OK with $WARNINGS suggestion(s)${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

exit 0
