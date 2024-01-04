#!/bin/bash

chsh -s /bin/bash

# Function to log messages
log() {
  echo "$(date) - $1" >> /var/log/custom_uninstall.log
}

# Uninstall Oh My Zsh
log "Uninstalling Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/uninstall.sh)"
if [ $? -ne 0 ]; then
  log "Error: Oh My Zsh uninstallation failed"
  exit 1
fi

# Uninstall Ansible
log "Uninstalling Ansible..."
brew uninstall ansible
if [ $? -ne 0 ]; then
  log "Error: Ansible uninstallation failed"
  exit 1
fi

# Uninstall Python
log "Uninstalling Python..."
brew uninstall python
if [ $? -ne 0 ]; then
  log "Error: Python uninstallation failed"
  exit 1
fi

# Uninstall Homebrew
log "Uninstalling Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
if [ $? -ne 0 ]; then
  log "Error: Homebrew uninstallation failed"
  exit 1
fi

log "Uninstallation completed successfully"
