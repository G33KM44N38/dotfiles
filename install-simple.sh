#!/bin/bash

# Ultra-simple dotfiles installer
# Alternative to the complex bash -c command

set -e

echo "🔄 Setting up dotfiles installation..."

# Method 1: Download and execute directly
echo "📥 Downloading installer..."
curl -fsSL -o /tmp/dotfiles-installer "https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/bin/dotfiles"

echo "🔧 Making executable..."
chmod +x /tmp/dotfiles-installer

echo "🚀 Running installation..."
echo "Note: You may need to enter your sudo password for package installation"
echo ""

# Run with all passed arguments
exec /tmp/dotfiles-installer "$@"