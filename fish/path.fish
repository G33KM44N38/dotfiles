set -x PATH $PATH /usr/local/bin
set -gx PATH $PATH $GOPATH/bin
set -gx GOPATH ~/go
set -gx PATH /Users/kylianmayanga/go/bin $PATH
set -U FZF_COMPLETE 2
set -x GOPATH ~/go
set -x GOBIN $GOPATH/bin/
set -x PATH $PATH:$GOPATH:$GOBIN
set -U fish_user_paths ~/bin $fish_user_paths
set -g -x TMUX_CONF ~/.config/tmux/tmux.conf
set -ga PATH $PATH /home/kylian/.local/bin
set -Ua fish_user_paths $HOME/.cargo/bin
