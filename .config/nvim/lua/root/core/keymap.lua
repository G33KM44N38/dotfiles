-- Enable termguicolors
vim.o.termguicolors = true
vim.cmd("set termguicolors")

local opts = { noremap = true, silent = true }
local noSilent = { noremap = true }

vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- Shorten function name
local keymap = vim.api.nvim_set_keymap

keymap("n", "<leader>de", "<cmd>silent !tmux split -v ~/.config/scripts/docker_container_exec.sh<CR>", opts)
keymap("n", "<leader>dl", "<cmd>silent !tmux split -v ~/.config/scripts/docker_container_log.sh<CR>", opts)
keymap("n", "<C-f>", "<cmd>silent !tmux neww tmux-navigate.sh<CR>", opts)
keymap('n', '<leader>lg', '<cmd>silent !tmux neww lazygit<CR>', opts)
keymap('n', '<leader>ld', '<cmd>silent !tmux neww lazydocker<CR>', opts)
keymap('i', 'kj', '<Esc>', opts)
keymap('i', 'KJ', '<Esc>', opts)
keymap("n", '<leader>f', ':Ex<CR>', opts)

keymap("n", "<C-z>", "<nop>", opts)

-- Save all buffers
keymap("n", "<leader>w", ":w<CR> :wa<CR>", opts)

-- paste without overwrite
vim.keymap.set("x", "<leader>p", "\"_dP")

-- paste to the clipboard
keymap("n", "<leader>y", "\"+y", opts)
keymap("v", "<leader>y", "\"+y", opts)
keymap("n", "<leader>Y", "\"+y", opts)

-- Increment/decrement
keymap('n', '+', '<C-a>', opts)
keymap('n', '-', '<C-x>', opts)

-- mapping fugitif
keymap("n", "<leader>g", ":G<CR>", opts)

-- open term
keymap("n", "<leader>tt", ":ToggleTerm direction=float fish<CR>", opts)

keymap("n", "<leader>he", "<cmd>Telescope help_tags<CR>", opts)
keymap("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)
keymap("n", "<C-p>", "<cmd>Telescope find_files<CR>", opts)
keymap("n", "<C-s>", ":lua require('telescope.builtin').live_grep()<CR>", opts)
keymap("n", "<leader>ke", ":lua require('telescope.builtin').keymaps()<CR>", opts)
keymap("n", "<leader>hi",
	":lua require('telescope.builtin').find_files({ hidden = true, no_ignore = true, file_ignore_patterns = {'.git/'} })<CR>",
	opts)

-- allow my cursor stay at the same place, when using `J`
keymap("n", "J", "mzJ`z", opts)

vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)

-- allow search term to be in the middle
keymap("n", "n", "nzzzv", opts)
keymap("n", "N", "Nzzzv", opts)

keymap('n', '<leader>tb', '<cmd>tabnext<CR>', opts)
keymap('n', '<leader>tp', '<cmd>tabprev<CR>', opts)
