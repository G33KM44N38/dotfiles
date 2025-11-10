#!/bin/bash

# Configuration management for dotfiles script

# Default configuration values
DEFAULT_DOTFILES_REPO="git@github.com:G33KM44N38/dotfiles.git"
DEFAULT_DOTFILES_DIR="$HOME/.dotfiles"
DEFAULT_CONFIG_DIR="$HOME/.dotfiles"
DEFAULT_VAULT_SECRET="$HOME/.ansible-vault/vault.secret"
DEFAULT_DOTFILES_LOG="$HOME/.dotfiles.log"
DEFAULT_IS_FIRST_RUN="$HOME/.dotfiles_run"

# Configuration file locations
SYSTEM_CONFIG="/etc/dotfiles/config"
USER_CONFIG="$HOME/.config/dotfiles/config"
LOCAL_CONFIG="$(dirname "${BASH_SOURCE[0]}")/../config/dotfiles.conf"

# Configuration variables (will be set by load_config)
DOTFILES_REPO=""
DOTFILES_DIR=""
CONFIG_DIR=""
VAULT_SECRET=""
DOTFILES_LOG=""
IS_FIRST_RUN=""

# Load configuration from file
function _load_config_file {
    local config_file="$1"
    
    if [[ -f "$config_file" && -r "$config_file" ]]; then
        # Source the config file in a subshell to validate it first
        if (set -e; source "$config_file") 2>/dev/null; then
            source "$config_file"
            return 0
        else
            _warning "Config file has syntax errors: $config_file"
            return 1
        fi
    fi
    return 1
}

# Set default values for unset configuration
function _set_defaults {
    DOTFILES_REPO="${DOTFILES_REPO:-$DEFAULT_DOTFILES_REPO}"
    DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DOTFILES_DIR}"
    CONFIG_DIR="${CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"
    VAULT_SECRET="${VAULT_SECRET:-$DEFAULT_VAULT_SECRET}"
    DOTFILES_LOG="${DOTFILES_LOG:-$DEFAULT_DOTFILES_LOG}"
    IS_FIRST_RUN="${IS_FIRST_RUN:-$DEFAULT_IS_FIRST_RUN}"
    
    # Expand tilde in paths
    DOTFILES_DIR="${DOTFILES_DIR/#\~/$HOME}"
    CONFIG_DIR="${CONFIG_DIR/#\~/$HOME}"
    VAULT_SECRET="${VAULT_SECRET/#\~/$HOME}"
    DOTFILES_LOG="${DOTFILES_LOG/#\~/$HOME}"
    IS_FIRST_RUN="${IS_FIRST_RUN/#\~/$HOME}"
}

# Validate configuration values
function _validate_config {
    local errors=0
    
    # Validate repository URL
    if [[ ! "$DOTFILES_REPO" =~ ^https?:// ]]; then
        _error "Invalid repository URL: $DOTFILES_REPO"
        ((errors++))
    fi
    
    # Validate directory paths
    local parent_dir
    for path in "$DOTFILES_DIR" "$CONFIG_DIR"; do
        parent_dir=$(dirname "$path")
        if [[ ! -d "$parent_dir" ]]; then
            _error "Parent directory does not exist: $parent_dir (for $path)"
            ((errors++))
        fi
    done
    
    # Check if vault secret directory exists (but not the file itself)
    if [[ -n "$VAULT_SECRET" ]]; then
        local vault_dir=$(dirname "$VAULT_SECRET")
        if [[ ! -d "$vault_dir" ]]; then
            _warning "Vault directory does not exist: $vault_dir"
        fi
    fi
    
    return $errors
}

# Load configuration from multiple sources (precedence: local > user > system > defaults)
function load_config {
    # Try to load from local config first (highest precedence)
    if _load_config_file "$LOCAL_CONFIG"; then
        echo "# Loaded config from: $LOCAL_CONFIG" >&2
    elif _load_config_file "$USER_CONFIG"; then
        echo "# Loaded config from: $USER_CONFIG" >&2
    elif _load_config_file "$SYSTEM_CONFIG"; then
        echo "# Loaded config from: $SYSTEM_CONFIG" >&2
    else
        echo "# Using default configuration" >&2
    fi
    
    # Set defaults for any unset values
    _set_defaults
    
    # Validate the final configuration
    if ! _validate_config; then
        _error "Configuration validation failed"
        return 1
    fi
    
    return 0
}

# Show current configuration
function show_config {
    echo -e "${LBLUE}Current Configuration:${NC}"
    echo -e "  Repository: ${CYAN}$DOTFILES_REPO${NC}"
    echo -e "  Dotfiles Dir: ${CYAN}$DOTFILES_DIR${NC}"
    echo -e "  Config Dir: ${CYAN}$CONFIG_DIR${NC}"
    echo -e "  Vault Secret: ${CYAN}$VAULT_SECRET${NC}"
    echo -e "  Log File: ${CYAN}$DOTFILES_LOG${NC}"
    echo -e "  First Run Flag: ${CYAN}$IS_FIRST_RUN${NC}"
}

# Create a sample configuration file
function create_sample_config {
    local config_file="$1"
    
    if [[ -z "$config_file" ]]; then
        config_file="$LOCAL_CONFIG"
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << 'EOF'
#!/bin/bash
# Dotfiles configuration file

# Repository URL
DOTFILES_REPO="git@github.com:G33KM44N38/dotfiles.git"

# Directory paths (use ~ for home directory)
DOTFILES_DIR="$HOME/.dotfiles"
CONFIG_DIR="$HOME/.dotfiles"

# Ansible vault secret file
VAULT_SECRET="$HOME/.ansible-vault/vault.secret"

# Log file location
DOTFILES_LOG="$HOME/.dotfiles.log"

# First run flag file
IS_FIRST_RUN="$HOME/.dotfiles_run"

# Optional: Override specific Ansible settings
# ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_SECRET"
# ANSIBLE_HOST_KEY_CHECKING=False
EOF
    
    _success "Sample configuration created at: $config_file"
    echo -e "${ARROW} Edit this file to customize your dotfiles setup"
}

# Check if required directories exist and create them if needed
function ensure_directories {
    local dirs=("$(dirname "$DOTFILES_LOG")" "$(dirname "$VAULT_SECRET")")
    
    for dir in "${dirs[@]}"; do
        if [[ -n "$dir" && ! -d "$dir" ]]; then
            _task "Creating directory: $dir"
            if mkdir -p "$dir" 2>/dev/null; then
                _task_done
            else
                _warning "Could not create directory: $dir"
            fi
        fi
    done
}

# Environment setup for external tools
function setup_environment {
    # Set up Ansible environment variables
    if [[ -f "$VAULT_SECRET" ]]; then
        export ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_SECRET"
    fi
    
    # Disable host key checking for automated runs
    export ANSIBLE_HOST_KEY_CHECKING=False
    
    # Set up logging
    export DOTFILES_LOG
}