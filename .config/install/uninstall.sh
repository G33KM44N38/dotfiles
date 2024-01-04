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

# Uninstall Oh My Zsh
log "Uninstalling Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/uninstall.sh)"
check_error $? "Oh My Zsh uninstallation"

# Uninstall Ansible
log "Uninstalling Ansible..."
brew uninstall ansible
check_error $? "Ansible uninstallation"

# Uninstall Python
log "Uninstalling Python..."
brew uninstall python
check_error $? "Python uninstallation"

# Uninstall Homebrew
log "Uninstalling Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
check_error $? "Homebrew uninstallation"

log "Uninstallation completed successfully"
