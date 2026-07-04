# LSP Stop Issue - Root Cause and Fix

## Problem Description
The LSP servers (specifically typescript-tools) were stopping unexpectedly after edits and after using the hover command.

## Root Cause Analysis

### 1. Duplicate Client Detachment Logic
The original code in `lsp.lua` was grouping LSP clients **only by name**:
```lua
local by_name = {}
for _, client in ipairs(clients) do
    by_name[client.name] = by_name[client.name] or {}
    table.insert(by_name[client.name], client)
end
```

This caused legitimate separate instances of the same LSP server (for different root directories) to be treated as duplicates and detached:
- `typescript-tools (id: 33)` for `~/coding/work/babacoiffure_monorepo.git/v2/apps/mobile`
- `typescript-tools (id: 34)` for `~/coding/work/babacoiffure_monorepo.git/v2`

### 2. Memory Management Plugins Conflict
Two memory management plugins were configured:
- `lsp-timeout.nvim` - Stops LSP servers after 3 minutes of inactivity
- `garbage-day.nvim` - Garbage collects inactive LSP clients

These plugins can interfere with normal LSP operations and create race conditions, especially when combined with the duplicate detachment logic.

### 3. Race Conditions
The 200ms delay in the duplicate detachment autocmd combined with the memory management plugins created race conditions where:
1. User performs an edit or hover command
2. LSP attach event triggers
3. Duplicate detachment logic runs after 200ms
4. Memory management plugins might stop clients during this window
5. LSP becomes unstable or stops completely

## Solution Implemented

### 1. Fixed Duplicate Client Detachment Logic
Modified the grouping to use **both name AND root directory**:
```lua
local by_name_and_root = {}
for _, client in ipairs(clients) do
    local root_dir = client.config.root_dir or "no_root"
    local key = client.name .. "|" .. root_dir
    by_name_and_root[key] = by_name_and_root[key] or {}
    table.insert(by_name_and_root[key], client)
end
```

Now only truly duplicate clients (same name AND same root directory) are detached.

### 2. Disabled Memory Management Plugins
Commented out both `lsp-timeout.nvim` and `garbage-day.nvim` configurations to eliminate interference with LSP operations. These can be re-enabled later with more conservative settings if needed.

### 3. Added Diagnostic Tools
Created a test script (`lsp_test.lua`) with commands:
- `:LspTest` - Shows detailed LSP client information
- `:LspInfo` - Combines existing `:LspClients` with detailed test output

## Files Modified

1. **`/Users/boss/.dotfiles/.config/nvim/lua/root/plugins/lsp.lua`**
   - Fixed duplicate client detachment logic (lines 210-267)
   - Commented out memory management plugins (lines 325-362)

2. **`/Users/boss/.dotfiles/.config/nvim/init.lua`**
   - Added `require("lsp_test")` to load diagnostic tools

3. **Created `/Users/boss/.dotfiles/.config/nvim/lsp_test.lua`**
   - Diagnostic script for LSP client inspection

## Testing Instructions

1. **Restart Neovim** to load the new configuration
2. **Open a TypeScript/JavaScript file** in your project
3. **Use hover command** (`K` or `:LspHover`) 
4. **Make edits** and observe if LSP stays active
5. **Run diagnostic commands**:
   - `:LspClients` - Shows basic client info
   - `:LspTest` - Shows detailed client info with duplicate detection
   - `:LspInfo` - Combined diagnostic output

## Expected Results

- LSP servers should remain active after edits and hover commands
- Multiple typescript-tools instances should coexist for different root directories
- No more "Detached duplicate" messages for legitimate separate instances
- LSP functionality (completion, diagnostics, hover) should work consistently

## Next Steps

If the issue persists, consider:
1. Checking Neovim logs: `:messages` and `:lua vim.lsp.set_log_level("DEBUG")`
2. Examining typescript-tools specific logs
3. Testing with a minimal configuration
4. Re-enabling memory management plugins with more conservative settings