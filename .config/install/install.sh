#!/bin/bash

# Function to handle errors
handle_error() {
  local exit_code=$1
  local error_message=$2
  if [ $exit_code -ne 0 ]; then
    echo "Error: $error_message"
    exit 1
  fi
}

# Check if Homebrew is installed
if ! command_exists brew; then
  echo "Homebrew is not installed. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  handle_error $? "Homebrew installation failed"
fi

# Add Homebrew to the PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/kylianmayanga/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Python
echo "Installing Python..."
brew install python
handle_error $? "Python installation failed"

# Install Ansible
echo "Installing Ansible..."
brew install ansible
handle_error $? "Ansible installation failed"


#Clone dotfils
echo "Clone dotfiles"
git clone https://github.com/G33KM44N38/dotfiles ~/.dotfiles


# Run the Ansible playbook
echo "Running the Ansible playbook..."
ansible-playbook ~/.dotfiles/.config/install/dev-env.yaml --ask-become-pass
handle_error $? "Ansible playbook execution failed"

# Check if Zsh is installed
if ! command_exists zsh; then
  echo "Zsh is not installed. Installing Zsh..."
  brew install zsh
  handle_error $? "Zsh installation failed"
fi


echo "Installation and playbook execution completed successfully"

