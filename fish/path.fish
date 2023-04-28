# Add /usr/local/bin to PATH if it's not already there
if not contains /usr/local/bin $PATH
    set -x PATH $PATH /usr/local/bin
end

# Add $GOPATH/bin to PATH if it's not already there
if not contains $GOPATH/bin $PATH
    set -gx PATH $PATH $GOPATH/bin
end

# Add ~/go/bin to PATH if it's not already there
if not contains ~/go/bin $PATH
    set -gx PATH ~/go/bin $PATH
end

# Add ~/.local/bin to PATH if it's not already there
if not contains ~/.local/bin $PATH
    set -ga PATH $PATH ~/.local/bin
end

# Add $HOME/.cargo/bin to fish_user_paths if it's not already there
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
end

# Add ~/.local/bin to PATH if it's not already there
if not contains ~/bin $PATH
    set -ga PATH $PATH ~/bin
end

set -e fish_tmux_autostarted
set -e fish_tmux_auto_start
set -e _fish_tmux_fixed_config
