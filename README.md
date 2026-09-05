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

## Codex on macOS

The Codex role resolves the physical config directory and installs a user
LaunchAgent. It sets `CODEX_HOME` for apps launched from the Dock at each login.
Zsh resolves the same directory for terminal commands. This avoids a Codex
bundled-plugin path check that rejects a symlinked `~/.codex` directory.

To apply only this fix on an existing Mac:

```bash
ansible-playbook install/codex-environment.yaml
```

Run this from your local dotfiles clone, as your user, without sudo.
The installer derives paths from that Mac. It preserves an explicit `CODEX_HOME`.
Run it again if you move the clone or change the config directory.
Quit and reopen ChatGPT after installation. Open a new terminal for Zsh.
Apps restored immediately at login may need one restart after the agent runs.
This does not install ChatGPT or grant macOS Screen Recording or Accessibility
permissions. Complete Computer Use setup separately on each Mac.

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
