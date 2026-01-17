#!/bin/bash
# J'Toye Digital - Makefile Check
# Ensures projects have proper Makefiles with standard targets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"
fi

# Setup help
setup_help "Check Makefile structure and verify standard targets exist"
add_help_option "<project_root>  Path to project root (default: current directory)"
add_help_option "--fix           Generate missing Makefile or targets"
handle_help "$@"

PROJECT_ROOT="${1:-.}"
PROJECT_NAME=$(basename "$(cd "$PROJECT_ROOT" && pwd)")
REPORT_FILE="${PROJECT_ROOT}/reports/makefile-report.txt"

mkdir -p "${PROJECT_ROOT}/reports"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}       MAKEFILE CHECK - ${PROJECT_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

ISSUES=0
WARNINGS=0

# Detect project type
detect_project_type() {
    if [[ -f "${PROJECT_ROOT}/go.mod" ]]; then
        echo "go"
    elif [[ -f "${PROJECT_ROOT}/requirements.txt" ]] || [[ -f "${PROJECT_ROOT}/pyproject.toml" ]] || [[ -f "${PROJECT_ROOT}/setup.py" ]]; then
        echo "python"
    elif [[ -f "${PROJECT_ROOT}/package.json" ]]; then
        echo "node"
    elif [[ -f "${PROJECT_ROOT}/Cargo.toml" ]]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

PROJECT_TYPE=$(detect_project_type)

# Find all Makefiles
find_makefiles() {
    echo -e "\n${BLUE}[1/4] Locating Makefiles${NC}"
    
    FOUND_FILES=$(find "$PROJECT_ROOT" -maxdepth 3 \( -name "Makefile" -o -name "makefile" -o -name "GNUmakefile" \) 2>/dev/null | \
                grep -v node_modules | grep -v .venv | grep -v vendor || true)
    
    if [[ -n "$FOUND_FILES" ]]; then
        echo -e "  ${GREEN}✓${NC} Found Makefile(s):"
        for mf in $FOUND_FILES; do
            echo "    - $mf"
        done
        MAKEFILES="$FOUND_FILES"
    else
        echo -e "  ${YELLOW}⚠${NC} No Makefile found in project"
        WARNINGS=$((WARNINGS + 1))
        MAKEFILES=""
    fi
}

# Check standard targets
check_standard_targets() {
    local makefile="$1"
    
    if [[ -z "$makefile" ]] || [[ ! -f "$makefile" ]]; then
        echo -e "\n${BLUE}[2/4] Checking Standard Targets${NC}"
        echo -e "  ${YELLOW}⚠${NC} No Makefile to analyze"
        return
    fi
    
    echo -e "\n${BLUE}[2/4] Checking Standard Targets${NC}"
    echo -e "  Analyzing: $makefile"
    
    # Define expected targets by project type
    case "$PROJECT_TYPE" in
        go)
            EXPECTED_TARGETS="build run test clean lint fmt docker"
            ;;
        python)
            EXPECTED_TARGETS="install run test clean lint format venv"
            ;;
        node)
            EXPECTED_TARGETS="install build dev test clean lint"
            ;;
        rust)
            EXPECTED_TARGETS="build run test clean fmt clippy"
            ;;
        *)
            EXPECTED_TARGETS="build run test clean"
            ;;
    esac
    
    # Extract actual targets from Makefile
    ACTUAL_TARGETS=$(grep -E "^[a-zA-Z_-]+:" "$makefile" 2>/dev/null | sed 's/:.*//' | sort -u || true)
    
    echo -e "\n  Expected targets for $PROJECT_TYPE project:"
    FOUND_TARGETS=0
    MISSING_TARGETS=""
    
    for target in $EXPECTED_TARGETS; do
        if echo "$ACTUAL_TARGETS" | grep -qw "$target"; then
            echo -e "    ${GREEN}✓${NC} $target"
            FOUND_TARGETS=$((FOUND_TARGETS + 1))
        else
            echo -e "    ${YELLOW}⚠${NC} $target (missing)"
            MISSING_TARGETS="$MISSING_TARGETS $target"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
    
    # Show additional targets
    echo -e "\n  Additional targets found:"
    for target in $ACTUAL_TARGETS; do
        if ! echo "$EXPECTED_TARGETS" | grep -qw "$target"; then
            echo -e "    ${BLUE}○${NC} $target"
        fi
    done
}

# Check Makefile quality
check_makefile_quality() {
    local makefile="$1"
    
    if [[ -z "$makefile" ]] || [[ ! -f "$makefile" ]]; then
        echo -e "\n${BLUE}[3/4] Checking Makefile Quality${NC}"
        echo -e "  ${YELLOW}⚠${NC} No Makefile to analyze"
        return
    fi
    
    echo -e "\n${BLUE}[3/4] Checking Makefile Quality${NC}"
    
    # Check for .PHONY declarations
    if grep -q "^\.PHONY" "$makefile" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} .PHONY targets declared"
    else
        echo -e "  ${YELLOW}⚠${NC} Missing .PHONY declarations"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for help target
    if grep -qE "^help:" "$makefile" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Help target available"
    else
        echo -e "  ${YELLOW}⚠${NC} No help target (consider adding)"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for default target
    FIRST_TARGET=$(grep -E "^[a-zA-Z_-]+:" "$makefile" 2>/dev/null | head -1 | sed 's/:.*//')
    if [[ -n "$FIRST_TARGET" ]]; then
        echo -e "  ${GREEN}✓${NC} Default target: $FIRST_TARGET"
    fi
    
    # Check for variable definitions
    VAR_COUNT=$(grep -E "^[A-Z_]+\s*[:?]?=" "$makefile" 2>/dev/null | wc -l || echo "0")
    echo -e "  ${BLUE}○${NC} Variables defined: $VAR_COUNT"
    
    # Check for environment-specific handling
    if grep -qE "ifdef|ifndef|ifeq" "$makefile" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Conditional logic present"
    fi
    
    # Check for shell specification
    if grep -q "^SHELL" "$makefile" 2>/dev/null; then
        SHELL_DEF=$(grep "^SHELL" "$makefile" | head -1)
        echo -e "  ${GREEN}✓${NC} Shell specified: $SHELL_DEF"
    fi
}

# Generate Makefile template
generate_template() {
    echo -e "\n${BLUE}[4/4] Makefile Recommendations${NC}"
    
    if [[ -z "$MAKEFILES" ]] || [[ "$WARNINGS" -gt 3 ]]; then
        echo ""
        echo -e "${BLUE}Recommended Makefile template for $PROJECT_TYPE project:${NC}"
        echo ""
        
        case "$PROJECT_TYPE" in
            python)
cat << 'EOF'
# Project Makefile
.PHONY: help install venv run test lint format clean

PYTHON := python3
VENV := .venv
CONDA_ENV := $(shell echo $${PWD##*/} | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

conda-env:  ## Create conda environment
	conda create -n $(CONDA_ENV) python=3.11 -y

conda-activate:  ## Show conda activation command
	@echo "Run: conda activate $(CONDA_ENV)"

install:  ## Install dependencies
	pip install -r requirements.txt

install-dev:  ## Install dev dependencies
	pip install -r requirements-dev.txt

run:  ## Run the application
	$(PYTHON) main.py

test:  ## Run tests
	pytest tests/ -v

lint:  ## Run linter
	ruff check .

format:  ## Format code
	ruff format .
	isort .

clean:  ## Clean build artifacts
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache .ruff_cache dist build *.egg-info

freeze:  ## Export dependencies
	pip freeze > requirements.txt
	conda env export > environment.yml
EOF
                ;;
            go)
cat << 'EOF'
# Project Makefile
.PHONY: help build run test lint fmt clean docker

BINARY := app
GO := go

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build:  ## Build the binary
	$(GO) build -o $(BINARY) ./cmd/...

run:  ## Run the application
	$(GO) run ./cmd/...

test:  ## Run tests
	$(GO) test -v ./...

lint:  ## Run linter
	golangci-lint run

fmt:  ## Format code
	$(GO) fmt ./...
	goimports -w .

clean:  ## Clean build artifacts
	rm -f $(BINARY)
	$(GO) clean

docker:  ## Build Docker image
	docker build -t $(BINARY) .

tidy:  ## Tidy dependencies
	$(GO) mod tidy
EOF
                ;;
            node)
cat << 'EOF'
# Project Makefile
.PHONY: help install build dev test lint clean docker

NPM := npm

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install:  ## Install dependencies
	$(NPM) install

build:  ## Build the project
	$(NPM) run build

dev:  ## Start development server
	$(NPM) run dev

test:  ## Run tests
	$(NPM) test

lint:  ## Run linter
	$(NPM) run lint

format:  ## Format code
	$(NPM) run format

clean:  ## Clean build artifacts
	rm -rf node_modules dist .next .turbo

docker:  ## Build Docker image
	docker build -t app .
EOF
                ;;
            *)
cat << 'EOF'
# Project Makefile
.PHONY: help build run test clean

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build:  ## Build the project
	@echo "Build target - implement me"

run:  ## Run the application
	@echo "Run target - implement me"

test:  ## Run tests
	@echo "Test target - implement me"

clean:  ## Clean build artifacts
	@echo "Clean target - implement me"
EOF
                ;;
        esac
        echo ""
    fi
}

# Main execution
{
    echo "=== MAKEFILE CHECK ==="
    echo "Project: $PROJECT_NAME"
    echo "Project Type: $PROJECT_TYPE"
    echo "Date: $(date)"
    echo ""
} > "$REPORT_FILE"

# Initialize MAKEFILES variable
MAKEFILES=""
find_makefiles

if [[ -n "$MAKEFILES" ]]; then
    # Check the root Makefile first, or first found
    PRIMARY_MAKEFILE=$(echo "$MAKEFILES" | head -1)
    check_standard_targets "$PRIMARY_MAKEFILE"
    check_makefile_quality "$PRIMARY_MAKEFILE"
else
    # Skip detailed checks if no Makefile
    echo -e "\n${BLUE}[2/4] Checking Standard Targets${NC}"
    echo -e "  ${YELLOW}⚠${NC} Skipped - no Makefile found"
    echo -e "\n${BLUE}[3/4] Checking Makefile Quality${NC}"
    echo -e "  ${YELLOW}⚠${NC} Skipped - no Makefile found"
fi

generate_template

# Summary
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                    SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

{
    echo ""
    echo "=== SUMMARY ==="
    echo "Issues: $ISSUES"
    echo "Warnings: $WARNINGS"
} >> "$REPORT_FILE"

if [[ $ISSUES -gt 0 ]]; then
    echo -e "  ${RED}✗${NC} Issues: $ISSUES"
    echo -e "  ${YELLOW}⚠${NC} Warnings: $WARNINGS"
    echo "STATUS: FAIL" >> "$REPORT_FILE"
    echo -e "\n  ${RED}RESULT: NEEDS ATTENTION${NC}"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo -e "  ${GREEN}✓${NC} Issues: 0"
    echo -e "  ${YELLOW}⚠${NC} Warnings: $WARNINGS"
    echo "STATUS: WARN" >> "$REPORT_FILE"
    echo -e "\n  ${YELLOW}RESULT: PASS WITH WARNINGS${NC}"
    exit 0
else
    echo -e "  ${GREEN}✓${NC} Issues: 0"
    echo -e "  ${GREEN}✓${NC} Warnings: 0"
    echo "STATUS: PASS" >> "$REPORT_FILE"
    echo -e "\n  ${GREEN}RESULT: PASS${NC}"
    exit 0
fi
