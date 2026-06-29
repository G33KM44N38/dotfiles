#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-thread-picker"
binary="$cache_dir/tmux-thread-picker"
source_file="$script_dir/tmux-thread-picker.go"

mkdir -p "$cache_dir"
if [ ! -x "$binary" ] || [ "$source_file" -nt "$binary" ]; then
	tmp_binary="$binary.$$"
	(cd "$script_dir/.." && go build -o "$tmp_binary" "$source_file")
	mv "$tmp_binary" "$binary"
fi

export TMUX_THREAD_PICKER_ENTRYPOINT="${TMUX_THREAD_PICKER_ENTRYPOINT:-$0}"
exec "$binary" "$@"
