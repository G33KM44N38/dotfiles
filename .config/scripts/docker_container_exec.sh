#!/usr/bin/env bash

container=$(docker ps --format "{{.Names}}" | awk 'NR>0')
selected=$(echo "$container" | fzf)

if echo "$container" | grep -qs "$selected"; then
    exec docker exec -it "$selected" bash
else
    echo "Container not found."
fi
