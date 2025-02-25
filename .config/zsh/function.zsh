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

# Add this to your ~/.zshrc file

# Function to parse package.json and provide completions
_package_json_completion() {
  local curcontext="$curcontext" state line
  typeset -A opt_args

  _arguments \
    '1: :->command' \
    '*: :->argument'

  case $state in
    command)
      local commands
      commands=($(jq -r 'keys | .[]' package.json 2>/dev/null))
      _describe -t commands 'package.json commands' commands
      ;;
    argument)
      case $words[2] in
        scripts)
          local scripts
          scripts=($(jq -r '.scripts | keys | .[]' package.json 2>/dev/null))
          _describe -t scripts 'npm scripts' scripts
          ;;
        dependencies|devDependencies)
          local deps
          deps=($(jq -r ".$words[2] | keys | .[]" package.json 2>/dev/null))
          _describe -t dependencies "$words[2]" deps
          ;;
      esac
      ;;
  esac
}

# Define the completion for package.json
compdef _package_json_completion jq -c '.' package.json

# neofetch
