#!/bin/bash
# J'Toye Digital - Conda Environment Setup
# Creates or activates dedicated conda environment for Python projects

set -e

PROJECT_ROOT="${1:-.}"
PROJECT_NAME=$(basename "$(cd "$PROJECT_ROOT" && pwd)")
ENV_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
PYTHON_VERSION="${2:-3.11}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    CONDA ENVIRONMENT SETUP - ${PROJECT_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check conda is available
if ! command -v conda &> /dev/null; then
    echo -e "${RED}✗ Conda is not installed${NC}"
    echo "  Install Miniconda: https://docs.conda.io/en/latest/miniconda.html"
    exit 1
fi

echo -e "\n${BLUE}Environment name:${NC} $ENV_NAME"
echo -e "${BLUE}Python version:${NC} $PYTHON_VERSION"

# Check if environment already exists
ENV_EXISTS=$(conda env list | grep -w "^$ENV_NAME " || true)

if [[ -n "$ENV_EXISTS" ]]; then
    echo -e "\n${GREEN}✓${NC} Environment '$ENV_NAME' already exists"
    echo ""
    echo -e "${BLUE}To activate:${NC}"
    echo "  conda activate $ENV_NAME"
    
    # Check if we should update it
    read -p "Update environment with current dependencies? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\n${BLUE}Updating environment...${NC}"
        
        if [[ -f "${PROJECT_ROOT}/environment.yml" ]]; then
            conda env update -n "$ENV_NAME" -f "${PROJECT_ROOT}/environment.yml"
        elif [[ -f "${PROJECT_ROOT}/requirements.txt" ]]; then
            # Activate and pip install
            eval "$(conda shell.bash hook)"
            conda activate "$ENV_NAME"
            pip install -r "${PROJECT_ROOT}/requirements.txt"
        fi
        
        echo -e "${GREEN}✓${NC} Environment updated"
    fi
else
    echo -e "\n${YELLOW}○${NC} Environment '$ENV_NAME' does not exist"
    echo ""
    
    # Determine creation method
    if [[ -f "${PROJECT_ROOT}/environment.yml" ]] || [[ -f "${PROJECT_ROOT}/environment.yaml" ]]; then
        ENV_FILE=$(ls "${PROJECT_ROOT}"/environment.y*ml 2>/dev/null | head -1)
        echo -e "${BLUE}Creating from environment.yml...${NC}"
        echo "  Source: $ENV_FILE"
        
        # Check if name in yml differs
        YML_NAME=$(grep "^name:" "$ENV_FILE" 2>/dev/null | awk '{print $2}' || echo "")
        if [[ -n "$YML_NAME" ]] && [[ "$YML_NAME" != "$ENV_NAME" ]]; then
            echo -e "${YELLOW}⚠${NC} Note: environment.yml defines name as '$YML_NAME'"
            read -p "Use '$YML_NAME' instead of '$ENV_NAME'? (Y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                ENV_NAME="$YML_NAME"
            fi
        fi
        
        conda env create -f "$ENV_FILE"
        
    elif [[ -f "${PROJECT_ROOT}/requirements.txt" ]]; then
        echo -e "${BLUE}Creating from requirements.txt...${NC}"
        echo "  Source: ${PROJECT_ROOT}/requirements.txt"
        
        # Create base environment
        conda create -n "$ENV_NAME" python="$PYTHON_VERSION" pip -y
        
        # Activate and install
        eval "$(conda shell.bash hook)"
        conda activate "$ENV_NAME"
        pip install -r "${PROJECT_ROOT}/requirements.txt"
        
        # Generate environment.yml for future use
        echo -e "\n${BLUE}Generating environment.yml...${NC}"
        conda env export > "${PROJECT_ROOT}/environment.yml"
        echo -e "${GREEN}✓${NC} Created ${PROJECT_ROOT}/environment.yml"
        
    else
        echo -e "${BLUE}Creating minimal Python environment...${NC}"
        
        conda create -n "$ENV_NAME" python="$PYTHON_VERSION" pip -y
        
        echo -e "\n${YELLOW}⚠${NC} No requirements.txt found"
        echo "  After installing packages, run:"
        echo "  pip freeze > requirements.txt"
        echo "  conda env export > environment.yml"
    fi
    
    echo -e "\n${GREEN}✓${NC} Environment '$ENV_NAME' created successfully"
fi

# Print activation instructions
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                 NEXT STEPS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  1. Activate the environment:"
echo -e "     ${GREEN}conda activate $ENV_NAME${NC}"
echo ""
echo "  2. Verify Python version:"
echo "     python --version"
echo ""
echo "  3. Install additional packages:"
echo "     pip install <package>"
echo ""
echo "  4. Save dependencies:"
echo "     pip freeze > requirements.txt"
echo "     conda env export > environment.yml"
echo ""

# Create/update Makefile conda targets
if [[ -f "${PROJECT_ROOT}/Makefile" ]]; then
    if ! grep -q "conda-activate" "${PROJECT_ROOT}/Makefile" 2>/dev/null; then
        echo -e "${YELLOW}○${NC} Consider adding conda targets to Makefile:"
        echo ""
        echo "  conda-env:  ## Create conda environment"
        echo "  	conda create -n $ENV_NAME python=$PYTHON_VERSION -y"
        echo ""
        echo "  conda-activate:  ## Show activation command"
        echo "  	@echo \"Run: conda activate $ENV_NAME\""
        echo ""
    fi
fi
