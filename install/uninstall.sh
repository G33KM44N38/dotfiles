#!/bin/bash

# Function to log messages
log() {
  echo "$(date) - $1" 
}

# Function to check for errors and log messages
check_error() {
  if [ $1 -ne 0 ]; then
    log "Error: $2 failed"
    exit 1
  fi
}

# Set the default shell to bash
chsh -s /bin/bash
check_error $? "Changing default shell to bash"

# Run the Ansible playbook
echo "Running the Ansible playbook..."
ansible-playbook ~/.dotfiles/.config/install/uninstall.yaml --ask-become-pass
handle_error $? "Ansible playbook execution failed"


# Uninstall Homebrew
log "Uninstalling Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
check_error $? "Homebrew uninstallation"

log "Uninstallation completed successfully"
