-- Enable termguicolors
vim.o.termguicolors = true
vim.cmd("set termguicolors")

local opts = { noremap = true, silent = true }
local noSilent = { noremap = true }

vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- Shorten function name
local keymap = vim.api.nvim_set_keymap

keymap("n", "<C-f>", "<cmd>silent !tmux neww tmux_navigate<CR>", opts)
keymap('n', '<leader>lg', '<cmd>silent !tmux neww lazygit<CR>', opts)
keymap('n', '<leader>ld', '<cmd>silent !tmux neww lazydocker<CR>', opts)
keymap('i', 'kj', '<Esc>', opts)
keymap('i', 'KJ', '<Esc>', opts)

keymap("n", "<C-z>", "<nop>", opts)

-- running macro
keymap("n", "<leader>q", "@q", opts)

-- Save all buffers
keymap("n", "<leader>w", ":w<CR> :wa<CR>", opts)

-- mapping change viewport
keymap("n", "<S-TAB>", ":bp<CR>", opts)
keymap("n", "<TAB>", ":bn<CR>", opts)

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
keymap("n", "<leader>gc", ":Git commit -m ", noSilent)
keymap("n", "<leader>gs", ":Git status<CR>", opts)
keymap("n", "<leader>gP", ":Git push<CR>", opts)
keymap("n", "<leader>gp", ":Git pull<CR>", opts)
keymap("n", "<leader>gC", ":Git checkout ", noSilent)
keymap("n", "<leader>gCn", ":Git checkout -b ", noSilent)

-- open term
keymap("n", "<leader>tt", ":ToggleTerm direction=float fish<CR>", opts)
keymap("n", "<leader>tv", ":ToggleTerm direction=vertical size=100 fish<CR>", opts)
keymap("n", "<leader>th", ":ToggleTerm direction=horizontal size=10 fish<CR>", opts)

keymap("n", "<leader>bd", ":bd<CR>", opts)

-- mapping Open Buffer fzf telescope
keymap("n", "<leader>bb", ":lua require'telescope.builtin'.buffers()<CR>", opts)
keymap("n", "<leader>s", ":lua require('telescope.builtin').find_files()<CR>", opts)
keymap("n", "<leader>dot", ":lua require('rc_telescope').search_dotfiles()<CR>", opts)
keymap("n", "?", ":lua require('telescope.builtin').current_buffer_fuzzy_find()<CR>", opts)
keymap("n", "<C-s>", ":lua require('telescope.builtin').live_grep()<CR>", opts)
keymap("n", "<leader>bq", ":lua require('telescope.builtin').quickfix()<CR>", opts)
keymap("n", "<leader>gf", ":lua require('telescope.builtin').git_files()<CR>", opts)
keymap("n", "<leader>x",
	":lua require('telescope.builtin').diagnostics(require('telescope.themes').get_dropdown({}))<CR>", opts)


keymap("n", "<leader>ke", ":lua require('telescope.builtin').keymaps()<CR>", opts)
keymap("n", "<leader>reset", ":LspRestart<CR>", opts)
keymap("n", "<leader>cheat", ":Cheat<CR>", opts)

keymap("n", "<space>lf", ":lua vim.lsp.buf.format()<CR>", opts)

-- allow my cursor stay at the same place, when using `J`
keymap("n", "J", "mzJ`z", opts)

-- nvim-dap mapping debugging
keymap("n", "<F5>", ":lua require'dap'.continue()<CR>", opts)
keymap("n", "<F2>", ":lua require'dap'.step_over()<CR>", opts)
keymap("n", "<F3>", ":lua require'dap'.step_into()<CR>", opts)
keymap("n", "<F4>", ":lua require'dap'.step_out()<CR>", opts)
keymap("n", "<leader>db", ":lua require'dap'.toggle_breakpoint()<CR>", opts)
keymap("n", "<leader>dB", ":lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", opts)
keymap("n", "<leader>ds", ":lua require'dap-go'.debug_test()<CR>", opts)
keymap("n", "<leader>dt", ":lua require'dapui'.toggle()<CR>", opts)

-- lspsaga
keymap("n", "gD", "<cmd>Lspsaga finder<CR>", opts)
keymap("n", "<C-j>", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts)
keymap("n", "<C-l>", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts)
keymap("n", "gr", "<cmd>Lspsaga rename<CR>", opts)
keymap("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", opts)
keymap("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts)
keymap("n", "gd", "<cmd>Lspsaga goto_definition<CR>", opts)
keymap("n", "gsd", "<C-w>v<C-w>l<cmd>Lspsaga goto_definition<CR>", opts)
keymap("n", "gp", "<cmd>Lspsaga peek_definition<CR>", opts)

-- vim-test
keymap("n", "<leader>t", ":TestNearest<CR>", opts)
keymap("n", "<leader>T", ":TestFile<CR>", opts)
keymap("n", "<leader>a", ":TestSuite<CR>", opts)
keymap("n", "<leader>l", ":TestLast<CR>", opts)
keymap("n", "<leader>tv", ":TestNearest -v<CR>", opts)

-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)

-- half page jumping, and keep the cursor in front
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)

-- allow search term to be in the middle
keymap("n", "n", "nzzzv", opts)
keymap("n", "N", "Nzzzv", opts)

local function setup_mappings()
	-- NERDTree mappings
	keymap('n', '<leader>n', ':NERDTreeFocus<CR>', opts)
	keymap('n', '<C-p>', ':NERDTreeToggle<CR>', opts)
	keymap('n', '<leader>f', ':NERDTreeFind<CR>', opts)

	-- Exit Vim if NERDTree is the only window remaining in the only tab.
	vim.cmd(
		[[ autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif ]])
end

setup_mappings()
