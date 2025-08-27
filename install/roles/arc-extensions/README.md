# Arc Extensions Role

This Ansible role installs browser extensions for Arc browser on macOS.

## Requirements

- macOS (Darwin)
- Arc browser installed
- Ansible

## Role Variables

- `extension_id`: The Chrome Web Store extension ID to install (required)
- `file_mode`: File permissions for extension config files (default: '0644')
- `directory_mode`: Directory permissions (default: '0755')
- `file_owner`: Owner of created files (default: current user)
- `file_group`: Group of created files (default: 'staff')

## Example Usage

### Single Extension
```yaml
- name: Install uBlock Origin extension
  include_role:
    name: arc-extensions
  vars:
    extension_id: cjpalhdlnbpafiamejdnhcphjbkeiagm
```

### Multiple Extensions
```yaml
- name: Install multiple Arc extensions
  include_role:
    name: arc-extensions
  vars:
    extension_id: "{{ item }}"
  loop:
    - cjpalhdlnbpafiamejdnhcphjbkeiagm  # uBlock Origin
    - dbepggeogbaibhgnhhndojpepiihcmeb  # Vimium
    - gcbommkclmclpchllfjekcdonpmejbdp  # HTTPS Everywhere
    - oldceelmchomogloeakaaofljhcmkklje  # Grammarly
```

## How it works

The role creates a JSON configuration file in Arc's external extensions directory:
`~/Library/Application Support/Arc/User Data/External Extensions/{extension_id}.json`

This tells Arc to install the extension from the Chrome Web Store on next browser restart.

## Finding Extension IDs

To find a Chrome Web Store extension ID:
1. Go to the extension's page in Chrome Web Store
2. The ID is the long string in the URL: `https://chrome.google.com/webstore/detail/[EXTENSION_ID]`
3. Example: `https://chrome.google.com/webstore/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm`

## Popular Extension IDs

- **uBlock Origin**: `cjpalhdlnbpafiamejdnhcphjbkeiagm`
- **Vimium**: `dbepggeogbaibhgnhhndojpepiihcmeb`
- **HTTPS Everywhere**: `gcbommkclmclpchllfjekcdonpmejbdp`
- **Grammarly**: `oldceelmchomogloeakaaofljhcmkklje`
- **Bitwarden**: `nngceckbapebfimnlniiiahkandclblb`
- **LastPass**: `hdokiejnpimakedhajhdlcegeplioahd`
- **Dark Reader**: `eimadpbcbfnmbkopoojfekhnkhdbieeh`
- **React Developer Tools**: `fmkadmapgofadopljbjfkapdkoienihi`

## Notes

- Only works on macOS
- Extensions must be available in the Chrome Web Store
- Arc browser must be restarted to see installed extensions
- The role creates backups of existing extension files