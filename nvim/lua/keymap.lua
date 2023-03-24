-- Enable termguicolors
vim.o.termguicolors = true
vim.cmd("set termguicolors")

local opts = { noremap = true, silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

vim.api.nvim_set_option('autoindent', true)
vim.api.nvim_set_option('wrap', false)
vim.api.nvim_set_keymap('n', '<Space>f', ':Files<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<Space>pv', ':NERDTree<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<Space>lg', ':LazyGit<CR>', { noremap = true })
vim.api.nvim_set_keymap('i', 'kj', '<Esc>', {})
vim.api.nvim_set_keymap('i', 'KJ', '<Esc>', {})

-- Required to be compatible with Neovim
vim.opt.compatible = false

-- Set fill characters for statusline
vim.opt.fillchars:append({ stl = ' ', stlnc = ' ' })

-- Set fold method to 'indent'
vim.opt.foldmethod = 'indent'

-- Set the fold level to 99
vim.opt.foldlevel = 99

-- Set the encoding to UTF-8
vim.opt.encoding = 'utf-8'

-- Enable unnamed clipboard
vim.opt.clipboard = 'unnamed'

-- Show matching brackets
vim.opt.showmatch = true

-- Add FZF to the runtime path
vim.opt.rtp:append('/usr/local/opt/fzf')

-- Show relative line numbers
vim.opt.rnu = true

-- Enable the mouse in all modes
vim.opt.mouse = 'a'

-- Show line numbers
vim.opt.number = true

-- Automatically reload files that have been changed outside of Vim
vim.opt.autoread = true

-- Set the backspace behavior
vim.opt.backspace = { 'indent', 'eol', 'start' }


-- Set the color scheme to Alduin
vim.cmd('colorscheme alduin')

-- Transparent background
vim.cmd('hi Normal guibg=NONE ctermbg=NONE')

-- Set tabstops for filetypes
vim.cmd('autocmd Filetype css setlocal ts=3 sw=3 expandtab')
vim.cmd('autocmd Filetype javascript setlocal ts=3 sw=3 expandtab')

-- Run gofmt before writing a go file
vim.cmd('autocmd BufWritePre *.go :silent! lua require("go.format").gofmt()')

-- Run LSP format on buffer write post
vim.cmd('autocmd BufWritePost * lua vim.lsp.buf.format()')

-- Run LSP formatting sync on InsertLeave event
vim.cmd('autocmd BufWritePre (InsertLeave?) <buffer> lua vim.lsp.buf.formatting_sync(nil,500)')

vim.g.ft_man_open_mode = 'vert'
vim.g.cmake_link_compile_commands = 1
vim.g.rnvimr_ex_enable = 1
vim.g.netrw_liststyle = 3
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 20

-- lazygit
vim.g.lazygit_floating_window_winblend = 0 -- transparency of floating window
vim.g.lazygit_floating_window_scaling_factor = 0.9 -- scaling factor for floating window
vim.g.lazygit_floating_window_corner_chars = {'╭', '╮', '╰', '╯'} -- customize lazygit popup window corner characters
vim.g.lazygit_floating_window_use_plenary = 0 -- use plenary.nvim to manage floating window if available
vim.g.lazygit_use_neovim_remote = 1 -- fallback to 0 if neovim-remote is not installed
vim.g.lazygit_use_custom_config_file_path = 0
vim.g.lazygit_config_file_path = ''

function setup_mappings()
  -- NERDTree mappings
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

require'lspconfig'

-- Airline_Vim
vim.g.airline_powerline_fonts = 1
if not vim.g.airline_symbols then
    vim.g.airline_symbols = {}
end

-- Custom indentPlugin Show
vim.g.indent_guides_enable_on_vim_startup = 1
vim.g.indent_guides_auto_colors = 0
vim.g.indent_guides_start_level = 2
vim.g.indent_guides_guide_size = 1
vim.cmd('highlight IndentGuidesOdd ctermbg=238')
vim.cmd('highlight IndentGuidesEven ctermbg=242')
vim.cmd('highlight Error NONE')
vim.cmd('highlight ErrorMsg NONE')

-- Disable function highlighting (affects both C and C++ files)
vim.g.cpp_function_highlight = 1

-- Enable highlighting of C++11 attributes
vim.g.cpp_attributes_highlight = 1

-- Highlight struct/class member variables (affects both C and C++ files)
vim.g.cpp_member_highlight = 1

-- configure treesitter
require'nvim-treesitter.configs'.setup {
	ensure_installed = "all", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
	highlight = {
		enable = true, -- false will disable the whole extension
		disable = { "rust" }, -- list of language that will be disabled
	},
}

-- vim-test
vim.cmd('let test#strategy = "vimux"')

-- set completeopt=noinsert,menuone,noselect
vim.g.completion_matching_strategy_list = {'exact', 'substring', 'fuzzy', 'all'}

-- configure nvcode-color-schemes
vim.g.nvcode_termcolors = 256

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- running macro
keymap("n", "<leader>q", "@q", opts)
-- Save
keymap("n", "<leader>w", ":w<CR> :wa<CR>", opts)

-- mapping change viewport
keymap("n", "<S-TAB>", "<C-W><C-W>", opts)
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
keymap("n", "<leader>th", ":ToggleTerm direction=horizontal size=100 fish<CR>", opts)

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

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
