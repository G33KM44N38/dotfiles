# dotfiles

## Install

### Option 1: One-liner (Recommended)
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/install-online.sh)"
```

### Option 2: Manual clone and run
```bash
git clone https://github.com/G33KM44N38/dotfiles ~/.dotfiles
cd ~/.dotfiles
./bin/dotfiles
```

### Option 3: Download and run
```bash
curl -fsSL -o /tmp/install-dotfiles.sh https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/install-online.sh
bash /tmp/install-dotfiles.sh
```

## Linux Support

This dotfiles setup now supports Linux with the same keybindings and tools as macOS!

- **Window Manager**: i3 (equivalent to aerospace)
- **Keybindings**: sxhkd + xcape (Karabiner equivalent)
- **Same shortcuts**: Hyper key, layers, and muscle memory work on both platforms

See `.config/README-linux-keymap.md` for Linux-specific setup instructions.
