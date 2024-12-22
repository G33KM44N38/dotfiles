#!/bin/bash

# List of files and directories to check and potentially encrypt
FILES_TO_CHECK=(
  "./.ssh/"  # Directory to check all files inside
  "./.zshrc"          # Individual file to check
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
  echo "Encrypting $file with Ansible Vault..."
  
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
}

# Function to check and encrypt files in a directory
check_and_encrypt_files() {
  local dir="$1"
  # Check if the directory exists
  if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist. Skipping."
    return
  fi

  # Iterate over all files in the directory, including hidden ones
  shopt -s dotglob  # Include hidden files
  for file in "$dir"/*; do
    # Skip if it's a directory
    if [ -d "$file" ]; then
      # Recursively check files in the subdirectory
      check_and_encrypt_files "$file"
      continue
    fi

    # Check if the file exists
    if [ ! -f "$file" ]; then
      echo "File $file does not exist. Skipping."
      continue
    fi

    echo "Checking $file..."
    
    # Check if file is already encrypted
    if is_ansible_vault_encrypted "$file"; then
      echo "$file is already encrypted. Proceeding with commit."
      continue
    fi
    
    # Encrypt the file
    encrypt_with_ansible_vault "$file"
    
    # Stage the newly encrypted file
    git add "$file"
  done
  shopt -u dotglob  # Disable dotglob
}

# Check staged files
for item in "${FILES_TO_CHECK[@]}"; do
  if [ -d "$item" ]; then
    # If it's a directory, check all files inside it
    check_and_encrypt_files "$item"
  else
    # Check if the item is staged
    if git diff --cached --name-only | grep -q "$item"; then
      echo "Checking $item..."
      
      # Check if file exists
      if [ ! -f "$item" ]; then
        echo "File $item does not exist. Skipping."
        continue
      fi
      
      # Check if file is already encrypted
      if is_ansible_vault_encrypted "$item"; then
        echo "$item is already encrypted. Proceeding with commit."
        continue
      fi
      
      # Encrypt the file
      encrypt_with_ansible_vault "$item"
      
      # Stage the newly encrypted file
      git add "$item"
    else
      echo "$item is not staged. Consider staging it for encryption."
    fi
  fi
done

exit 0
