# Task List: Arc Browser Extension Installer Implementation

Based on the PRD for Arc Browser Extension Installer (Ansible Implementation)

## Relevant Files

- `roles/arc-extensions/tasks/main.yml` - Main entry point for the Ansible role with validation and platform detection
- `roles/arc-extensions/tasks/darwin.yaml` - macOS-specific implementation for Arc extension installation
- `roles/arc-extensions/templates/arc_extension.json.j2` - Jinja2 template for Arc extension configuration files
- `roles/arc-extensions/defaults/main.yml` - Default variables for the role including extension settings
- `roles/arc-extensions/vars/main.yml` - Role-specific variables and Arc browser paths
- `main.yaml` - Main dotfiles playbook that will include the new arc-extensions role

### Notes

- Follow existing Ansible role patterns in the dotfiles structure (observe other roles like `roles/arc/`, `roles/git/`)
- Arc extensions are installed by creating JSON configuration files in `~/Library/Application Support/Arc/User Data/External Extensions/`
- The role should be idempotent and handle existing extension files gracefully
- Test the role by running the playbook with a valid extension ID

## Tasks

- [x] 1.0 Create Ansible Role Directory Structure *(Completed: 2025-08-27)*
   - [x] 1.1 Create `roles/arc-extensions/` directory *(Completed: 2025-08-27)*
   - [x] 1.2 Create `roles/arc-extensions/tasks/` subdirectory *(Completed: 2025-08-27)*
   - [x] 1.3 Create `roles/arc-extensions/templates/` subdirectory *(Completed: 2025-08-27)*
   - [x] 1.4 Create `roles/arc-extensions/defaults/` subdirectory *(Completed: 2025-08-27)*
   - [x] 1.5 Create `roles/arc-extensions/vars/` subdirectory *(Completed: 2025-08-27)*

- [x] 2.0 Implement Core Task Logic *(Completed: 2025-08-27)*
   - [x] 2.1 Create `tasks/main.yml` with platform validation (Darwin only) *(Completed: 2025-08-27)*
   - [x] 2.2 Add browser validation to ensure Arc-only support using `assert` module *(Completed: 2025-08-27)*
   - [x] 2.3 Include platform-specific tasks based on `ansible_os_family` *(Completed: 2025-08-27)*
   - [x] 2.4 Create `tasks/darwin.yaml` for macOS implementation *(Completed: 2025-08-27)*
   - [x] 2.5 Set Arc extensions directory path using `set_fact` module *(Completed: 2025-08-27)*
   - [x] 2.6 Implement directory creation using `file` module with proper permissions *(Completed: 2025-08-27)*
   - [x] 2.7 Install extension configuration file using `template` module with backup option *(Completed: 2025-08-27)*
   - [x] 2.8 Add completion confirmation using `debug` module *(Completed: 2025-08-27)*

- [x] 3.0 Create Extension Configuration Template *(Completed: 2025-08-27)*
   - [x] 3.1 Research Arc browser extension configuration format *(Completed: 2025-08-27)*
   - [x] 3.2 Create `templates/arc_extension.json.j2` template file *(Completed: 2025-08-27)*
   - [x] 3.3 Include extension_id variable in template *(Completed: 2025-08-27)*
   - [x] 3.4 Add required Arc-specific configuration fields *(Completed: 2025-08-27)*
   - [x] 3.5 Test template rendering with sample extension ID *(Completed: 2025-08-27)*

- [x] 4.0 Set Up Role Variables and Defaults *(Completed: 2025-08-27)*
   - [x] 4.1 Create `defaults/main.yml` with default extension settings *(Completed: 2025-08-27)*
   - [x] 4.2 Define `extension_id` variable (no default value, must be provided) *(Completed: 2025-08-27)*
   - [x] 4.3 Create `vars/main.yml` with Arc-specific paths and constants *(Completed: 2025-08-27)*
   - [x] 4.4 Define `user_home` variable using `ansible_env.HOME` *(Completed: 2025-08-27)*
   - [x] 4.5 Set file and directory permissions as variables *(Completed: 2025-08-27)*

- [x] 5.0 Integrate Role into Main Playbook *(Completed: 2025-08-27)*
   - [x] 5.1 Add `arc-extensions` role to `main.yaml` playbook *(Completed: 2025-08-27)*
   - [x] 5.2 Configure role to run conditionally (when extension_id is defined) *(Completed: 2025-08-27)*
   - [x] 5.3 Test role execution with a sample extension ID *(Completed: 2025-08-27)*
   - [x] 5.4 Verify extension appears in Arc browser after restart *(Completed: 2025-08-27)*
   - [x] 5.5 Document usage example in playbook or role README *(Completed: 2025-08-27)*