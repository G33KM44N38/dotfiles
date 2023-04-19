-- Enable termguicolors
vim.o.termguicolors = true
vim.cmd("set termguicolors")

local opts = { noremap = true, silent = true }

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

vim.api.nvim_set_keymap('n', '<leader>f', ':Files<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>lg', ':LazyGit<CR>', { noremap = true })
vim.api.nvim_set_keymap('i', 'kj', '<Esc>', {})
vim.api.nvim_set_keymap('i', 'KJ', '<Esc>', {})


function setup_mappings()
	-- NERDTree mappings
	vim.api.nvim_set_keymap('n', '<leader>pv', ':NERDTree<CR>', { noremap = true })
	vim.api.nvim_set_keymap('n', '<leader>n', ':NERDTreeFocus<CR>', { noremap = true })
	vim.api.nvim_set_keymap('n', '<C-t>', ':NERDTreeToggle<CR>', { noremap = true })
	vim.api.nvim_set_keymap('n', '<C-f>', ':NERDTreeFind<CR>', { noremap = true })

	-- Exit Vim if NERDTree is the only window remaining in the only tab.
	vim.cmd([[ autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif ]])
end

setup_mappings()

require('dap-go').setup()

local data_dir = vim.fn.has('nvim') == 1 and vim.fn.stdpath('data') .. '/site' or '~/.vim'
if vim.fn.empty(vim.fn.glob(data_dir .. '/autoload/plug.vim')) > 0 then
	vim.fn.execute('!curl -fLo ' .. data_dir .. '/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim')
	vim.cmd([[ autocmd VimEnter * PlugInstall --sync | source $MYVIMRC ]])
end


	-- running macro
	keymap("n", "<leader>q", "@q", opts)
	-- Save
	keymap("n", "<leader>w", ":w<CR> :wa<CR>", opts)

	-- mapping change viewport
	keymap("n", "<S-TAB>", ":bp<CR>", opts)
	keymap("n", "<TAB>", ":bn<CR>", opts)

	-- make
	keymap("n", "<leader>m", ":make ", opts)

	-- commante line
	keymap("n", "<leader><leader>c", ":Commentary <CR>", opts)

	-- paste without overwrite
	vim.keymap.set("x", "<leader>p", "\"_dP")

	-- paste to the clipboard
	vim.keymap.set("n", "<leader>y", "\"+y")
	vim.keymap.set("v", "<leader>y", "\"+y")
	vim.keymap.set("n", "<leader>Y", "\"+y")

	-- copilot
	keymap("n", "<leader>co", ":Copilot panel<CR>", opts)

	-- mapping fugitif
	keymap("n", "<leader>gs", ":G<CR>", opts)
	keymap("n", "<leader>gc", ":Git commit<CR>", opts)
	keymap("n", "<leader>gp", ":Git push<CR>", opts)
	keymap("n", "<leader>gb", ":Git checkout", opts)

	-- open term
	keymap("n", "<leader>tt", ":ToggleTerm direction=float fish<CR>", opts)
	keymap("n", "<leader>tv", ":ToggleTerm direction=vertical size=100 fish<CR>", opts)
	keymap("n", "<leader>th", ":ToggleTerm direction=horizontal size=10 fish<CR>", opts)

	-- mapping Open Buffer fzf telescope
	keymap("n", "<leader>bd", ":bd<CR>", opts)
	keymap("n", "<leader>bb", ":lua require'telescope.builtin'.buffers()<CR>", opts)

	-- keymap("n", "<leader>t", ":! ctags <CR> :lua require('telescope.builtin').tags()<CR>", opts)
	keymap("n", "bf", ":lua require('telescope.builtin').find_files()<CR>", opts)
	keymap("n", "<leader>dot", ":lua require('rc_telescope').search_dotfiles()<CR>", opts)
	keymap("n", "<leader>conf", ":lua require('rc_telescope').config()<CR>", opts)
	keymap("n", "?", ":lua require('telescope.builtin').current_buffer_fuzzy_find()<CR>", opts)
	keymap("n", "br", ":lua require('telescope.builtin').live_grep()<CR>", opts)
	keymap("n", "<leader>bq", ":lua require('telescope.builtin').quickfix()<CR>", opts)
	keymap("n", "gf", ":lua require('telescope.builtin').git_files()<CR>", opts)
	keymap("n", "<leader>xx", ":lua require('telescope.builtin').diagnostics()<CR>", opts)

	keymap("n", "<leader>km", ":lua require('telescope.builtin').keymaps()<CR>", opts)
	keymap("n", "<leader>old", ":lua require('telescope.builtin').oldfiles()<CR>", opts)
	keymap("n", "<leader>reset", ":LspRestart<CR>", opts)
	keymap("n", "<leader>cheat", ":Cheat<CR>", opts)

	-- local autogroup = vim.api.nvim_create_augroup("LspFormatting", {})
	keymap("n", "<space>lf", ":lua vim.lsp.buf.format()<CR>", opts)

	-- nvim-dap mapping debugging
	keymap("n", "<F5>", ":lua require'dap'.continue()<CR>", opts)
	keymap("n", "<F2>", ":lua require'dap'.step_over()<CR>", opts)
	keymap("n", "<F3>", ":lua require'dap'.step_into()<CR>", opts)
	keymap("n", "<F4>", ":lua require'dap'.step_out()<CR>", opts)
	keymap("n", "<leader>b", ":lua require'dap'.toggle_breakpoint()<CR>", opts)
	keymap("n", "<leader>B", ":lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", opts)
	keymap("n", "<leader>ds", ":lua require'dap-go'.debug_test()<CR>", opts)
	keymap("n", "<leader>du", ":lua require'dapui'.toggle()<CR>", opts)

	-- lspsaga
	vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts)
	vim.keymap.set("n", "gD", "<cmd>Lspsaga lsp_finder<CR>", opts)
	vim.keymap.set("i", "<C-k>", "<cmd>Lspsaga signature_help<CR>", opts)
	vim.keymap.set("n", "<C-j>", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts)
	vim.keymap.set("n", "gr", "<cmd>Lspsaga rename<CR>", opts)
	vim.keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", opts)
	vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts)
	vim.keymap.set("n", "gd", "<cmd>Lspsaga goto_definition<CR>", opts)

	require("nvim-dap-virtual-text").setup()
	require("dapui").setup()

	-- vim-test
	vim.keymap.set("n", "<leader>t", ":TestNearest -v<CR>", { silent = true })
	vim.keymap.set("n", "<leader>T", ":TestFile<CR>", { silent = true })
	vim.keymap.set("n", "<leader>a", ":TestSuite<CR>", { silent = true })
	vim.keymap.set("n", "<leader>l", ":TestLast<CR>", { silent = true })
	vim.keymap.set("n", "<leader>g", ":TestVisit<CR>", { silent = true })

	-- Move text up and down
	keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
	keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
