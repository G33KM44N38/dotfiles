-- Test script to verify LSP client management
local function test_lsp_clients()
    print("\n=== LSP Client Test ===")
    
    -- Get all active clients
    local all_clients = vim.lsp.get_clients()
    print(string.format("Total active clients: %d", #all_clients))
    
    for _, client in ipairs(all_clients) do
        local root = client.config.root_dir or "no root"
        print(string.format("  %d. %s (root: %s)", client.id, client.name, root))
    end
    
    -- Test buffer attachments
    local bufnr = vim.api.nvim_get_current_buf()
    local buf_clients = vim.lsp.get_clients({ bufnr = bufnr })
    print(string.format("\nClients attached to current buffer (%d):", bufnr))
    
    for _, client in ipairs(buf_clients) do
        local root = client.config.root_dir or "no root"
        print(string.format("  %d. %s (root: %s)", client.id, client.name, root))
    end
    
    -- Check for duplicates by name and root
    local by_name_and_root = {}
    for _, client in ipairs(buf_clients) do
        local root_dir = client.config.root_dir or "no_root"
        local key = client.name .. "|" .. root_dir
        by_name_and_root[key] = by_name_and_root[key] or {}
        table.insert(by_name_and_root[key], client)
    end
    
    print("\nDuplicate check (by name AND root):")
    local found_duplicates = false
    for key, client_list in pairs(by_name_and_root) do
        if #client_list > 1 then
            found_duplicates = true
            local name, root = key:match("^(.-)|(.*)$")
            print(string.format("  Duplicate found: %s (root: %s) - %d instances", name, root, #client_list))
            for _, client in ipairs(client_list) do
                print(string.format("    - Client ID %d", client.id))
            end
        end
    end
    
    if not found_duplicates then
        print("  No duplicates found!")
    end
    
    print("\n=== Test Complete ===")
end

-- Create commands for testing
vim.api.nvim_create_user_command("LspTest", test_lsp_clients, {})
vim.api.nvim_create_user_command("LspInfo", function()
    vim.cmd("LspClients")
    test_lsp_clients()
end, {})

print("LSP test commands registered: :LspTest, :LspInfo")