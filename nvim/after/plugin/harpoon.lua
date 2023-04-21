local mark = require("harpoon.mark")
local ui = require("harpoon.ui")

vim.keymap.set("n", "<leader>a", mark.add_file)
vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)

vim.keymap.set("n", "<C-u>",function() ui.nav_file(1) end)
vim.keymap.set("n", "<C-y>",function() ui.nav_file(2) end)
vim.keymap.set("n", "<C-n>",function() ui.nav_file(3) end)
vim.keymap.set("n", "<C-m>",function() ui.nav_file(4) end)
vim.api.nvim_set_keymap("n", "<C-P>", ":lua require('harpoon.tmux').sendCommand(0, 'tmux_navigate; tmux kill-window')<CR>", {noremap = true, silent = true})
