#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Reconnecter les AirPods
# @raycast.mode compact
# @raycast.packageName AirPods
# @raycast.description Reprend les AirPods sur ce Mac après un appel téléphonique

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_file="$script_dir/lib/bluetooth-connect.m"
helper_dir="$HOME/.local/lib/bluetooth-connect"
helper="$helper_dir/bluetooth-connect"

if [[ ! -x "$helper" || "$source_file" -nt "$helper" ]]; then
    mkdir -p "$helper_dir"
    build_file="$(mktemp "$helper_dir/build.XXXXXX")"
    trap 'rm -f "$build_file"' EXIT
    /usr/bin/clang -Wall -Wextra -Werror -fobjc-arc \
        -framework Foundation -framework IOBluetooth \
        "$source_file" -o "$build_file"
    chmod +x "$build_file"
    mv -f "$build_file" "$helper"
    trap - EXIT
fi

airpods_name="${AIRPODS_NAME:-Kylian’s AirPods Pro}"
if [[ -n "${AIRPODS_ADDRESS:-}" ]]; then
    "$helper" "$AIRPODS_ADDRESS"
else
    "$helper"
fi

switch_audio="$(command -v SwitchAudioSource || true)"
if [[ -z "$switch_audio" && -x /opt/homebrew/bin/SwitchAudioSource ]]; then
    switch_audio=/opt/homebrew/bin/SwitchAudioSource
fi
if [[ -z "$switch_audio" ]]; then
    echo "AirPods connectés, mais SwitchAudioSource est introuvable." >&2
    echo "Installe switchaudio-osx pour forcer aussi la sortie audio." >&2
    exit 1
fi

for attempt in {1..10}; do
    if "$switch_audio" -s "$airpods_name" -t output >/dev/null 2>&1; then
        if current_output="$("$switch_audio" -c -t output 2>/dev/null)" && \
            [[ "$current_output" == "$airpods_name" ]]; then
            printf '%s\n' "$airpods_name est maintenant la sortie audio du Mac."
            exit 0
        fi
    fi
    sleep 0.3
done

echo "AirPods connectés, mais macOS n'a pas sélectionné leur sortie audio." >&2
exit 1
