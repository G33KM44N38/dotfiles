#!/bin/bash

# Simple dotfiles installer
# Downloads and runs the dotfiles installation script

set -e

echo "🔄 Downloading dotfiles installer..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
INSTALL_SCRIPT="$TEMP_DIR/dotfiles-installer.sh"

# Download the installer
if ! curl -fsSL -o "$INSTALL_SCRIPT" "https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/bin/dotfiles"; then
    echo "❌ Failed to download installer"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Make it executable
chmod +x "$INSTALL_SCRIPT"

echo "🚀 Running installer..."
echo "Note: You may be prompted for sudo password for package installation"
echo ""

# Run the installer with all arguments passed to this script
if "$INSTALL_SCRIPT" "$@"; then
    echo ""
    echo "✅ Installation completed successfully!"
else
    echo ""
    echo "❌ Installation failed"
    exit 1
fi

# Clean up
rm -rf "$TEMP_DIR"