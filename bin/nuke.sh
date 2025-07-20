#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Nuke Session
# @raycast.mode compact
# @raycast.icon 💣
# @raycast.description Force quit user processes, restart Mouseless, AeroSpace, and relaunch Raycast.
# @raycast.author Kylian

ESSENTIAL_APPS=("Mouseless" "AeroSpace" "Raycast" "$0" "$SHELL")

echo "🧨 Killing all non-essential user processes..."

# Liste tous les PID de l'utilisateur
user_pids=($(pgrep -u "$USER"))

for pid in "${user_pids[@]}"; do
  # Récupérer le nom de la commande/process
  cmd=$(ps -p $pid -o comm= | xargs basename)

  # Skip les processus essentiels
  skip=false
  for keep in "${ESSENTIAL_APPS[@]}"; do
    # Attention $0 c'est le chemin du script, on ne kill pas le script ni le shell courant
    if [[ "$cmd" == "$keep" ]]; then
      skip=true
      break
    fi
  done

  if $skip; then
    echo "⚠️ Skipping essential process: $cmd ($pid)"
  else
    echo "Killing process: $cmd ($pid)"
    kill -9 $pid 2>/dev/null
  fi
done

# Vérification que les processus indésirables sont bien tués
echo "⏳ Waiting for processes to terminate..."

max_wait=10
while (( max_wait > 0 )); do
  # Vérifier s’il reste des processus non essentiels en vie
  remaining=0
  for pid in $(pgrep -u "$USER"); do
    cmd=$(ps -p $pid -o comm= | xargs basename)
    skip=false
    for keep in "${ESSENTIAL_APPS[@]}"; do
      if [[ "$cmd" == "$keep" ]]; then
        skip=true
        break
      fi
    done
    if ! $skip; then
      ((remaining++))
    fi
  done

  if (( remaining == 0 )); then
    echo "✅ All non-essential processes killed."
    break
  else
    echo "⏳ Still $remaining processes alive, waiting..."
    sleep 1
    ((max_wait--))
  fi
done

if (( remaining > 0 )); then
  echo "⚠️ Warning: Some processes could not be killed."
fi

# Relance Mouseless
SCRIPT_PATH="./kill_restart_mouseless.sh"
if [[ -x "$SCRIPT_PATH" ]]; then
  echo "🔄 Restarting Mouseless..."
  "$SCRIPT_PATH"
else
  echo "⚠️ Mouseless restart script not found or not executable. Skipping."
fi

# Relance AeroSpace
echo "🔄 Restarting AeroSpace..."
pkill -x "AeroSpace" 2>/dev/null
sleep 1
open -a "AeroSpace"

# Relance Raycast
echo "🔄 Relaunching Raycast..."
open -a "Raycast"

echo "✅ Done."
