#!/usr/bin/env basH

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

    # Generate the list for fzf, prefixing existing tmux sessions
    fzf_input=""
    # Use process substitution to feed find output line by line
    while IFS= read -r dir; do
        # Clean up the path by removing trailing slashes for basename
        clean_dir=$(echo "$dir" | sed 's:/*$::')
        dir_name=$(basename "$clean_dir" | tr . _)
        # Check if the session name exists in the pre-fetched list
        if echo "$existing_tmux_sessions" | grep -q -E "^${dir_name}$"; then
            fzf_input+="[TMUX] $dir_name	$dir\n" # Display: [TMUX] dir_name, Value: /full/path
        else
            fzf_input+="$dir_name	$dir\n" # Display: dir_name, Value: /full/path
        fi
    done < <(find "${search_paths[@]}" -mindepth 0 -maxdepth 1 -type d)

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
tmux_running=$(pgrep tmux)

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
