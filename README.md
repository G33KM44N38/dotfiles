# dotfiles

## Install

### Option 1: one-liner

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/install-online.sh)"
```

### Option 2: Manual clone and run
```bash
git clone https://github.com/G33KM44N38/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bin/dotfiles
```

### Option 3: Download and run
```bash
curl -fsSL -o /tmp/install-dotfiles.sh https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/install-online.sh
bash /tmp/install-dotfiles.sh
```

## Ubuntu

The installer detects Ubuntu and runs `install/ubuntu.yaml`. It installs the core
terminal and development tools, links the portable Neovim, Ghostty, and Zsh
configuration, and installs Tailscale. It does not link macOS settings or
credential files into the Linux home directory.

After the playbook finishes, authenticate the tools that need an account:

```bash
sudo tailscale up
gh auth login
codex login
```

Restart the session once so Zsh becomes the login shell.
