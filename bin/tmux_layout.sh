#!/bin/bash

tmux rename-window 'nvim'
tmux send-keys -R "nvim ." C-m
tmux new-window -n 'run'
tmux new-window -n 'process'
tmux select-window -t 1
