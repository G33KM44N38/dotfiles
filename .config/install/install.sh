#!/bin/bash

# Function to handle errors
handle_error() {
  local exit_code=$1
  local error_message=$2
  if [ $exit_code -ne 0 ]; then
    echo "Error: $error_message" >&2
    exit 1
  fi
}

# Check if Homebrew is installed
if ! command -v brew &> /dev/null
then
    echo "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    handle_error $? "Homebrew installation failed"
fi

# Add Homebrew to the PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/kylianmayanga/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Ansible
echo "Installing Ansible..."
brew install ansible
handle_error $? "Ansible installation failed"


# Run the Ansible playbook
echo "Running the Ansible playbook..."
ansible-playbook ~/.dotfiles/.config/install/dev-env.yaml --ask-become-pass
handle_error $? "Ansible playbook execution failed"

echo "Installation and playbook execution completed successfully"
