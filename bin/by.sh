#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title  bye
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 👋🏾

# Documentation:
# @raycast.description  bye
# @raycast.author me
#

arc-cli select-space-name master
pkill -TERM "Brave Browser"
pkill -TERM "QuickTime Player"
pkill -TERM "Telegram"
open raycast://extensions/raycast/system/eject-all-disks
open -a "iTerm"
open -a "Arc"

# vi:ft=sh:
