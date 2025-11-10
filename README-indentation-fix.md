# YAML Indentation Fix - Solana Role Removal

## Problem Description

After removing the Solana role from the Ansible playbook (`install/main.yaml`), a YAML syntax error occurred due to inconsistent indentation in the cross-platform roles section.

### Error Details
```
ERROR: YAML parsing failed: While parsing a block collection did not find expected '-' indicator.
Origin: /Users/boss/.dotfiles/install/main.yaml:63:7
```

## Root Cause

The indentation inconsistency occurred because:

1. **Comment indentation mismatch**: The comment `# Cross-platform roles (run on both macOS and Linux)` was indented with 7 spaces instead of 4 spaces (matching other section comments)

2. **Task indentation inconsistency**: The role inclusion tasks had varying levels of indentation, with some tasks indented differently than others in the same list

3. **List structure misalignment**: The YAML list items weren't properly aligned at the same indentation level

## Solution Applied

### 1. Fixed Comment Indentation
```yaml
# Before (incorrect):
      # Cross-platform roles (run on both macOS and Linux)

# After (correct):
    # Cross-platform roles (run on both macOS and Linux)
```

### 2. Standardized Task Indentation
All role inclusion tasks were aligned to use consistent indentation:

```yaml
# Correct indentation pattern:
     - name: Run roles
       ansible.builtin.include_role:
         name: role_name
```

### 3. Verified Syntax
Ran `ansible-playbook --syntax-check install/main.yaml` to confirm the YAML is valid.

## Prevention Guidelines

### YAML Indentation Rules for Ansible Playbooks

1. **Use consistent indentation**: Stick to 2-space indentation throughout the file
2. **Align list items**: All items in a list should start at the same column
3. **Match comment levels**: Comments should align with the code structure they describe
4. **Validate syntax**: Always run `ansible-playbook --syntax-check` after making changes

### Common Pitfalls

- Mixing tabs and spaces (always use spaces)
- Inconsistent indentation levels within the same block
- Comments not aligned with their corresponding code sections
- Nested structures with misaligned indentation

## Files Modified

- `install/main.yaml`: Fixed indentation in cross-platform roles section
- `install/roles/solana/`: Removed (role directory deleted)

## Testing

After the fix:
- YAML syntax validation passes
- Ansible playbook structure is intact
- All role inclusions maintain proper formatting

## Related Changes

This fix was part of removing the Solana role from the dotfiles installation, which involved:
1. Removing Solana from the role inclusion list
2. Deleting the `install/roles/solana/` directory
3. Fixing resulting YAML indentation issues