# Arc DevTools Shortcuts Role

This Ansible role configures custom keyboard shortcuts for Arc browser's DevTools.

## Requirements

- macOS (Darwin)
- Arc browser installed
- Ansible

## Role Variables

- `user_home`: User home directory (default: "{{ ansible_env.HOME }}")
- `arc_user_data_path`: Arc user data directory path
- `devtools_shortcuts_file`: DevTools shortcuts configuration file path

## Example Usage

```yaml
- name: Configure Arc DevTools shortcuts
  include_role:
    name: arc-devtools-shortcuts
  tags: ['arc-devtools-shortcuts', 'arc-shortcuts']
```

## Testing

You can test this role independently using tags:

```bash
# Test only the arc-devtools-shortcuts role
ansible-playbook main.yaml -t arc-devtools-shortcuts

# Or use the shorter tag
ansible-playbook main.yaml -t arc-shortcuts

# Cleanup for re-testing
ansible-playbook main.yaml -t arc-devtools-shortcuts-cleanup
```

## What it does

This role creates a `devtools_shortcuts.json` file in Arc's user data directory that defines custom keyboard shortcuts for DevTools actions.

Currently configured shortcuts:
- **Cmd+Option+N**: Toggle Network tab in DevTools

## How it works

The role creates a JSON configuration file that Arc's DevTools reads to determine custom keyboard shortcuts. The shortcuts are applied when DevTools starts.

## Notes

- Only works on macOS
- Arc browser must be restarted for changes to take effect
- The role creates backups of existing configuration files
- Custom shortcuts are defined in the `custom_shortcuts` array