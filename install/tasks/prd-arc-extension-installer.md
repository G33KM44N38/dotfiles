# Product Requirements Document: Arc Browser Extension Installer (Ansible Implementation)

## Introduction/Overview

This PRD outlines the requirements for creating a new Ansible role that automatically installs browser extensions for Arc browser. This feature must be implemented using Ansible as part of the personal dotfiles automation system. The goal is to create a focused, Arc-only extension installer that can automatically configure browser extensions during system setup, eliminating the need for manual extension installation.

## Goals

1. Create a new Ansible role that automatically installs Arc browser extensions
2. Provide a focused, Arc-only extension installer that successfully installs browser extensions
3. Automate browser extension configuration as part of dotfiles setup
4. Create a simple, maintainable solution without unnecessary complexity

## User Stories

- As a dotfiles user, I want to automatically install Arc browser extensions during system setup so that my browser is configured with necessary extensions without manual intervention
- As a developer maintaining personal dotfiles, I want a new extension installer that only supports Arc to keep the solution simple and focused
- As an Ansible user, I want the extension installer to handle directory creation and file placement automatically so that extensions are properly recognized by Arc browser

## Functional Requirements

1. The Ansible role must validate that only Arc browser is supported and reject other browser parameters
2. The Ansible role must create the Arc external extensions directory at the correct path: `~/Library/Application Support/Arc/User Data/External Extensions`
3. The Ansible role must install extension preference files using the `arc_extension.json.j2` template
4. The Ansible role must set proper file ownership and permissions (owner: user, group: staff, mode: 0644 for files, 0755 for directories)
5. The Ansible role must accept an `extension_id` parameter to specify which extension to install
6. The Ansible role must provide confirmation feedback when extension installation completes
7. The Ansible role must create backup copies of existing extension files when overwriting

## Non-Goals (Out of Scope)

1. Support for Chrome, Edge, or other browsers
2. Multi-browser compatibility or fallback mechanisms
3. Extension validation or verification of extension IDs
4. Automated testing framework implementation
5. Extension removal or uninstallation functionality
6. Extension store integration or automated extension discovery

## Design Considerations

- The new Ansible role should follow existing Ansible role patterns within the dotfiles structure
- Create a new Jinja2 template file (`arc_extension.json.j2`) for Arc extension configuration
- Variable naming should be clear and Arc-specific (e.g., `arc_extensions_path`)
- The Ansible role should integrate seamlessly with the existing dotfiles Ansible setup

## Technical Considerations

- The new Ansible role must work with the existing Ansible playbook structure in `/Users/boss/.dotfiles/install/`
- Path handling should use Ansible's `{{ user_home }}` variable for portability
- The Ansible template system should use a new `arc_extension.json.j2` template to be created
- File operations should include proper Ansible error handling and idempotency using appropriate Ansible modules (`file`, `template`, `assert`)
- Role directory structure should follow Ansible best practices with `tasks/`, `templates/`, and `vars/` directories

## Success Metrics

1. Successful installation of specified extensions in Arc browser
2. Extension appears and functions correctly after Arc browser restart
3. Ansible role executes without errors when provided valid extension IDs
4. Clean, maintainable code following Ansible best practices
5. Fast Ansible playbook execution time due to simple, focused logic

## Implementation Steps (Ansible-Specific)

1. Create new Ansible role directory structure: `roles/arc-extensions/`
2. Create `tasks/main.yml` with validation logic using Ansible's `assert` module for Arc browser
3. Create `tasks/darwin.yaml` for macOS-specific implementation
4. Set up Arc extensions path configuration using `arc_extensions_path` variable in Ansible facts
5. Implement directory creation task using Ansible's `file` module for Arc-specific path
6. Create new Jinja2 template file `templates/arc_extension.json.j2` for extension configuration
7. Implement extension file installation using Ansible's `template` module
8. Add completion message using Ansible's `debug` module
9. Create role variables in `vars/main.yml` or `defaults/main.yml`
10. Integrate the new role into the main dotfiles playbook

## Open Questions

1. Should the Ansible role provide any logging or debugging output using `debug` tasks for troubleshooting extension installation issues?
2. Are there specific Arc browser extension formats or requirements that differ from Chrome extensions in the Jinja2 template?
3. Should the Ansible role validate that Arc browser is actually installed before attempting extension installation using a `stat` or `command` task?