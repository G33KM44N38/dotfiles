-- Enable termguicolors
vim.o.termguicolors = true
vim.cmd("set termguicolors")

Opts = { noremap = true, silent = true }
local noSilent = { noremap = true }

vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- Shorten function name
local keymap = vim.api.nvim_set_keymap

keymap("n", "<leader>de", "<cmd>silent !tmux split -v ~/.config/scripts/docker_container_exec.sh<CR>", Opts)
keymap("n", "<leader>dl", "<cmd>silent !tmux split -v ~/.config/scripts/docker_container_log.sh<CR>", Opts)
keymap("n", "<C-f>", "<cmd>silent !tmux neww tmux-navigate.sh<CR>", Opts)
keymap("n", "<leader>lg", "<cmd>silent !tmux neww lazygit<CR>", Opts)
keymap("n", "<leader>ld", "<cmd>silent !tmux neww lazydocker<CR>", Opts)
keymap("i", "kj", "<Esc>", Opts)
keymap("n", "<leader><leader>", ":Ex<CR>", Opts)

keymap("n", "<C-z>", "<nop>", Opts)

-- Save all buffers
keymap("n", "<leader>w", ":w<CR> :wa<CR>", Opts)

-- paste without overwrite
vim.keymap.set("x", "<leader>p", '"_dP')

-- paste to the clipboard
keymap("n", "<leader>y", '"+y', Opts)
keymap("v", "<leader>y", '"+y', Opts)
keymap("n", "<leader>Y", '"+y', Opts)

-- Increment/decrement
keymap("n", "+", "<C-a>", Opts)
keymap("n", "-", "<C-x>", Opts)

-- allow my cursor stay at the same place, when using `J`
keymap("n", "J", "mzJ`z", Opts)

vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", Opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", Opts)

-- allow search term to be in the middle
keymap("n", "n", "nzzzv", Opts)
keymap("n", "N", "Nzzzv", Opts)
keymap("n", "<C-d>", "<C-d>zzzv", Opts)
keymap("n", "<C-u>", "<C-u>zzzv", Opts)

keymap("n", "<leader>tb", "<cmd>tabnext<CR>", Opts)
keymap("n", "<leader>tp", "<cmd>tabprev<CR>", Opts)
