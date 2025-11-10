#!/bin/bash

# Online dotfiles installer
# This script handles the installation when run remotely

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 G33KM44N38's Dotfiles Installer${NC}"
echo ""

# Check if we're running remotely (not in the dotfiles directory)
if [[ ! -f "bin/dotfiles" ]]; then
    echo -e "${YELLOW}📥 Running remotely, cloning repository...${NC}"

    # Check if dotfiles already exist
    if [[ -d "$HOME/.dotfiles" ]]; then
        echo -e "${YELLOW}⚠️  Dotfiles directory already exists at ~/.dotfiles${NC}"
        echo -e "${YELLOW}   Updating existing installation...${NC}"
        cd "$HOME/.dotfiles"
        git pull
    else
        echo -e "${GREEN}📥 Cloning dotfiles repository...${NC}"
        git clone "git@github.com:G33KM44N38/dotfiles.git" "$HOME/.dotfiles"
        cd "$HOME/.dotfiles"
    fi

    echo -e "${GREEN}✅ Repository ready${NC}"
    echo ""
fi

# Now run the local installer
echo -e "${BLUE}🔧 Running local installer...${NC}"
exec "./bin/dotfiles" "$@"