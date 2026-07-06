#!/usr/bin/env bash

container=$(docker ps --format "{{.Names}}" | awk 'NR>0')
selected=$(echo "$container" | fzf)

if echo "$container" | grep -qs "$selected"; then
    exec docker logs -f "$selected"
else
    echo "Container not found."
fi
