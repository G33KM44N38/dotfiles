#!/bin/bash
docker run --rm -it archlinux:latest bash -c "pacman -Syu --noconfirm git && curl -fsSL https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/install-online.sh | bash"
