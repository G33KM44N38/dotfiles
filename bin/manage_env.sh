#!/bin/bash
find "$HOME/.group_env" -type f -print | fzf | xargs -r nvim
