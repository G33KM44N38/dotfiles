#!/bin/bash

# List of files and directories to check and potentially decrypt
FILES_TO_CHECK=(
  ".ssh"
  ".zshrc"
)

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

# Function to decrypt file with Ansible Vault
decrypt_with_ansible_vault() {
  local file="$1"
  echo "Decrypting $file with Ansible Vault..."
  
  if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
    echo "Warning: Vault password file not found at $VAULT_PASSWORD_FILE. Skipping decryption for $file." >&2
    return 1
  fi

  if ! ansible-vault decrypt --vault-password-file="$VAULT_PASSWORD_FILE" "$file"; then
    echo "Error: Failed to decrypt $file" >&2
    return 1
  fi
  return 0
}

# Function to check and decrypt files in a directory recursively
check_and_decrypt_files() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    return
  fi

  shopt -s dotglob
  for file in "$dir"/*; do
    if [ -d "$file" ]; then
      check_and_decrypt_files "$file"
      continue
    fi

    if [ ! -f "$file" ]; then
      continue
    fi

    if is_ansible_vault_encrypted "$file"; then
      if decrypt_with_ansible_vault "$file"; then
        git restore --staged "$file" 2>/dev/null || true # Unstage if it was staged
      fi
    fi
  done
  shopt -u dotglob
}

# Check files and directories in the list
for item in "${FILES_TO_CHECK[@]}"; do
  if [ -d "$item" ]; then
    check_and_decrypt_files "$item"
  else
    if [ ! -f "$item" ]; then
      continue
    fi
    
    if is_ansible_vault_encrypted "$item"; then
      if decrypt_with_ansible_vault "$item"; then
        git restore --staged "$item" 2>/dev/null || true # Unstage if it was staged
      fi
    fi
  fi
done

exit 0