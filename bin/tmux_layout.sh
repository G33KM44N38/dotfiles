#!/bin/bash

tmux rename-window 'nvim'
tmux send-keys -R "nvim ." C-m
# tmux kill-window -t 3
# tmux kill-window -t 2
tmux new-window -n 'run'
tmux new-window -n 'process'
tmux select-window -t 1
