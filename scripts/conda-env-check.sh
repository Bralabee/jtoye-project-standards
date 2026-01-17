#!/bin/bash
# J'Toye Digital - Conda Environment Check
# Ensures Python projects use dedicated conda virtual environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"
fi

# Setup help
setup_help "Check conda environment setup and Python project dependencies"
add_help_option "<project_root>  Path to project root (default: current directory)"
handle_help "$@"

PROJECT_ROOT="${1:-.}"
PROJECT_NAME=$(basename "$(cd "$PROJECT_ROOT" && pwd)")
REPORT_FILE="${PROJECT_ROOT}/reports/conda-env-report.txt"

mkdir -p "${PROJECT_ROOT}/reports"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    CONDA ENVIRONMENT CHECK - ${PROJECT_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

ISSUES=0
WARNINGS=0

# Check if this is a Python project
is_python_project() {
    [[ -f "${PROJECT_ROOT}/requirements.txt" ]] || \
    [[ -f "${PROJECT_ROOT}/setup.py" ]] || \
    [[ -f "${PROJECT_ROOT}/pyproject.toml" ]] || \
    [[ -f "${PROJECT_ROOT}/environment.yml" ]] || \
    [[ -f "${PROJECT_ROOT}/environment.yaml" ]] || \
    find "$PROJECT_ROOT" -maxdepth 3 -name "requirements.txt" -o -name "*.py" 2>/dev/null | head -1 | grep -q .
}

# Check if conda is available
check_conda_available() {
    echo -e "\n${BLUE}[1/5] Checking Conda Installation${NC}"
    
    if command -v conda &> /dev/null; then
        CONDA_VERSION=$(conda --version 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} Conda is installed: $CONDA_VERSION"
        return 0
    else
        echo -e "  ${RED}✗${NC} Conda is not installed or not in PATH"
        echo "    Install Miniconda: https://docs.conda.io/en/latest/miniconda.html"
        ISSUES=$((ISSUES + 1))
        return 1
    fi
}

# Check for dedicated project environment
check_project_env() {
    echo -e "\n${BLUE}[2/5] Checking Project Environment${NC}"
    
    # Normalize project name for env matching (lowercase, replace spaces/hyphens)
    ENV_NAME_PATTERN=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
    
    # List conda environments
    EXISTING_ENVS=$(conda env list 2>/dev/null | grep -v "^#" | awk '{print $1}' || echo "")
    
    # Check for exact match or similar names
    MATCHING_ENV=""
    for env in $EXISTING_ENVS; do
        env_lower=$(echo "$env" | tr '[:upper:]' '[:lower:]')
        if [[ "$env_lower" == "$ENV_NAME_PATTERN" ]] || \
           [[ "$env_lower" == *"$ENV_NAME_PATTERN"* ]] || \
           [[ "$ENV_NAME_PATTERN" == *"$env_lower"* ]]; then
            MATCHING_ENV="$env"
            break
        fi
    done
    
    if [[ -n "$MATCHING_ENV" ]]; then
        echo -e "  ${GREEN}✓${NC} Found dedicated environment: $MATCHING_ENV"
        echo "CONDA_ENV=$MATCHING_ENV" >> "$REPORT_FILE"
    else
        echo -e "  ${YELLOW}⚠${NC} No dedicated conda environment found for project"
        echo "    Expected environment name containing: $ENV_NAME_PATTERN"
        echo "    Available environments:"
        for env in $EXISTING_ENVS; do
            echo "      - $env"
        done
        WARNINGS=$((WARNINGS + 1))
    fi
}

# Check for environment definition files
check_env_files() {
    echo -e "\n${BLUE}[3/5] Checking Environment Definition Files${NC}"
    
    HAS_ENV_FILE=false
    
    # Check for environment.yml (conda native)
    if [[ -f "${PROJECT_ROOT}/environment.yml" ]] || [[ -f "${PROJECT_ROOT}/environment.yaml" ]]; then
        ENV_FILE=$(ls "${PROJECT_ROOT}"/environment.y*ml 2>/dev/null | head -1)
        echo -e "  ${GREEN}✓${NC} Found environment.yml: $ENV_FILE"
        HAS_ENV_FILE=true
        
        # Validate structure
        if grep -q "^name:" "$ENV_FILE" 2>/dev/null; then
            ENV_NAME_IN_FILE=$(grep "^name:" "$ENV_FILE" | head -1 | awk '{print $2}')
            echo -e "    Environment name defined: $ENV_NAME_IN_FILE"
        else
            echo -e "  ${YELLOW}⚠${NC} environment.yml missing 'name' field"
            WARNINGS=$((WARNINGS + 1))
        fi
        
        if grep -q "dependencies:" "$ENV_FILE" 2>/dev/null; then
            DEP_COUNT=$(grep -A 100 "dependencies:" "$ENV_FILE" | grep "^  - " | wc -l)
            echo -e "    Dependencies listed: ~$DEP_COUNT packages"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} No environment.yml found"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for requirements.txt (pip)
    REQ_FILES=$(find "$PROJECT_ROOT" -maxdepth 3 -name "requirements*.txt" ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/venv/*" 2>/dev/null)
    
    if [[ -n "$REQ_FILES" ]]; then
        echo -e "  ${GREEN}✓${NC} Found requirements.txt file(s):"
        for req in $REQ_FILES; do
            REQ_COUNT=$(grep -v "^#" "$req" 2>/dev/null | grep -v "^$" | wc -l)
            echo -e "    - $req ($REQ_COUNT packages)"
        done
        HAS_ENV_FILE=true
    fi
    
    # Check for pyproject.toml
    if [[ -f "${PROJECT_ROOT}/pyproject.toml" ]]; then
        echo -e "  ${GREEN}✓${NC} Found pyproject.toml"
        HAS_ENV_FILE=true
    fi
    
    if [[ "$HAS_ENV_FILE" == false ]]; then
        echo -e "  ${RED}✗${NC} No environment definition files found"
        echo "    Create environment.yml or requirements.txt to define dependencies"
        ISSUES=$((ISSUES + 1))
    fi
}

# Check if environment is activated
check_env_activated() {
    echo -e "\n${BLUE}[4/5] Checking Active Environment${NC}"
    
    if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
        echo -e "  ${GREEN}✓${NC} Conda environment active: $CONDA_DEFAULT_ENV"
        
        # Check if it matches project
        ENV_NAME_PATTERN=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
        ACTIVE_LOWER=$(echo "$CONDA_DEFAULT_ENV" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$ACTIVE_LOWER" == *"$ENV_NAME_PATTERN"* ]] || [[ "$ENV_NAME_PATTERN" == *"$ACTIVE_LOWER"* ]]; then
            echo -e "  ${GREEN}✓${NC} Active environment matches project"
        else
            echo -e "  ${YELLOW}⚠${NC} Active environment may not be project-specific"
            echo "    Active: $CONDA_DEFAULT_ENV"
            echo "    Expected: contains '$ENV_NAME_PATTERN'"
            WARNINGS=$((WARNINGS + 1))
        fi
    elif [[ -n "$VIRTUAL_ENV" ]]; then
        echo -e "  ${YELLOW}⚠${NC} Using venv instead of conda: $VIRTUAL_ENV"
        echo "    Consider switching to conda for consistency"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} No virtual environment is currently active"
        WARNINGS=$((WARNINGS + 1))
    fi
}

# Generate setup instructions
generate_setup_instructions() {
    echo -e "\n${BLUE}[5/5] Setup Instructions${NC}"
    
    ENV_NAME_SUGGESTION=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    
    echo ""
    echo -e "${BLUE}To create a dedicated conda environment:${NC}"
    echo ""
    
    # If environment.yml exists
    if [[ -f "${PROJECT_ROOT}/environment.yml" ]] || [[ -f "${PROJECT_ROOT}/environment.yaml" ]]; then
        echo "  # Using environment.yml:"
        echo "  conda env create -f environment.yml"
        echo "  conda activate <env-name-from-yml>"
    # If requirements.txt exists
    elif [[ -f "${PROJECT_ROOT}/requirements.txt" ]]; then
        echo "  # Create environment from requirements.txt:"
        echo "  conda create -n ${ENV_NAME_SUGGESTION} python=3.11 -y"
        echo "  conda activate ${ENV_NAME_SUGGESTION}"
        echo "  pip install -r requirements.txt"
        echo ""
        echo "  # Or generate environment.yml:"
        echo "  conda env export > environment.yml"
    else
        echo "  # Create new environment:"
        echo "  conda create -n ${ENV_NAME_SUGGESTION} python=3.11 -y"
        echo "  conda activate ${ENV_NAME_SUGGESTION}"
        echo ""
        echo "  # Then save environment:"
        echo "  pip freeze > requirements.txt"
        echo "  conda env export > environment.yml"
    fi
    
    echo ""
    echo -e "${BLUE}To activate the environment:${NC}"
    echo "  conda activate ${ENV_NAME_SUGGESTION}"
}

# Main execution
{
    echo "=== CONDA ENVIRONMENT CHECK ==="
    echo "Project: $PROJECT_NAME"
    echo "Date: $(date)"
    echo ""
} > "$REPORT_FILE"

if ! is_python_project; then
    echo -e "\n${YELLOW}⚠${NC} Not a Python project - skipping conda checks"
    echo "STATUS: SKIPPED (not a Python project)" >> "$REPORT_FILE"
    exit 0
fi

check_conda_available
check_project_env
check_env_files
check_env_activated
generate_setup_instructions

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
