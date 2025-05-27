#!/usr/bin/env bash

# Secure tmux directory switcher script
# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# Function to log errors
log_error() {
    echo "Error: $1" >&2
}

# Function to validate directory exists and is accessible
validate_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_error "Directory does not exist: $dir"
        return 1
    fi
    if [[ ! -r "$dir" ]]; then
        log_error "Directory is not readable: $dir"
        return 1
    fi
    return 0
}

# Function to sanitize session name
sanitize_session_name() {
    local name="$1"
    # Remove any characters that could be problematic for tmux session names
    # Keep only alphanumeric, underscore, hyphen, and dot
    echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/^[._-]*//' | sed 's/[._-]*$//'
}

# Function to check if tmux is available
check_tmux_available() {
    if ! command -v tmux >/dev/null 2>&1; then
        log_error "tmux is not installed or not in PATH"
        exit 1
    fi
}

# Function to check if fzf is available (when needed)
check_fzf_available() {
    if ! command -v fzf >/dev/null 2>&1; then
        log_error "fzf is not installed or not in PATH (required for directory selection)"
        exit 1
    fi
}

# Define allowed base directories (whitelist approach)
declare -a ALLOWED_DIRS=(
    "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
    "$HOME/backup"
    "$HOME/coding"
    "$HOME/coding/work/baba_coiffure"
    "$HOME/coding/work"
    "$HOME/goinfre"
    "$HOME/.dotfiles"
    "$HOME/.dotfiles/.config"
)

# Function to check if a directory is within allowed paths
is_allowed_directory() {
    local target="$1"
    local real_target
    
    # Resolve to absolute path to prevent directory traversal
    if ! real_target=$(realpath "$target" 2>/dev/null); then
        log_error "Cannot resolve path: $target"
        return 1
    fi
    
    # Check if the resolved path starts with any allowed directory
    for allowed_dir in "${ALLOWED_DIRS[@]}"; do
        local real_allowed
        if real_allowed=$(realpath "$allowed_dir" 2>/dev/null); then
            if [[ "$real_target" == "$real_allowed"* ]]; then
                return 0
            fi
        fi
    done
    
    log_error "Directory not in allowed paths: $real_target"
    return 1
}

# Function to find directories safely
find_directories() {
    local dirs=()
    
    # Only search in directories that exist and are accessible
    for dir in "${ALLOWED_DIRS[@]}"; do
        if [[ -d "$dir" && -r "$dir" ]]; then
            # Use -print0 and process with while loop to handle spaces in filenames
            while IFS= read -r -d '' directory; do
                if validate_directory "$directory"; then
                    dirs+=("$directory")
                fi
            done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
        fi
    done
    
    # Also add .dotfiles subdirectories if they exist
    if [[ -d "$HOME/.dotfiles" && -r "$HOME/.dotfiles" ]]; then
        while IFS= read -r -d '' directory; do
            if validate_directory "$directory"; then
                dirs+=("$directory")
            fi
        done < <(find "$HOME/.dotfiles" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
    fi
    
    # Print directories for fzf
    printf '%s\n' "${dirs[@]}"
}

main() {
    local selected=""
    
    # Check if tmux is available
    check_tmux_available
    
    # Handle directory selection
    if [[ $# -eq 1 ]]; then
        selected="$1"
        
        # Validate the provided directory
        if ! is_allowed_directory "$selected"; then
            exit 1
        fi
        
        if ! validate_directory "$selected"; then
            exit 1
        fi
    else
        # Check if fzf is available for interactive selection
        check_fzf_available
        
        # Use fzf to select directory
        if ! selected=$(find_directories | fzf --prompt="Select directory: " --height=40% --reverse); then
            echo "No directory selected" >&2
            exit 0
        fi
        
        # Double-check the selected directory (defense in depth)
        if ! is_allowed_directory "$selected"; then
            exit 1
        fi
    fi
    
    # Ensure we have a valid selection
    if [[ -z "$selected" ]]; then
        echo "No directory selected" >&2
        exit 0
    fi
    
    # Clean up the path by removing trailing slashes
    selected="${selected%/}"
    
    # Create a safe session name
    local selected_name
    selected_name=$(sanitize_session_name "$(basename "$selected")")
    
    # Ensure session name is not empty after sanitization
    if [[ -z "$selected_name" ]]; then
        selected_name="default_session"
    fi
    
    # Check if already in a tmux session
    if [[ -z "${TMUX:-}" ]]; then
        # Not in tmux session
        if tmux has-session -t="$selected_name" 2>/dev/null; then
            tmux attach-session -t "$selected_name"
        else
            tmux new-session -s "$selected_name" -c "$selected"
        fi
    else
        # Already in tmux session
        if tmux has-session -t="$selected_name" 2>/dev/null; then
            tmux switch-client -t "$selected_name"
        else
            tmux new-session -d -s "$selected_name" -c "$selected"
            tmux switch-client -t "$selected_name"
        fi
    fi
}

# Run main function with all arguments
main "$@"
