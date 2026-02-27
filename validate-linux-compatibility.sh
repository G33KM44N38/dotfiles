#!/bin/bash

# Validate Linux compatibility of dotfiles
# This script checks the Ansible playbook and role structure

set -e

echo "🔍 Validating Linux compatibility of dotfiles"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a role has Linux support
check_role_linux_support() {
    local role=$1
    local role_path="install/roles/$role"

    if [[ ! -d "$role_path" ]]; then
        echo -e "${YELLOW}⚠️  Role $role does not exist${NC}"
        return 1
    fi

    # Check if role has Linux-specific tasks
    if [[ -f "$role_path/tasks/linux.yml" ]]; then
        echo -e "${GREEN}✅ $role has Linux support${NC}"
        return 0
    elif [[ -f "$role_path/tasks/ubuntu.yml" ]]; then
        echo -e "${GREEN}✅ $role has Ubuntu support${NC}"
        return 0
    elif [[ -f "$role_path/tasks/main.yaml" ]] || [[ -f "$role_path/tasks/main.yml" ]]; then
        # Check if main.yaml includes Linux tasks
        if grep -q "linux.yml\|ubuntu.yml\|ansible_system.*Linux" "$role_path/tasks/main.yaml" 2>/dev/null; then
            echo -e "${GREEN}✅ $role has Linux support in main.yaml${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  $role may not have Linux support${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ $role has no task files${NC}"
        return 1
    fi
}

# Check main playbook structure
echo -e "\n${BLUE}Checking main playbook structure...${NC}"
if grep -q "when: ansible_system == 'Darwin'" install/main.yaml; then
    echo -e "${GREEN}✅ Main playbook has macOS conditionals${NC}"
else
    echo -e "${RED}❌ Main playbook missing macOS conditionals${NC}"
fi

if grep -q "appcleaner\|arc\|dock\|karabiner\|mouseless\|raycast" install/main.yaml; then
    if grep -q "when: ansible_system == 'Darwin'" install/main.yaml; then
        echo -e "${GREEN}✅ macOS-only roles are properly conditional${NC}"
    else
        echo -e "${RED}❌ macOS-only roles not properly conditional${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find macOS role references${NC}"
fi

# Check key roles for Linux support
echo -e "\n${BLUE}Checking role Linux support...${NC}"

# Roles that should have Linux support
linux_roles=("cron" "ghostty" "python" "solana" "stripe")
failed_roles=0

for role in "${linux_roles[@]}"; do
    if ! check_role_linux_support "$role"; then
        ((failed_roles++))
    fi
done

# Check roles that already have Ubuntu support
ubuntu_roles=("fzf" "lazygit" "node" "nvim" "ripgrep" "stow" "tmux" "yarn" "zsh")
echo -e "\n${BLUE}Checking roles with existing Ubuntu support...${NC}"

for role in "${ubuntu_roles[@]}"; do
    if check_role_linux_support "$role"; then
        echo -e "${GREEN}✅ $role has Ubuntu support${NC}"
    else
        echo -e "${YELLOW}⚠️  $role may need Ubuntu support${NC}"
    fi
done

# Validate Ansible playbook syntax
echo -e "\n${BLUE}Validating Ansible playbook syntax...${NC}"
if command -v ansible-playbook >/dev/null 2>&1; then
    if ansible-playbook --syntax-check install/main.yaml >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Ansible playbook syntax is valid${NC}"
    else
        echo -e "${RED}❌ Ansible playbook has syntax errors${NC}"
        ((failed_roles++))
    fi
else
    echo -e "${YELLOW}⚠️  ansible-playbook not available for syntax check${NC}"
fi

# Summary
echo -e "\n${BLUE}Validation Summary:${NC}"
if [ $failed_roles -eq 0 ]; then
    echo -e "${GREEN}🎉 All validations passed! Linux compatibility looks good.${NC}"
    echo -e "${GREEN}Your dotfiles should now work on Linux systems.${NC}"
    echo -e "\n${BLUE}To test the actual installation:${NC}"
    echo "1. On Ubuntu/Debian: sudo apt install ansible git curl"
    echo "2. Run: bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/bin/dotfiles)\""
else
    echo -e "${RED}❌ $failed_roles issue(s) found. Please check the output above.${NC}"
    exit 1
fi
