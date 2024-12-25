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
  echo "Debug: Checking if $file is encrypted..."
  # Check if the file starts with $ANSIBLE_VAULT header
  if head -n 1 "$file" | grep -q "\$ANSIBLE_VAULT;" ; then
    echo "Debug: $file is encrypted."
    return 0  # File is encrypted
  else
    echo "Debug: $file is not encrypted."
    return 1  # File is not encrypted
  fi
}

# Function to encrypt file with Ansible Vault
encrypt_with_ansible_vault() {
  local file="$1"

  echo -e "${GREEN}Encrypting file: $file${NC}"
  
  # Check if password file exists
  if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
    echo "Error: Vault password file not found at $VAULT_PASSWORD_FILE"
    exit 1
  fi

  # Encrypt using the specified password file
  if ! ansible-vault encrypt --vault-password-file="$VAULT_PASSWORD_FILE" "$file"; then
    echo "Error: Failed to encrypt $file"
    exit 1
  fi
  echo "Debug: Successfully encrypted $file."
}

# Function to check and encrypt files in a directory recursively
check_and_encrypt_files() {
  local dir="$1"
  echo "Debug: Checking directory $dir..."
  
  # Check if the directory exists
  if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist. Skipping."
    return
  fi

  # Iterate over all files in the directory, including hidden ones
  shopt -s dotglob  # Include hidden files
  for file in "$dir"/*; do
    # If it's a directory, check files inside it recursively
    if [ -d "$file" ]; then
      echo "Debug: $file is a directory, checking recursively."
      check_and_encrypt_files "$file"
      continue
    fi

    # Check if the file exists
    if [ ! -f "$file" ]; then
      echo "File $file does not exist. Skipping."
      continue
    fi

    if git diff --cached --name-only | grep -q "$file$"; then
      echo "Debug: $file is staged."

      # Check if the file is already encrypted
      if is_ansible_vault_encrypted "$file"; then
        echo "$file is already encrypted. Skipping."
        continue
      fi

      # Encrypt the file
      encrypt_with_ansible_vault "$file"

      # Stage the newly encrypted file
      git add "$file"
      echo "Debug: Staged newly encrypted file $file."
    fi
  done
  shopt -u dotglob  # Disable dotglob
}

# Check files and directories in the list
for item in "${FILES_TO_CHECK[@]}"; do
  echo "Debug: Checking item $item..."
  
  if [ -d "$item" ]; then
    # If it's a directory, check all files inside it recursively
    check_and_encrypt_files "$item"
  else
    echo "======>>>> $item..."
    
    # Check if the item is staged using the full path
    if git diff --cached --name-only | grep -q "^$item$"; then
      echo "Debug: Checking file $item..."

      # Check if file exists
      if [ ! -f "$item" ]; then
        echo "File $item does not exist. Skipping."
        continue
      fi
      
      # Check if the file is already encrypted
      if is_ansible_vault_encrypted "$item"; then
        echo "$item is already encrypted. Skipping."
        continue
      fi
      
      # Log in green before encrypting the file
      echo -e "${GREEN}Encrypting file: $item${NC}"
      
      # Encrypt the file
      encrypt_with_ansible_vault "$item"
      
      # Stage the newly encrypted file
      git add "$item"
      echo "Debug: Staged newly encrypted file $item."
    else
      echo "$item is not staged. Skipping."
    fi
  fi
done

exit 0
