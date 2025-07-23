#!/bin/bash
find "$HOME/.dotfiles/.group_env" -type f -print | fzf | xargs -r nvim
