# Add directories to PATH
add_to_path() {
    if [[ ! $PATH == *$1* ]]; then
        export PATH=$1:$PATH
    fi
}

add_to_path /usr/local/bin
add_to_path $GOPATH/bin
add_to_path ~/go/bin
add_to_path ~/.local/bin
add_to_path ~/bin
add_to_path ~/.bun/bin

# Add $HOME/.cargo/bin to fish_user_paths
if [[ ! $fish_user_paths == *$HOME/.cargo/bin* ]]; then
    export fish_user_paths=$HOME/.cargo/bin:$fish_user_paths
fi

# Set FZF_COMPLETE to 2 if it's not already set
if [[ -z $FZF_COMPLETE ]]; then
    export FZF_COMPLETE=2
fi

# Set TMUX_CONF to ~/.config/tmux/tmux.conf if it's not already set
if [[ -z $TMUX_CONF ]]; then
    export TMUX_CONF=~/.config/tmux/tmux.conf
    export fish_tmux_config=~/.config/tmux/tmux.conf
fi
