#!/bin/bash

# Step 1: Update, upgrade, and clean up Homebrew
brew update && brew upgrade && brew cleanup

# Step 2: Run Brew doctor for general maintenance
brew doctor

# Step 3: Remove unused local volumes
docker volume prune

# Step 4: Empty the trash
rm -rf ~/.Trash/*

# Step 5: Check available disk space
df -h

# clear git branches
cd ~ && find . -type d -execdir test -e "{}/.git" && bash -c 'cd "{}" && echo WORKING ON "{}" && git branch --merged master | grep -v "\* master" | xargs -n 1 git branch -d' \;
