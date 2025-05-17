#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Nuke Session
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 💣

# Documentation:
# @raycast.description Force quit user processes, restart Mouseless, AeroSpace, and relaunch Raycast.
# @raycast.author Kylian

### 🧨 Étape 1 : Kill processus utilisateur ###
echo "Killing all user processes..."
pkill -u "$USER"

### 🛠 Étape 2 : Restart Mouseless ###
SCRIPT_PATH="./kill_restart_mouseless.sh"
if [[ -x "$SCRIPT_PATH" ]]; then
  echo "Restarting Mouseless..."
  "$SCRIPT_PATH"
else
  echo "⚠️ Mouseless script not found or not executable. Skipping."
fi

### 🌀 Étape 3 : Restart AeroSpace ###
echo "Restarting AeroSpace..."
pkill -x "AeroSpace"
sleep 1
open -a "AeroSpace"

### 🚀 Étape 4 : Relancer Raycast ###
echo "Relaunching Raycast..."
open -a "Raycast"

echo "✅ Done."
