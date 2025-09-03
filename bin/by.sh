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
pkill -TERM "Safari"
pkill -TERM "Finder"
open raycast://extensions/raycast/system/eject-all-disks

# vi:ft=sh:
