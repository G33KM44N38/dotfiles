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

git_safe_delete_candidates() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository" >&2
    return 1
  fi

  local default_base line branch
  local -a worktree_branches

  git fetch origin --prune >/dev/null 2>&1 || return 1
  default_base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)

  while IFS= read -r line; do
    case "$line" in
      "branch refs/heads/"*)
        branch=${line#branch refs/heads/}
        worktree_branches+=("$branch")
        ;;
    esac
  done < <(git worktree list --porcelain)

  git branch --merged "$default_base" --format='%(refname:short)' | while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    case "$branch" in
      main|master|develop|dev|release|v2) continue ;;
    esac

    if print -r -l -- "${worktree_branches[@]}" | grep -Fqx -- "$branch"; then
      continue
    fi

    printf '%-50s merged into %s\n' "$branch" "$default_base"
  done
}
