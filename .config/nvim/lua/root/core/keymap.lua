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

keymap("n", "<C-z>", "<nop>", opts)

-- Save all buffers
keymap("n", "<leader>w", ":w<CR> :wa<CR>", opts)

-- make
keymap("n", "<leader>m", ":make ", noSilent)

-- commente line
keymap("n", "<leader><leader>c", ":Commentary <CR>", opts)

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
-- keymap("n", "<leader>gc", ":Git commit<CR>", noSilent)
-- keymap("n", "<leader>gs", ":Git status<CR>", opts)
-- keymap("n", "<leader>gP", ":Git push<CR>", opts)
-- keymap("n", "<leader>gp", ":Git pull<CR>", opts)

-- open term
keymap("n", "<leader>tt", ":ToggleTerm direction=float fish<CR>", opts)

-- mapping Open Buffer fzf telescope
keymap("n", "<leader>n", ":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", opts)
keymap("n", "<leader>N", ":lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>", opts)
keymap("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)
keymap("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)
keymap("n", 'gr', "<cmd>Telescope lsp_references<CR>", opts)
keymap("n", "<leader>pf", ":lua require('telescope.builtin').find_files()<CR>", opts)
keymap("n", "<C-s>", ":lua require('telescope.builtin').live_grep()<CR>", opts)
keymap("n", "<leader>gof", ":lua require('telescope.builtin').live_grep({grep_open_files=true})", opts)
keymap("n", "<C-p>", ":lua require('telescope.builtin').git_files()<CR>", opts)
keymap("n", "<leader>ke", ":lua require('telescope.builtin').keymaps()<CR>", opts)

-- allow my cursor stay at the same place, when using `J`
keymap("n", "J", "mzJ`z", opts)

vim.keymap.set({ "n", "v" }, "<leader>c", vim.lsp.buf.code_action, { desc = "See available code actions" }) -- see available code actions, in visual mode will apply to selection

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Trouble
vim.keymap.set("n", "<leader>xw", function() require("trouble").toggle("workspace_diagnostics") end)
vim.keymap.set("n", "<leader>xx", function() require("trouble").toggle() end)

-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)

-- allow search term to be in the middle
keymap("n", "n", "nzzzv", opts)
keymap("n", "N", "Nzzzv", opts)

-- git worktrees

local function setup_mappings()
	-- NERDTree mappings
	-- keymap('n', '<leader>d', ':NERDTreeToggle<CR>', opts)
	keymap('n', '<leader>f', ':NERDTreeFind<CR>', opts)

	-- Exit Vim if NERDTree is the only window remaining in the only tab.
	vim.cmd(
		[[ autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif ]])
end

setup_mappings()
