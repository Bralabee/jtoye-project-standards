#!/bin/bash
# =============================================================================
# J'Toye Digital - Release Automation
# =============================================================================
# Automates version bumping, changelog generation, git tagging, and
# release notes compilation.
#
# Usage:
#   ./scripts/release.sh patch|minor|major  - Bump version
#   ./scripts/release.sh 1.2.3              - Set specific version
#   ./scripts/release.sh --dry-run patch    - Preview changes
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Options
DRY_RUN=false
BUMP_TYPE=""
NEW_VERSION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        patch|minor|major)
            BUMP_TYPE="$1"
            shift
            ;;
        [0-9]*)
            NEW_VERSION="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: release.sh [--dry-run] <patch|minor|major|X.Y.Z>"
            echo ""
            echo "Examples:"
            echo "  ./scripts/release.sh patch       # 1.2.3 -> 1.2.4"
            echo "  ./scripts/release.sh minor       # 1.2.3 -> 1.3.0"
            echo "  ./scripts/release.sh major       # 1.2.3 -> 2.0.0"
            echo "  ./scripts/release.sh 2.0.0       # Set specific version"
            echo "  ./scripts/release.sh --dry-run patch  # Preview"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "$PROJECT_ROOT"

echo "═══════════════════════════════════════════════════════════════"
echo "  Release Automation"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# -----------------------------------------------------------------------------
# Get Current Version
# -----------------------------------------------------------------------------
if [ ! -f VERSION ]; then
    echo "0.1.0" > VERSION
fi

CURRENT_VERSION=$(cat VERSION | tr -d '[:space:]')
echo -e "  Current version: ${BLUE}$CURRENT_VERSION${NC}"

# -----------------------------------------------------------------------------
# Calculate New Version
# -----------------------------------------------------------------------------
if [ -n "$BUMP_TYPE" ]; then
    # Parse current version
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    
    case $BUMP_TYPE in
        patch)
            PATCH=$((PATCH + 1))
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
    esac
    
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
elif [ -z "$NEW_VERSION" ]; then
    echo -e "${RED}Error: Specify bump type (patch/minor/major) or version number${NC}"
    exit 1
fi

echo -e "  New version:     ${GREEN}$NEW_VERSION${NC}"
echo ""

# Validate semantic versioning
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid version format. Use X.Y.Z${NC}"
    exit 1
fi

# Check if version already exists
if git tag -l "v$NEW_VERSION" | grep -q "v$NEW_VERSION"; then
    echo -e "${RED}Error: Tag v$NEW_VERSION already exists${NC}"
    exit 1
fi

# -----------------------------------------------------------------------------
# Dry Run Check
# -----------------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would perform the following:${NC}"
    echo "  1. Update VERSION file to $NEW_VERSION"
    echo "  2. Sync version to all components"
    echo "  3. Generate changelog entry"
    echo "  4. Commit changes"
    echo "  5. Create git tag v$NEW_VERSION"
    echo ""
    
    # Preview changelog
    echo -e "${YELLOW}[DRY RUN] Changelog preview:${NC}"
    echo ""
    echo "## [$NEW_VERSION] - $(date +%Y-%m-%d)"
    echo ""
    git log --oneline v$CURRENT_VERSION..HEAD 2>/dev/null | head -10 || git log --oneline HEAD~10..HEAD | head -10
    echo ""
    exit 0
fi

# -----------------------------------------------------------------------------
# Pre-release Checks
# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/6] Running pre-release checks...${NC}"

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}Error: Uncommitted changes detected. Commit or stash first.${NC}"
    git status --short
    exit 1
fi

echo -e "${GREEN}  ✓ Working directory clean${NC}"

# Run validation if available
if [ -f "$SCRIPT_DIR/validate-project.sh" ]; then
    echo -e "${BLUE}  Running project validation...${NC}"
    if ! "$SCRIPT_DIR/validate-project.sh" > /dev/null 2>&1; then
        echo -e "${RED}Error: Project validation failed. Fix issues first.${NC}"
        "$SCRIPT_DIR/validate-project.sh"
        exit 1
    fi
    echo -e "${GREEN}  ✓ Project validation passed${NC}"
fi

echo ""

# -----------------------------------------------------------------------------
# Update Version
# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/6] Updating version to $NEW_VERSION...${NC}"

echo "$NEW_VERSION" > VERSION

# Sync version to all files
if [ -f "$SCRIPT_DIR/sync-version.sh" ]; then
    "$SCRIPT_DIR/sync-version.sh" > /dev/null
    echo -e "${GREEN}  ✓ Version synced across all files${NC}"
else
    echo -e "${YELLOW}  ⚠ sync-version.sh not found, only VERSION file updated${NC}"
fi

echo ""

# -----------------------------------------------------------------------------
# Generate Changelog Entry
# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/6] Generating changelog entry...${NC}"

# Get commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
    COMMITS=$(git log --oneline "$LAST_TAG"..HEAD 2>/dev/null || git log --oneline HEAD~20..HEAD)
else
    COMMITS=$(git log --oneline HEAD~20..HEAD)
fi

# Categorize commits
FEATURES=$(echo "$COMMITS" | grep -iE "^[a-f0-9]+ (feat|add|new)" | sed 's/^[a-f0-9]* /- /' || true)
FIXES=$(echo "$COMMITS" | grep -iE "^[a-f0-9]+ (fix|bug|patch)" | sed 's/^[a-f0-9]* /- /' || true)
DOCS=$(echo "$COMMITS" | grep -iE "^[a-f0-9]+ (doc|readme)" | sed 's/^[a-f0-9]* /- /' || true)
CHORES=$(echo "$COMMITS" | grep -iE "^[a-f0-9]+ (chore|refactor|style|test|ci)" | sed 's/^[a-f0-9]* /- /' || true)
OTHER=$(echo "$COMMITS" | grep -viE "^[a-f0-9]+ (feat|add|new|fix|bug|patch|doc|readme|chore|refactor|style|test|ci)" | sed 's/^[a-f0-9]* /- /' || true)

# Build changelog entry
CHANGELOG_ENTRY="## [$NEW_VERSION] - $(date +%Y-%m-%d)

"

[ -n "$FEATURES" ] && CHANGELOG_ENTRY+="### Added
$FEATURES

"

[ -n "$FIXES" ] && CHANGELOG_ENTRY+="### Fixed
$FIXES

"

[ -n "$DOCS" ] && CHANGELOG_ENTRY+="### Documentation
$DOCS

"

[ -n "$CHORES" ] && CHANGELOG_ENTRY+="### Changed
$CHORES

"

[ -n "$OTHER" ] && CHANGELOG_ENTRY+="### Other
$OTHER

"

# Update CHANGELOG.md
if [ -f CHANGELOG.md ]; then
    # Insert after the header
    if grep -q "^## \[" CHANGELOG.md; then
        # Insert before first version entry
        sed -i "/^## \[/i\\
$CHANGELOG_ENTRY" CHANGELOG.md
    else
        # Append to file
        echo "$CHANGELOG_ENTRY" >> CHANGELOG.md
    fi
    echo -e "${GREEN}  ✓ CHANGELOG.md updated${NC}"
else
    # Create new changelog
    cat > CHANGELOG.md << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

$CHANGELOG_ENTRY
EOF
    echo -e "${GREEN}  ✓ CHANGELOG.md created${NC}"
fi

echo ""

# -----------------------------------------------------------------------------
# Commit Changes
# -----------------------------------------------------------------------------
echo -e "${BLUE}[4/6] Committing changes...${NC}"

git add -A
git commit -m "chore(release): v$NEW_VERSION

- Bump version to $NEW_VERSION
- Update changelog
"

echo -e "${GREEN}  ✓ Changes committed${NC}"
echo ""

# -----------------------------------------------------------------------------
# Create Git Tag
# -----------------------------------------------------------------------------
echo -e "${BLUE}[5/6] Creating git tag...${NC}"

git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION

$(echo "$CHANGELOG_ENTRY" | head -30)
"

echo -e "${GREEN}  ✓ Created tag v$NEW_VERSION${NC}"
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "${BLUE}[6/6] Release complete!${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}  ✓ Released v$NEW_VERSION${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Next steps:"
echo "    1. Review the changelog: less CHANGELOG.md"
echo "    2. Push changes:  git push origin main"
echo "    3. Push tag:      git push origin v$NEW_VERSION"
echo "    4. Create GitHub release (optional)"
echo ""
echo "  To undo:"
echo "    git reset --hard HEAD~1 && git tag -d v$NEW_VERSION"
