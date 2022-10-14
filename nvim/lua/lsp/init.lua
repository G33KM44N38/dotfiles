local ok, lsp_installer = pcall(require, "nvim-lsp-installer")

if not ok then
    return
end

local utils = require "utils"

local servers = {
    "bashls",
    "ccls",
    "clangd",
    "cmake",
    "sumneko_lua",
    "cssls",
    "html",
    "emmet_ls",
    "jsonls",
    "yamlls",
    "dockerls",
    "sumneko_lua",
    "gopls",
    "tsserver",
}

local signs = {
    { name = "DiagnosticSignError", text = "" },
    { name = "DiagnosticSignWarn", text = "" },
    { name = "DiagnosticSignHint", text = "" },
    { name = "DiagnosticSignInfo", text = "" },
  }

for _, sign in ipairs(signs) do
    vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
  end

-- Floating border
local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = opts.border or { { " ", "FloatBorder" } }
    return orig_util_open_floating_preview(contents, syntax, opts, ...)
end

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

local opts = { noremap = true, silent = true, nowait = true }

vim.api.nvim_set_keymap("n", "<space>e", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
vim.api.nvim_set_keymap("n", "<space>lp", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
vim.api.nvim_set_keymap("n", "<space>ln", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
vim.api.nvim_set_keymap("n", "<space>q", "<cmd>lua vim.diagnostic.setloclist()<CR>", opts)

local on_attach = function(client, bufnr)
    -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>n", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
    -- vim.api.nvim_buf_set_keymap(bufnr, "n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
    -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>lr", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>lc", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
    -- vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>lf", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)

    require("illuminate").on_attach(client)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)

lsp_installer.setup {
    ensure_installed = servers,
    automatic_installation = true,
    ui = {
        icons = {
            server_installed = "",
            server_pending = "",
            server_uninstalled = "",
        },
    },
}

for _, server in ipairs(servers) do
    require("lsp.servers." .. server).setup(on_attach, capabilities)
end

-- Gutter sign icons
for type, icon in pairs(utils.signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- Prefix diagnostic virtual text
vim.diagnostic.config {
    virtual_text = {
        source = "always",
        prefix = " ",
        spacing = 6,
    },
    float = {
        header = false,
        source = "always",
    },
    signs = {
      active = signs,
    },
    underline = false,
    update_in_insert = true,
}
