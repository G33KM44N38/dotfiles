# Consolidate similar blocks
function add_to_path
    if not contains $argv[1] $PATH
        set -ga PATH $PATH $argv[1]
    end
end

# Add directories to PATH
add_to_path /usr/local/bin
add_to_path $GOPATH/bin
add_to_path ~/go/bin
add_to_path ~/.local/bin
add_to_path ~/bin
add_to_path ~/.bun/bin

# Add $HOME/.cargo/bin to fish_user_paths
if not contains $HOME/.cargo/bin $fish_user_paths
    set -Ua fish_user_paths $HOME/.cargo/bin
end

# Set FZF_COMPLETE to 2 if it's not already set
if not set -q FZF_COMPLETE
    set -U FZF_COMPLETE 2
end

# Set TMUX_CONF to ~/.config/tmux/tmux.conf if it's not already set
if not set -q TMUX_CONF
    set -g -x TMUX_CONF ~/.config/tmux/tmux.conf
    set -g -x fish_tmux_config ~/.config/tmux/tmux.conf
end
