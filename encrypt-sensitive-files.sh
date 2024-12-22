#!/bin/bash

# List of files to check and potentially encrypt
FILES_TO_CHECK=(
  "secrets.yml"
  "credentials.json"
  "sensitive_config.txt"
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
  ansible-vault encrypt --vault-password-file="$VAULT_PASSWORD_FILE" "$file"
}

# Check staged files
for file in "${FILES_TO_CHECK[@]}"; do
  # Check if the file is staged
  if git diff --cached --name-only | grep -q "$file"; then
    echo "Checking $file..."
    
    # Check if file exists
    if [ ! -f "$file" ]; then
      echo "File $file does not exist. Skipping."
      continue
    fi
    
    # Check if file is already encrypted
    if is_ansible_vault_encrypted "$file"; then
      echo "$file is already encrypted. Proceeding with commit."
      continue
    fi
    
    # Encrypt the file
    encrypt_with_ansible_vault "$file"
    
    # Stage the newly encrypted file
    git add "$file"
  fi
done

exit 0
