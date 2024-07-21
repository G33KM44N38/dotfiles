# Functions Encryption
encrypt_file() {
    local filename=$1
    sops --encrypt --age $(grep -oE "public key: (.*)" "$SOPS_AGE_KEY_FILE" | sed 's/public key: //') --encrypted-regex '^(data|stringData)$' --in-place "$filename"
}

encrypt_env() {
    local filename=$1
    sops --encrypt --age $(grep -oE "public key: (.*)" "$SOPS_AGE_KEY_FILE" | sed 's/public key: //') -i "$filename"
}

decrypt_file() {
    local filename=$1
    sops --decrypt --age $(grep -oE "public key: (.*)" "$SOPS_AGE_KEY_FILE" | sed 's/public key: //') --encrypted-regex '^(data|stringData)$' --in-place "$filename"
}

decrypt_env() {
    local filename=$1
    sops --decrypt --age $(grep -oE "public key: (.*)" "$SOPS_AGE_KEY_FILE" | sed 's/public key: //') -i "$filename"
}
