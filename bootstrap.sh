#!/bin/bash
# =============================================================================
# J'Toye Digital - Project Standards Bootstrap
# =============================================================================
# Initializes any project with standardized automation scripts.
#
# Usage:
#   ../_project_standards/bootstrap.sh [--type TYPE] [--force]
#
# Options:
#   --type TYPE   Project type: monorepo, python, go, node (default: auto-detect)
#   --force       Overwrite existing scripts
#   --dry-run     Show what would be done without making changes
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
PROJECT_TYPE=""
FORCE=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: bootstrap.sh [--type TYPE] [--force] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --type TYPE   Project type: monorepo, python, go, node"
            echo "  --force       Overwrite existing scripts"
            echo "  --dry-run     Show what would be done"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-detect project type if not specified
detect_project_type() {
    if [ -f "pnpm-workspace.yaml" ] || [ -f "turbo.json" ] || [ -f "lerna.json" ]; then
        echo "monorepo"
    elif [ -d "backend" ] && [ -d "frontend" ]; then
        # Multi-service project (like asao)
        echo "monorepo"
    elif [ -f "go.mod" ] && [ ! -f "package.json" ]; then
        echo "go"
    elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] && [ ! -f "package.json" ]; then
        echo "python"
    elif [ -f "package.json" ]; then
        echo "node"
    else
        echo "generic"
    fi
}

if [ -z "$PROJECT_TYPE" ]; then
    PROJECT_TYPE=$(detect_project_type)
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  J'Toye Digital - Project Standards Bootstrap${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Project: ${GREEN}$(basename "$PROJECT_DIR")${NC}"
echo -e "  Type:    ${GREEN}$PROJECT_TYPE${NC}"
echo -e "  Path:    $PROJECT_DIR"
echo ""

# Check if already initialized
if [ -f "scripts/validate-project.sh" ] && [ "$FORCE" = false ]; then
    echo -e "${YELLOW}⚠ Project already has validation scripts.${NC}"
    echo "  Use --force to overwrite."
    exit 1
fi

# Create directories
if [ "$DRY_RUN" = false ]; then
    mkdir -p scripts
    mkdir -p .github
fi

# -----------------------------------------------------------------------------
# Generate project-config.sh based on type
# -----------------------------------------------------------------------------
generate_config() {
    local config_content=""
    
    case $PROJECT_TYPE in
        monorepo)
            config_content='# Project Configuration
PROJECT_NAME="'"$(basename "$PROJECT_DIR")"'"
PROJECT_TYPE="monorepo"

# Files containing version (relative to project root)
VERSION_FILES=(
    "package.json"
    "apps/*/package.json"
    "services/*/package.json"
    "packages/*/package.json"
)

# JSON files with version field
JSON_VERSION_FILES=(
    "package.json"
    "apps/web/package.json"
)

# Manifest files (Chrome extensions, etc.)
MANIFEST_FILES=(
    "services/extension/manifest.json"
    "extension/manifest.json"
)

# Documentation files with version headers
DOC_VERSION_FILES=(
    "README.md"
    "docs/ARCHITECTURE.md"
    "docs/AI_INSTRUCTIONS.md"
    "PROJECT_REQUIREMENTS.md"
)

# Paths that should NOT exist in docs (stale references)
FORBIDDEN_DOC_PATHS=(
    "services/web"  # Should be apps/web
)

# Allowed exceptions (changelog mentions, etc.)
FORBIDDEN_PATH_EXCEPTIONS=(
    "→"
    "moved from"
    "not \`"
)

# Required files that must exist
REQUIRED_FILES=(
    "VERSION"
    "CHANGELOG.md"
    "README.md"
    ".env.example"
)

# Required environment variables in .env.example
REQUIRED_ENV_VARS=(
    "DATABASE_URL"
    "JWT_SECRET"
)
'
            ;;
        python)
            config_content='# Project Configuration
PROJECT_NAME="'"$(basename "$PROJECT_DIR")"'"
PROJECT_TYPE="python"

# Python version files
VERSION_FILES=(
    "setup.py"
    "pyproject.toml"
    "*/__version__.py"
    "*/version.py"
)

# Required files
REQUIRED_FILES=(
    "VERSION"
    "README.md"
    "requirements.txt"
    "setup.py"
)

# Required environment variables
REQUIRED_ENV_VARS=(
    "PYTHONPATH"
)

# Paths that should not appear in docs
FORBIDDEN_DOC_PATHS=()
FORBIDDEN_PATH_EXCEPTIONS=()
'
            ;;
        go)
            config_content='# Project Configuration
PROJECT_NAME="'"$(basename "$PROJECT_DIR")"'"
PROJECT_TYPE="go"

# Go version files (look for version constants)
VERSION_FILES=(
    "cmd/*/main.go"
    "internal/version/version.go"
    "version.go"
)

# Required files
REQUIRED_FILES=(
    "VERSION"
    "README.md"
    "go.mod"
    "go.sum"
)

# Required environment variables
REQUIRED_ENV_VARS=()

# Paths that should not appear in docs
FORBIDDEN_DOC_PATHS=()
FORBIDDEN_PATH_EXCEPTIONS=()
'
            ;;
        node)
            config_content='# Project Configuration
PROJECT_NAME="'"$(basename "$PROJECT_DIR")"'"
PROJECT_TYPE="node"

# Node version files
VERSION_FILES=(
    "package.json"
)

JSON_VERSION_FILES=(
    "package.json"
)

# Required files
REQUIRED_FILES=(
    "VERSION"
    "README.md"
    "package.json"
)

# Required environment variables
REQUIRED_ENV_VARS=()

# Paths that should not appear in docs
FORBIDDEN_DOC_PATHS=()
FORBIDDEN_PATH_EXCEPTIONS=()
'
            ;;
        *)
            config_content='# Project Configuration
PROJECT_NAME="'"$(basename "$PROJECT_DIR")"'"
PROJECT_TYPE="generic"

# Version files to sync
VERSION_FILES=()

# Required files
REQUIRED_FILES=(
    "VERSION"
    "README.md"
)

# Required environment variables
REQUIRED_ENV_VARS=()

# Paths that should not appear in docs
FORBIDDEN_DOC_PATHS=()
FORBIDDEN_PATH_EXCEPTIONS=()
'
            ;;
    esac
    
    echo "$config_content"
}

# -----------------------------------------------------------------------------
# Generate sync-version.sh
# -----------------------------------------------------------------------------
generate_sync_version() {
    cat << 'SYNC_EOF'
#!/bin/bash
# =============================================================================
# Version Sync Script
# =============================================================================
# Reads version from VERSION file and updates all configured components.
#
# Usage: ./scripts/sync-version.sh [new-version]
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
source "$SCRIPT_DIR/project-config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$PROJECT_ROOT"

# Get or set version
if [ -n "$1" ]; then
    NEW_VERSION="$1"
    echo "$NEW_VERSION" > VERSION
    echo -e "${GREEN}✓ Updated VERSION file to $NEW_VERSION${NC}"
else
    if [ ! -f VERSION ]; then
        echo "0.1.0" > VERSION
        echo -e "${YELLOW}Created VERSION file with 0.1.0${NC}"
    fi
    NEW_VERSION=$(cat VERSION | tr -d '[:space:]')
fi

echo -e "${YELLOW}Syncing version $NEW_VERSION across project...${NC}"
echo ""

# Update JSON files
update_json_version() {
    local file="$1"
    if [ -f "$file" ]; then
        if command -v jq &> /dev/null; then
            jq --arg v "$NEW_VERSION" '.version = $v' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        else
            sed -i 's/"version": "[^"]*"/"version": "'"$NEW_VERSION"'"/' "$file"
        fi
        echo -e "${GREEN}✓ $file${NC}"
    fi
}

# Update Markdown version headers
update_md_version() {
    local file="$1"
    if [ -f "$file" ]; then
        sed -i 's/\*\*Version\*\*: [0-9.]*/**Version**: '"$NEW_VERSION"'/' "$file"
        sed -i 's/Current Status (v[0-9.]*)/Current Status (v'"$NEW_VERSION"')/' "$file"
        echo -e "${GREEN}✓ $file${NC}"
    fi
}

# Process JSON version files
if [ -n "${JSON_VERSION_FILES+x}" ]; then
    for pattern in "${JSON_VERSION_FILES[@]}"; do
        for file in $pattern; do
            [ -f "$file" ] && update_json_version "$file"
        done
    done
fi

# Process manifest files
if [ -n "${MANIFEST_FILES+x}" ]; then
    for pattern in "${MANIFEST_FILES[@]}"; do
        for file in $pattern; do
            [ -f "$file" ] && update_json_version "$file"
        done
    done
fi

# Process documentation files
if [ -n "${DOC_VERSION_FILES+x}" ]; then
    for file in "${DOC_VERSION_FILES[@]}"; do
        update_md_version "$file"
    done
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Version sync complete! All components now at v$NEW_VERSION${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Update CHANGELOG.md"
echo "  2. Commit: git add -A && git commit -m 'chore: bump version to $NEW_VERSION'"
SYNC_EOF
}

# -----------------------------------------------------------------------------
# Generate validate-project.sh
# -----------------------------------------------------------------------------
generate_validate() {
    cat << 'VALIDATE_EOF'
#!/bin/bash
# =============================================================================
# Pre-commit Validation Script
# =============================================================================
# Validates project consistency. Used as pre-commit hook and in CI.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
if [ -f "$SCRIPT_DIR/project-config.sh" ]; then
    source "$SCRIPT_DIR/project-config.sh"
else
    echo "Error: project-config.sh not found. Run bootstrap first."
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

cd "$PROJECT_ROOT"

echo "═══════════════════════════════════════════════════════════════"
echo "  ${PROJECT_NAME:-Project} - Validation"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# -----------------------------------------------------------------------------
# 1. Version Consistency
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/4] Checking version consistency...${NC}"

if [ -f VERSION ]; then
    EXPECTED_VERSION=$(cat VERSION | tr -d '[:space:]')
    echo -e "${GREEN}  ✓ VERSION: $EXPECTED_VERSION${NC}"
    
    # Check JSON files
    if [ -n "${JSON_VERSION_FILES+x}" ]; then
        for file in "${JSON_VERSION_FILES[@]}"; do
            if [ -f "$file" ]; then
                ACTUAL=$(grep '"version"' "$file" | head -1 | sed 's/.*: "\([^"]*\)".*/\1/')
                if [ "$ACTUAL" != "$EXPECTED_VERSION" ]; then
                    echo -e "${RED}  ✗ $file: $ACTUAL (expected $EXPECTED_VERSION)${NC}"
                    ERRORS=$((ERRORS + 1))
                else
                    echo -e "${GREEN}  ✓ $file: $ACTUAL${NC}"
                fi
            fi
        done
    fi
    
    # Check manifest files
    if [ -n "${MANIFEST_FILES+x}" ]; then
        for file in "${MANIFEST_FILES[@]}"; do
            if [ -f "$file" ]; then
                ACTUAL=$(grep '"version"' "$file" | head -1 | sed 's/.*: "\([^"]*\)".*/\1/')
                if [ "$ACTUAL" != "$EXPECTED_VERSION" ]; then
                    echo -e "${RED}  ✗ $file: $ACTUAL (expected $EXPECTED_VERSION)${NC}"
                    ERRORS=$((ERRORS + 1))
                else
                    echo -e "${GREEN}  ✓ $file: $ACTUAL${NC}"
                fi
            fi
        done
    fi
else
    echo -e "${RED}  ✗ VERSION file not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Forbidden Path Check
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[2/4] Checking documentation paths...${NC}"

if [ -n "${FORBIDDEN_DOC_PATHS+x}" ] && [ ${#FORBIDDEN_DOC_PATHS[@]} -gt 0 ]; then
    for forbidden in "${FORBIDDEN_DOC_PATHS[@]}"; do
        # Build grep exclusion pattern from exceptions
        EXCLUDE_PATTERN=""
        if [ -n "${FORBIDDEN_PATH_EXCEPTIONS+x}" ]; then
            for exc in "${FORBIDDEN_PATH_EXCEPTIONS[@]}"; do
                EXCLUDE_PATTERN="$EXCLUDE_PATTERN | grep -v '$exc'"
            done
        fi
        
        FOUND=$(eval "grep -rn '$forbidden' docs/ --include='*.md' 2>/dev/null $EXCLUDE_PATTERN" || true)
        if [ -n "$FOUND" ]; then
            echo -e "${RED}  ✗ Found forbidden path '$forbidden':${NC}"
            echo "$FOUND" | head -5 | while read -r line; do
                echo -e "${RED}    $line${NC}"
            done
            ERRORS=$((ERRORS + 1))
        fi
    done
    
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}  ✓ No forbidden paths found${NC}"
    fi
else
    echo -e "${GREEN}  ✓ No forbidden paths configured${NC}"
fi

echo ""

# -----------------------------------------------------------------------------
# 3. Required Files
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[3/4] Checking required files...${NC}"

if [ -n "${REQUIRED_FILES+x}" ]; then
    for file in "${REQUIRED_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo -e "${GREEN}  ✓ $file${NC}"
        else
            echo -e "${RED}  ✗ Missing: $file${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

echo ""

# -----------------------------------------------------------------------------
# 4. Environment Variables
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[4/4] Checking environment template...${NC}"

if [ -f ".env.example" ] && [ -n "${REQUIRED_ENV_VARS+x}" ]; then
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if grep -q "^$var=" .env.example || grep -q "^# $var=" .env.example; then
            echo -e "${GREEN}  ✓ $var${NC}"
        else
            echo -e "${RED}  ✗ $var missing from .env.example${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done
elif [ ! -f ".env.example" ] && [ -n "${REQUIRED_ENV_VARS+x}" ] && [ ${#REQUIRED_ENV_VARS[@]} -gt 0 ]; then
    echo -e "${YELLOW}  ⚠ .env.example not found (skipping env var check)${NC}"
else
    echo -e "${GREEN}  ✓ No env vars to check${NC}"
fi

echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "═══════════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}  ✓ All validations passed!${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    exit 0
else
    echo -e "${RED}  ✗ Found $ERRORS error(s). Fix before committing.${NC}"
    echo ""
    echo "  Quick fix: ./scripts/sync-version.sh"
    echo "═══════════════════════════════════════════════════════════════"
    exit 1
fi
VALIDATE_EOF
}

# -----------------------------------------------------------------------------
# Generate install-hooks.sh
# -----------------------------------------------------------------------------
generate_install_hooks() {
    cat << 'HOOKS_EOF'
#!/bin/bash
# Installs git pre-commit hook

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "Error: Not a git repository"
    exit 1
fi

cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
if [ -f "$PROJECT_ROOT/scripts/validate-project.sh" ]; then
    "$PROJECT_ROOT/scripts/validate-project.sh"
    exit $?
fi
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ Pre-commit hook installed"
HOOKS_EOF
}

# -----------------------------------------------------------------------------
# Generate PR template
# -----------------------------------------------------------------------------
generate_pr_template() {
    cat << 'PR_EOF'
## Pull Request

### Description
<!-- What does this PR do? -->

### Type of Change
- [ ] 🐛 Bug fix
- [ ] ✨ New feature
- [ ] 💥 Breaking change
- [ ] 📚 Documentation
- [ ] 🔧 Configuration

### Checklist
- [ ] `./scripts/validate-project.sh` passes
- [ ] Tests added/updated (if applicable)
- [ ] Documentation updated (if applicable)
- [ ] CHANGELOG.md updated (if user-facing)

### Version (if releasing)
- [ ] Ran `./scripts/sync-version.sh X.Y.Z`

### Related Issues
<!-- Fixes #123 -->
PR_EOF
}

# -----------------------------------------------------------------------------
# Write files
# -----------------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Dry run - would create:${NC}"
    echo "  scripts/project-config.sh"
    echo "  scripts/sync-version.sh"
    echo "  scripts/validate-project.sh"
    echo "  scripts/install-hooks.sh"
    echo "  .github/PULL_REQUEST_TEMPLATE.md"
    echo "  VERSION (if not exists)"
    exit 0
fi

echo -e "${YELLOW}Creating files...${NC}"

# Project config
generate_config > scripts/project-config.sh
echo -e "${GREEN}  ✓ scripts/project-config.sh${NC}"

# Sync version
generate_sync_version > scripts/sync-version.sh
chmod +x scripts/sync-version.sh
echo -e "${GREEN}  ✓ scripts/sync-version.sh${NC}"

# Validate
generate_validate > scripts/validate-project.sh
chmod +x scripts/validate-project.sh
echo -e "${GREEN}  ✓ scripts/validate-project.sh${NC}"

# Install hooks
generate_install_hooks > scripts/install-hooks.sh
chmod +x scripts/install-hooks.sh
echo -e "${GREEN}  ✓ scripts/install-hooks.sh${NC}"

# PR template
mkdir -p .github
generate_pr_template > .github/PULL_REQUEST_TEMPLATE.md
echo -e "${GREEN}  ✓ .github/PULL_REQUEST_TEMPLATE.md${NC}"

# VERSION file
if [ ! -f VERSION ]; then
    echo "0.1.0" > VERSION
    echo -e "${GREEN}  ✓ VERSION (created with 0.1.0)${NC}"
fi

# Copy advanced scripts from standards directory
echo ""
echo -e "${YELLOW}Installing advanced audit tools...${NC}"

ADVANCED_SCRIPTS=(
    "security-scan.sh"
    "code-quality.sh"
    "architecture-check.sh"
    "test-coverage.sh"
    "docs-validator.sh"
    "full-audit.sh"
)

for script in "${ADVANCED_SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
        cp "$SCRIPT_DIR/scripts/$script" "scripts/$script"
        chmod +x "scripts/$script"
        echo -e "${GREEN}  ✓ scripts/$script${NC}"
    fi
done

echo ""

# Install git hooks
./scripts/install-hooks.sh

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Bootstrap complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Installed scripts:"
echo "  ./scripts/validate-project.sh  - Pre-commit validation"
echo "  ./scripts/sync-version.sh      - Sync version everywhere"
echo "  ./scripts/security-scan.sh     - Security audit"
echo "  ./scripts/code-quality.sh      - Lint & quality checks"
echo "  ./scripts/architecture-check.sh - Architecture validation"
echo "  ./scripts/test-coverage.sh     - Test coverage analysis"
echo "  ./scripts/docs-validator.sh    - Documentation checks"
echo "  ./scripts/full-audit.sh        - Run ALL checks"
echo ""
echo "Next steps:"
echo "  1. Review scripts/project-config.sh and customize"
echo "  2. Run: ./scripts/full-audit.sh"
echo "  3. Commit: git add scripts/ .github/ VERSION && git commit -m 'chore: add project standards'"
