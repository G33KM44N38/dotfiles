#!/usr/bin/env bash

# # Enable debug output
# set -x

if [[ $# -eq 1 ]]; then
    selected=$1
else
    # Construct a list of existing base directories
    declare -a search_paths
    # Use a temporary array for the raw paths to handle glob expansion
    raw_paths=(
        "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/"
        "~/backup/"
        "~/coding/"
        "~/coding/work/"
        "~/coding/perso/"
        "~/goinfre/"
        "~/.dotfiles/"
        "~/.dotfiles/.config/"
    )

    for dir in "${raw_paths[@]}"; do
        # Expand tilde for each path
        expanded_dir=$(eval echo "$dir")
        if [[ -d "$expanded_dir" ]]; then
            search_paths+=("$expanded_dir")
        fi
    done

    # Check if search_paths is empty
    if [[ ${#search_paths[@]} -eq 0 ]]; then
        echo "No valid search directories found." >&2
        exit 1
    fi

    # Get all existing tmux session names once
    existing_tmux_sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)

    # Collect unique directories using find with sort -u
    all_dirs=$(find "${search_paths[@]}" -mindepth 1 -maxdepth 1 -type d | sort -u)

    # Build arrays mapping basenames to paths
    declare -a basenames
    declare -a paths_strings
    while IFS= read -r dir; do
        # Clean up the path by removing trailing slashes for basename
        clean_dir=$(echo "$dir" | sed 's:/*$::')
        dir_name=$(basename "$clean_dir" | tr . _)
        # Find if dir_name already exists
        index=-1
        for ((j=0; j<${#basenames[@]}; j++)); do
            if [[ ${basenames[j]} == "$dir_name" ]]; then
                index=$j
                break
            fi
        done
        if [[ $index -ge 0 ]]; then
            paths_strings[index]+=$'\n'"$clean_dir"
        else
            basenames+=("$dir_name")
            paths_strings+=("$clean_dir")
        fi
    done <<< "$all_dirs"

    # Generate the list for fzf, prefixing existing tmux sessions
    fzf_input=""
    for ((i=0; i<${#basenames[@]}; i++)); do
        basename=${basenames[i]}
        # Split paths by newline instead of space
        paths_str=${paths_strings[i]}
        IFS=$'\n' read -ra paths <<< "$paths_str"

        if [[ ${#paths[@]} -gt 1 ]]; then
            # Basename conflict: use full paths as display names
            for path in "${paths[@]}"; do
                if echo "$existing_tmux_sessions" | grep -q -E "^${basename}$"; then
                    fzf_input+="[TMUX] $path	$path\n"
                else
                    fzf_input+="$path	$path\n"
                fi
            done
        else
            # Unique basename: use basename as display name
            path=${paths[0]}
            if echo "$existing_tmux_sessions" | grep -q -E "^${basename}$"; then
                fzf_input+="[TMUX] $basename	$path\n"
            else
                fzf_input+="$basename	$path\n"
            fi
        fi
    done

    # Check if fzf_input is empty
    if [[ -z "$fzf_input" ]]; then
        echo "No directories found to select from." >&2
        exit 0
    fi

    # Pass to fzf and parse the output
    # --delimiter='\t' tells fzf to use tab as a delimiter for fields
    # --with-nth=1 tells fzf to display and search only on the first field (the display name)
    selected_line=$(echo -e "$fzf_input" | fzf --ansi --delimiter='\t' --with-nth=1)
    
    if [[ -z "$selected_line" ]]; then
        echo "No directory selected" >&2
        exit 0
    fi

    selected=$(echo "$selected_line" | awk -F'	' '{print $2}')
fi

if [[ -z $selected ]]; then
    echo "No directory selected" >&2
    exit 0
fi

selected_name=$(basename "$selected" | tr . _)

# Clean up the path by removing trailing slashes
selected=$(echo "$selected" | sed 's:/*$::')

# Check if already in a tmux session
if [[ -z "$TMUX" ]]; then
    # Not in tmux session
    if tmux has-session -t="$selected_name" 2> /dev/null; then
        tmux attach-session -t "$selected_name"
    else
        tmux new-session -s "$selected_name" -c "$selected"
    fi
else
    # Already in tmux session
    if tmux has-session -t="$selected_name" 2> /dev/null; then
        tmux switch-client -t "$selected_name"
    else
        tmux new-session -d -s "$selected_name" -c "$selected"
        tmux switch-client -t "$selected_name"
    fi
fi
