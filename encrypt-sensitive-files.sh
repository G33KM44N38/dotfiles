#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# List of files and directories to check and potentially encrypt
FILES_TO_CHECK=(
  ".ssh"
  ".zshrc"
  ".group_env"
  "settings.json"
  "raycast/config.json")

# Path to the Ansible Vault password file
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-$HOME/.ansible-vault/vault.secret}"

# Function to check if a file is encrypted with Ansible Vault
is_ansible_vault_encrypted() {
  local file="$1"
  if head -n 1 "$file" 2>/dev/null | grep -q "\$ANSIBLE_VAULT;" ; then
    return 0
  else
    return 1
  fi
}

# Function to encrypt file with Ansible Vault
encrypt_with_ansible_vault() {
  local file="$1"

  if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
    echo "Warning: Vault password file not found at $VAULT_PASSWORD_FILE. Skipping encryption for $file." >&2
    return 1
  fi

  if ! ansible-vault encrypt --vault-password-file="$VAULT_PASSWORD_FILE" "$file"; then
    echo "Error: Failed to encrypt $file" >&2
    return 1
  fi
  return 0
}

# Function to check and encrypt files in a directory recursively
check_and_encrypt_files() {
  local dir="$1"
  
  if [ ! -d "$dir" ]; then
    return
  fi

  shopt -s dotglob
  for file in "$dir"/*; do
    if [ -d "$file" ]; then
      check_and_encrypt_files "$file"
      continue
    fi

    if [ ! -f "$file" ]; then
      continue
    fi

    if git diff --cached --name-only | grep -q "^$(echo "$file" | sed 's/^\.\///')$"; then
      if is_ansible_vault_encrypted "$file"; then
        continue
      fi

      if encrypt_with_ansible_vault "$file"; then
        git add "$file"
        echo -e "${GREEN}Encrypted and staged: $file${NC}"
      fi
    fi
  done
  shopt -u dotglob
}

# Check files and directories in the list
for item in "${FILES_TO_CHECK[@]}"; do
  
  if [ -d "$item" ]; then
    check_and_encrypt_files "$item"
  else
    if git diff --cached --name-only | grep -q "^$item$"; then

      if [ ! -f "$item" ]; then
        continue
      fi
      
      if is_ansible_vault_encrypted "$item"; then
        continue
      fi
      
      if encrypt_with_ansible_vault "$item"; then
        git add "$item"
        echo -e "${GREEN}Encrypted and staged: $item${NC}"
      fi
    fi
  fi
done

exit 0
