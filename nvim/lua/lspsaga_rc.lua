local status, saga = pcall(require, 'lspsaga')
if (not status)then return end

saga.init_lsp_saga{
	server_filetype_map = {}
}
local opts = {noremap = true, silent = true}
vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts)
vim.keymap.set("n", "gD", "<cmd>Lspsaga lsp_finder<CR>", opts)
vim.keymap.set("i", "<C-k>", "<cmd>Lspsaga signature_help<CR>", opts)
vim.keymap.set("n", "<C-j>", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts)
vim.keymap.set("n", "gr", "<cmd>Lspsaga rename<CR>", opts)

local action = require("lspsaga.codeaction")
vim.keymap.set("n", "<leader>ca", action.code_action, { silent = true })
vim.keymap.set("v", "<leader>ca", function()
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-U>", true, false, true))
    action.range_code_action()
end, { silent = true })
