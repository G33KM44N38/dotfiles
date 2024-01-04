#!/bin/bash

#color codes
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE="\\033[38;5;27m"
SEA="\\033[38;5;49m"
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

#emoji codes
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
X_MARK="${RED}\xE2\x9C\x96${NC}"
PIN="${RED}\xF0\x9F\x93\x8C${NC}"
CLOCK="${GREEN}\xE2\x8C\x9B${NC}"
ARROW="${SEA}\xE2\x96\xB6${NC}"
BOOK="${RED}\xF0\x9F\x93\x8B${NC}"
HOT="${ORANGE}\xF0\x9F\x94\xA5${NC}"
WARNING="${RED}\xF0\x9F\x9A\xA8${NC}"
RIGHT_ANGLE="${GREEN}\xE2\x88\x9F${NC}"


#path
DOTFILES_DIR="$HOME/.dotfiles"

set -e

# Function to handle errors
handle_error() {
  local exit_code=$1
  local error_message=$2
  if [ $exit_code -ne 0 ]; then
    echo "Error: $error_message" >&2
    exit 1
  fi
}

# Clone repository
if ! [[ -d "$DOTFILES_DIR" ]]; then
    echo -e "${ARROW} ${CYAN}Cloning repository: ${YELLOW}github.com/G33KM44N38/dotfiles${NC}"
    git clone --quiet "https://github.com/G33KM44N38/dotfiles" "$DOTFILES_DIR" 2>&1 > /dev/null
else
    echo -e "${ARROW} ${CYAN}Updating repository: ${YELLOW}github.com/TechDufus/dotfiles${NC}"
    git -C "$DOTFILES_DIR" pull --quiet > /dev/null
fi

# Check if Homebrew is installed
if ! command -v brew &> /dev/null
then
    echo "${ARROW} ${CYAN} Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    handle_error $? "Homebrew installation failed"
fi

# Add Homebrew to the PATH
echo 'which brew' >> /Users/kylianmayanga/.zprofile

# Install Ansible
echo "${ARROW} ${CYAN} Installing Ansible..."
brew install ansible
handle_error $? "Ansible installation failed"


# Run the Ansible playbook
echo "${ARROW} ${CYAN} Running the Ansible playbook..."
ansible-playbook ~/.dotfiles/.config/install/main.yaml --ask-become-pass
handle_error $? "Ansible playbook execution failed"

echo "${ARROW} ${CYAN} Installation and playbook execution completed successfully"
