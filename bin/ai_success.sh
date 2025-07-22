#!/bin/zsh
set -euo pipefail # Exit on error, unset variables, and pipefail

YOUTUBE_URL="https://www.youtube.com/watch?v=fdJ2tZ71hoc"

# Define a preferred persistent installation path for yt-dlp
YTDLP_PERSISTENT_PATH="$HOME/.local/bin/yt-dlp"
YTDLP="" # Initialize YTDLP variable

# === Check for yt-dlp ===
if command -v yt-dlp &> /dev/null; then
  YTDLP="yt-dlp" # Use system-wide yt-dlp if available
elif [[ -x "$YTDLP_PERSISTENT_PATH" ]]; then
  YTDLP="$YTDLP_PERSISTENT_PATH" # Use the persistently downloaded yt-dlp if it's executable
else
  mkdir -p "$(dirname "$YTDLP_PERSISTENT_PATH")" # Ensure the directory exists

  if ! curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o "$YTDLP_PERSISTENT_PATH"; then
    # Attempt to download to the persistent path failed
    if ! curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /tmp/yt-dlp; then
      # Both persistent and temporary downloads failed
      echo "❌ Échec du téléchargement de yt-dlp. Veuillez l'installer manuellement." >&2
      echo "   (e.g., brew install yt-dlp ou pip install yt-dlp)" >&2
      exit 1
    else
      chmod +x /tmp/yt-dlp
      YTDLP="/tmp/yt-dlp"
    fi
  else
    chmod +x "$YTDLP_PERSISTENT_PATH"
    YTDLP="$YTDLP_PERSISTENT_PATH"
  fi
fi

# === Vérifie ffplay ===
if ! command -v ffplay &> /dev/null; then
  echo "❌ 'ffplay' est requis pour lire l'audio." >&2
  echo "➡️  Installe-le avec Homebrew :" >&2
  echo "    brew install ffmpeg" >&2
  exit 1
fi

# === Extrait l'URL directe de l'audio ===
AUDIO_URL="$("$YTDLP" -f bestaudio --get-url "$YOUTUBE_URL" 2>/dev/null)"

if [[ -z "$AUDIO_URL" ]]; then
  echo "❌ Échec de l'extraction de l'URL audio. Vérifiez la connexion ou l'URL YouTube." >&2
  exit 1
fi

# === Joue l'audio avec ffplay ===
ffplay -nodisp -autoexit "$AUDIO_URL" &>/dev/null
