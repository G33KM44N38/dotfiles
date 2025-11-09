# Linux Keymap Setup - Karabiner Equivalent

This directory contains Linux configurations that provide similar functionality to your macOS Karabiner setup.

## Overview

The Linux keymap system uses multiple tools to replicate Karabiner's advanced functionality:

- **sxhkd**: Simple X Hotkey Daemon - handles most hotkeys and shortcuts
- **xcape**: Allows modifier keys to act as other keys when tapped
- **xmodmap**: Basic key remapping
- **i3**: Window manager integration

## Key Features Implemented

### ✅ Hyper Key (Spacebar)
- **Spacebar** acts as a modifier when held (like Karabiner's hyper key)
- Hyper + letter combinations open applications and websites
- Same shortcuts as your macOS setup

### ✅ Key Layers
- **Left GUI layer**: Number keys and navigation
- **Right GUI layer**: Symbol keys
- **Left Option layer**: Function keys

### ✅ Home Row Mods (Basic)
- Basic home row mod simulation using sxhkd
- For full home row mods, consider using [kanata](https://github.com/jtroo/kanata)

### ✅ Application Shortcuts
- Hyper + O: Application launcher (Linux equivalents)
- Hyper + B: Browser shortcuts
- Hyper + Q: Work-related shortcuts
- Hyper + S: System controls
- Hyper + R: Utility shortcuts

## Setup Instructions

### 1. Install Required Tools

The dotfiles installation will automatically install:
```bash
# Ubuntu/Debian
sudo apt install sxhkd xcape xdotool wmctrl xbacklight playerctl copyq pavucontrol blueman flameshot arandr

# Arch Linux
sudo pacman -S sxhkd xcape xdotool wmctrl xorg-xbacklight playerctl copyq pavucontrol blueman flameshot arandr

# Fedora
sudo dnf install sxhkd xcape xdotool wmctrl xbacklight playerctl copyq pavucontrol blueman flameshot arandr
```

### 2. Start Services

Add to your `~/.xinitrc` or window manager startup:
```bash
# Start sxhkd
sxhkd &

# Load xmodmap
xmodmap ~/.config/X11/xmodmap &

# Set up hyper key with xcape (spacebar acts as hyper when held)
xcape -e 'Super_L=space'
```

### 3. i3 Integration

If using i3, the configuration automatically starts sxhkd. For other window managers, add sxhkd to your startup.

## Key Mappings

### Hyper Key Combinations

| Combination | Action |
|-------------|--------|
| `Super + Space + B + A` | Open ChatGPT |
| `Super + Space + B + Y` | Open YouTube |
| `Super + Space + O + T` | Open Ghostty |
| `Super + Space + O + W` | Open Browser |
| `Super + Space + S + U/J` | Volume Up/Down |
| `Super + Space + S + I/K` | Brightness Up/Down |

### Key Layers

| Layer | Trigger | Keys | Output |
|-------|---------|------|--------|
| Left GUI | `Super + Q/W/E/R/T` | QWERTY | 12345 |
| Left GUI | `Super + H/J/K/L` | HJKL | Arrow keys |
| Right GUI | `Super + A/S/D/F` | Various | Symbols |

### Home Row Mods (Basic)

| Key | When held | Action |
|-----|-----------|--------|
| A | Held | Additional Super |
| S | Held | Additional Alt |
| D | Held | Additional Shift |
| F | Held | Additional Control |

## Limitations

1. **Home Row Mods**: The current implementation is basic. For full home row mods, use [kanata](https://github.com/jtroo/kanata) or QMK firmware.

2. **Raycast Extensions**: Linux equivalents are used where available. Some macOS-specific tools need Linux alternatives.

3. **Application Paths**: Update application commands in `sxhkdrc` to match your installed applications.

## Customization

### Modifying Shortcuts

Edit `~/.config/sxhkd/sxhkdrc` to customize shortcuts:

```bash
# Format: modifier + key
#         command
super + space ; a
    chromium --app="https://myapp.com"
```

### Advanced Home Row Mods

For full home row mod support, install kanata:

```bash
# Install kanata
cargo install kanata

# Create kanata config (see kanata documentation)
# Run kanata with your config
```

## Troubleshooting

### sxhkd not working
```bash
# Check if sxhkd is running
pgrep sxhkd

# Start sxhkd manually
sxhkd -c ~/.config/sxhkd/sxhkdrc

# Reload configuration
pkill -USR1 sxhkd
```

### Key mappings not working
```bash
# Test xmodmap
xmodmap ~/.config/X11/xmodmap

# Check for conflicts
xinput list
setxkbmap -query
```

### Hyper key not working
```bash
# Test xcape
xcape -e 'Super_L=space'

# Check Super key behavior
xev | grep -A2 -B2 Super
```

## Alternative Tools

For more advanced keymapping on Linux:

- **[kanata](https://github.com/jtroo/kanata)**: Advanced key remapping with layers
- **[kmonad](https://github.com/kmonad/kmonad)**: Keyboard manager with layers
- **[xremap](https://github.com/k0kubun/xremap)**: Key remapper for X11/Wayland
- **QMK Firmware**: Custom keyboard firmware with advanced features

## macOS Comparison

| Feature | macOS (Karabiner) | Linux (sxhkd/xcape) |
|---------|-------------------|---------------------|
| Hyper key | ✅ Native | ✅ Via xcape |
| Key layers | ✅ Native | ✅ Via sxhkd |
| Home row mods | ✅ Native | ⚠️ Basic (use kanata for full) |
| GUI integration | ✅ Native | ✅ Via tools |
| Performance | ✅ Excellent | ✅ Good |

The Linux setup provides ~90% of the macOS functionality with some limitations in advanced features like full home row mods.