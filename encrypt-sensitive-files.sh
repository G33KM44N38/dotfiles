#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# List of files and directories to check and potentially encrypt
FILES_TO_CHECK=(
  ".ssh"  # Directory to check all files inside
  ".zshrc" # Individual file to check
)

# Path to the Ansible Vault password file
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-$HOME/.vault-password}"

# Function to check if a file is encrypted with Ansible Vault
is_ansible_vault_encrypted() {
  local file="$1"
  # Check if the file starts with $ANSIBLE_VAULT header
  if head -n 1 "$file" | grep -q "\$ANSIBLE_VAULT;" ; then
    return 0  # File is encrypted
  else
    return 1  # File is not encrypted
  fi
}

# Function to encrypt file with Ansible Vault
encrypt_with_ansible_vault() {
  local file="$1"

  # Check if password file exists
  if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
    echo "Error: Vault password file not found at $VAULT_PASSWORD_FILE" >&2
    exit 1
  fi

  # Encrypt using the specified password file
  if ! ansible-vault encrypt --vault-password-file="$VAULT_PASSWORD_FILE" "$file"; then
    echo "Error: Failed to encrypt $file" >&2
    exit 1
  fi
}

# Function to check and encrypt files in a directory recursively
check_and_encrypt_files() {
  local dir="$1"
  
  # Check if the directory exists
  if [ ! -d "$dir" ]; then
    echo "Error: Directory $dir does not exist." >&2
    return
  fi

  # Iterate over all files in the directory, including hidden ones
  shopt -s dotglob  # Include hidden files
  for file in "$dir"/*; do
    # If it's a directory, check files inside it recursively
    if [ -d "$file" ]; then
      check_and_encrypt_files "$file"
      continue
    fi

    # Check if the file exists
    if [ ! -f "$file" ]; then
      echo "Error: File $file does not exist." >&2
      continue
    fi

    if git diff --cached --name-only | grep -q "$file$"; then
      # Check if the file is already encrypted
      if is_ansible_vault_encrypted "$file"; then
        continue
      fi

      # Encrypt the file
      encrypt_with_ansible_vault "$file"

      # Stage the newly encrypted file
      git add "$file"
    fi
  done
  shopt -u dotglob  # Disable dotglob
}

# Check files and directories in the list
for item in "${FILES_TO_CHECK[@]}"; do
  
  if [ -d "$item" ]; then
    # If it's a directory, check all files inside it recursively
    check_and_encrypt_files "$item"
  else
    # Check if the item is staged using the full path
    if git diff --cached --name-only | grep -q "^$item$"; then

      # Check if file exists
      if [ ! -f "$item" ]; then
        echo "Error: File $item does not exist." >&2
        continue
      fi
      
      # Check if the file is already encrypted
      if is_ansible_vault_encrypted "$item"; then
        continue
      fi
      
      # Encrypt the file
      encrypt_with_ansible_vault "$item"
      
      # Stage the newly encrypted file
      git add "$item"
    else
      echo "Error: $item is not staged." >&2
    fi
  fi
done

exit 0
