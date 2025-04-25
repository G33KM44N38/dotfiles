require("root.core.keymap")
require("root.my_plugins.Commiter")
-- require("root.my_plugins.git-worktree.lua.git-worktree")

vim.opt.scrolloff = 1
-- Required to be compatible with Neovim
vim.opt.compatible = false

vim.opt.signcolumn = 'yes'

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
-- vim.opt.rtp:append('/usr/local/opt/fzf')

-- Show relative line numbers
vim.opt.rnu = true
vim.opt.nu = true

-- Enable the mouse in all modes
vim.opt.mouse = 'a'

-- Show line numbers
vim.opt.number = true

-- Automatically reload files that have been changed outside of Vim
vim.opt.autoread = true

-- Set the backspace behavior
vim.opt.backspace = { 'indent', 'eol', 'start' }

-- set the syntax on
vim.cmd("autocmd FileType go syntax enable")


-- Transparent background
vim.cmd('hi Normal guibg=NONE ctermbg=NONE')

-- Set tabstops for filetypes
vim.cmd("autocmd Filetype * setlocal ts=5 sw=5")

-- Set no swapfile
vim.opt.swapfile = false

-- Run LSP format on buffer write post
-- vim.cmd('silent! autocmd BufWritePost * lua vim.lsp.buf.format()')

vim.g.ft_man_open_mode = 'vert'
vim.g.cmake_link_compile_commands = 1
vim.g.rnvimr_ex_enable = 1
-- vim.g.netrw_liststyle = 3
-- vim.g.netrw_banner = 0
-- vim.g.netrw_winsize = 20

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

-- no higlight search
vim.cmd('set nohlsearch')

-- set completeopt=noinsert,menuone,noselect
vim.g.completion_matching_strategy_list = { 'exact', 'substring', 'fuzzy', 'all' }

-- configure nvcode-color-schemes
vim.g.nvcode_termcolors = 256


vim.cmd("set nowrap")
vim.api.nvim_set_option_value('autoindent', false, {})
vim.api.nvim_set_option_value('wrap', false, {})

vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldcolumn = "0" -- Disables the fold column
vim.opt.foldtext = ""    -- Shows syntax highlighting in folded text
-- vim.opt.foldlevelstart = 1 -- Closes nested folds by default

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local bufnr = args.buf
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if vim.tbl_contains({ 'null-ls' }, client.name) then -- blacklist lsp
			return
		end
	end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_autocmd("BufRead", {
	pattern = "*.txt",
	callback = function()
		vim.cmd("TSBufDisable highlight")
	end
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { ".env", ".env.*" },
	callback = function()
		vim.bo.filetype = "dotenv"
	end
})

vim.api.nvim_create_user_command("FileCreationDate", function()
	local date = vim.fn.system('stat -c %w ' .. vim.fn.expand('%'))
	print(os.date('%Y-%m-%d %H:%M:%S', vim.fn.system('stat -f %B ' .. vim.fn.expand('%'))))
end, {})

vim.api.nvim_create_autocmd("TermOpen", {
	group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
	callback = function()
		vim.opt.number = false
		vim.opt.relativenumber = false
		vim.api.nvim_set_keymap("i", "<C-\\><C-n>", "<Esc>", { noremap = true, silent = true })
	end
})
