#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Connect iPad Sidecar
# @raycast.mode fullOutput
# @raycast.packageName Sidecar
# @raycast.description Connect an available iPad as a Sidecar display
# @raycast.argument1 {"type":"text","placeholder":"iPad name (optional)","optional":true}

# Built from Ocasio-J/SidecarLauncher commit:
# 4b7a9df950a64239b2a073428f0390fc16934a9e
# Uses private Apple APIs; macOS updates may require rebuilding the helper.
set -euo pipefail

launcher="$HOME/.local/lib/sidecar-launcher/SidecarLauncher"
if [[ ! -x "$launcher" ]]; then
  echo "SidecarLauncher is missing: $launcher"
  echo "Install it from https://github.com/Ocasio-J/SidecarLauncher"
  exit 1
fi

device="${1:-}"
if [[ -z "$device" ]]; then
  if devices=$("$launcher" devices 2>&1); then
    if [[ -z "$devices" ]]; then
      echo "No iPad available. Wake and unlock your iPad, then retry."
      exit 1
    fi
  else
    echo "$devices"
    echo "Wake and unlock your iPad, then retry."
    exit 1
  fi
  if [[ "$devices" == *$'\n'* ]]; then
    echo "Several iPads are available. Enter the name in the Raycast argument:"
    echo "$devices"
    exit 1
  fi
  device="$devices"
fi

echo "Connecting to $device…"
if "$launcher" connect "$device"; then
  echo "Sidecar connected."
else
  echo "Connection failed. Check that your iPad is awake and unlocked."
  exit 1
fi
