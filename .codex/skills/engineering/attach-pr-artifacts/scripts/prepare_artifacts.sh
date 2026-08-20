#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: prepare_artifacts.sh [--output-dir DIR] FILE..." >&2
  exit 2
}

output_dir="/tmp/github-pr-artifacts"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ $# -ge 2 ]] || usage
      output_dir="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -gt 0 ]] || usage

bytes_for() {
  if stat -f '%z' "$1" >/dev/null 2>&1; then
    stat -f '%z' "$1"
  else
    stat -c '%s' "$1"
  fi
}

absolute_path() {
  local parent name
  parent=$(dirname "$1")
  name=$(basename "$1")
  printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$name"
}

unique_video_path() {
  local stem="$1" candidate counter=2
  candidate="$output_dir/${stem}-github.mp4"
  while [[ -e "$candidate" ]]; do
    candidate="$output_dir/${stem}-github-${counter}.mp4"
    counter=$((counter + 1))
  done
  printf '%s\n' "$candidate"
}

image_limit=$((10 * 1024 * 1024))
free_video_limit=$((10 * 1024 * 1024))
paid_video_limit=$((100 * 1024 * 1024))

for input in "$@"; do
  [[ -f "$input" ]] || { echo "ERROR\tnot a regular file\t$input" >&2; exit 1; }

  path=$(absolute_path "$input")
  filename=$(basename "$path")
  extension=${filename##*.}
  extension=$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')
  size=$(bytes_for "$path")

  case "$extension" in
    png|gif|jpg|jpeg|svg)
      if (( size > image_limit )); then
        echo "ERROR\timage exceeds GitHub's 10 MB limit\t$path" >&2
        exit 1
      fi
      printf 'READY\timage\t%s\t%s\n' "$size" "$path"
      ;;
    mp4|mov|webm)
      command -v ffprobe >/dev/null 2>&1 || { echo "ERROR\tffprobe is required for videos\t$path" >&2; exit 1; }
      codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$path" | head -n 1)
      pixel_format=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "$path" | head -n 1)

      prepared="$path"
      if [[ "$extension" != "mp4" || "$codec" != "h264" || "$pixel_format" != "yuv420p" ]]; then
        command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR\tffmpeg is required to create a compatible MP4\t$path" >&2; exit 1; }
        mkdir -p "$output_dir"
        stem=${filename%.*}
        prepared=$(unique_video_path "$stem")
        ffmpeg -hide_banner -loglevel error -i "$path" \
          -map 0:v:0 -map '0:a?' \
          -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p' \
          -c:v libx264 -crf 23 -preset medium \
          -c:a aac -b:a 128k \
          -movflags +faststart "$prepared"
        size=$(bytes_for "$prepared")
      fi

      if (( size > paid_video_limit )); then
        echo "ERROR\tvideo exceeds GitHub's 100 MB limit after preparation\t$prepared" >&2
        exit 1
      fi
      if (( size > free_video_limit )); then
        echo "WARN\tvideo exceeds the 10 MB free-plan limit\t$prepared" >&2
      fi
      printf 'READY\tvideo\t%s\t%s\n' "$size" "$prepared"
      ;;
    *)
      echo "ERROR\tunsupported image/video extension .$extension\t$path" >&2
      exit 1
      ;;
  esac
done
