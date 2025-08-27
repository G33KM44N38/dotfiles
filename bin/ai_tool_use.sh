#!/bin/zsh
set -euo pipefail # Exit on error, unset variables, and pipefail

AUDIO_FILE="$HOME/.sound/tool_use.mp3"

# === Vérifie que le fichier audio existe ===
if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "❌ Le fichier audio '$AUDIO_FILE' n'existe pas." >&2
  exit 1
fi

# === Vérifie ffplay ===
if ! command -v ffplay &> /dev/null; then
  echo "❌ 'ffplay' est requis pour lire l'audio." >&2
  echo "➡️  Installe-le avec Homebrew :" >&2
  echo "    brew install ffmpeg" >&2
  exit 1
fi

# === Joue l'audio avec ffplay ===
ffplay -nodisp -autoexit "$AUDIO_FILE" &>/dev/null

