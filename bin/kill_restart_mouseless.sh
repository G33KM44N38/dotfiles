#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title  kill restart mouseless
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🐁

# Documentation:
# @raycast.description  kill restart mouseless
# @raycast.author me
#

pkill -f "mouseless" 
open -a "mouseless"
# vi:ft=sh:
