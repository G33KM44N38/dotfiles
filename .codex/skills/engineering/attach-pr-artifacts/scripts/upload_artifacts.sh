#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: upload_artifacts.sh [--repo OWNER/REPO] [--json] FILE...

Uploads prepared images and videos to GitHub's user-attachments store.
The default output is Markdown ready for a PR body or comment.
EOF
  exit 2
}

repo_arg=""
json_output=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|-R)
      [[ $# -ge 2 ]] || usage
      repo_arg="$2"
      shift 2
      ;;
    --json)
      json_output=true
      shift
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

for command_name in gh curl jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR\trequired command not found\t$command_name" >&2
    exit 1
  }
done

if [[ -n "$repo_arg" ]]; then
  repo=$(gh repo view "$repo_arg" --json nameWithOwner --jq .nameWithOwner)
else
  repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
fi

repo_data=$(gh api "repos/$repo")
repo_id=$(jq -er '.id | numbers' <<<"$repo_data")
can_push=$(jq -r '.permissions.push // false' <<<"$repo_data")
[[ "$can_push" == "true" ]] || {
  echo "ERROR\tGitHub account lacks push permission\t$repo" >&2
  exit 1
}

token=$(gh auth token --hostname github.com)

absolute_path() {
  local parent name
  parent=$(dirname "$1")
  name=$(basename "$1")
  printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$name"
}

urlencode() {
  jq -rn --arg value "$1" '$value | @uri'
}

mime_for() {
  local extension
  extension=${1##*.}
  extension=$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')

  case "$extension" in
    png) printf '%s\n' 'image/png' ;;
    gif) printf '%s\n' 'image/gif' ;;
    jpg|jpeg) printf '%s\n' 'image/jpeg' ;;
    svg) printf '%s\n' 'image/svg+xml' ;;
    mp4) printf '%s\n' 'video/mp4' ;;
    mov) printf '%s\n' 'video/quicktime' ;;
    webm) printf '%s\n' 'video/webm' ;;
    *)
      echo "ERROR\tunsupported image/video extension\t$1" >&2
      return 1
      ;;
  esac
}

kind_for() {
  case "$1" in
    image/*) printf '%s\n' image ;;
    video/*) printf '%s\n' video ;;
    *) return 1 ;;
  esac
}

for input in "$@"; do
  [[ -f "$input" ]] || {
    echo "ERROR\tnot a regular file\t$input" >&2
    exit 1
  }

  path=$(absolute_path "$input")
  filename=$(basename "$path")
  mime=$(mime_for "$filename")
  kind=$(kind_for "$mime")
  endpoint="https://uploads.github.com/user-attachments/assets"
  endpoint+="?name=$(urlencode "$filename")"
  endpoint+="&content_type=$(urlencode "$mime")"
  endpoint+="&repository_id=$repo_id"

  echo "Uploading $filename to $repo" >&2
  response_with_status=$(
    printf 'Authorization: Bearer %s\n' "$token" |
      curl --silent --show-error \
        --request POST \
        --header @- \
        --header 'Accept: application/vnd.github+json' \
        --header 'Content-Type: application/octet-stream' \
        --data-binary "@$path" \
        --write-out $'\n%{http_code}' \
        "$endpoint"
  )

  http_status=${response_with_status##*$'\n'}
  response=${response_with_status%$'\n'*}
  if [[ "$http_status" != 2* ]]; then
    message=$(jq -r '.message // "no response message"' <<<"$response" 2>/dev/null || printf '%s' 'invalid JSON response')
    echo "ERROR\tGitHub upload failed with HTTP $http_status\t$message" >&2
    exit 1
  fi

  url=$(jq -er \
    '.url | strings | select(startswith("https://github.com/user-attachments/"))' \
    <<<"$response") || {
    echo "ERROR\tGitHub returned no user-attachment URL\t$filename" >&2
    exit 1
  }

  if [[ "$kind" == "image" ]]; then
    markdown="![$filename]($url)"
  else
    markdown="$url"
  fi

  if [[ "$json_output" == "true" ]]; then
    jq -cn \
      --arg path "$path" \
      --arg name "$filename" \
      --arg kind "$kind" \
      --arg content_type "$mime" \
      --arg url "$url" \
      --arg markdown "$markdown" \
      '{path: $path, name: $name, kind: $kind, content_type: $content_type, url: $url, markdown: $markdown}'
  else
    printf '%s\n' "$markdown"
  fi
done
