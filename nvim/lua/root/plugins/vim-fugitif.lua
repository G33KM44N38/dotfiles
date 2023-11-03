return {
	'tpope/vim-fugitive',
	config = function()
		vim.cmd('command -bar -bang -nargs=* Gfix :G commit<bang> -v -m "🔧 FIX: <args> 🔧"')
		vim.cmd('command -bar -bang -nargs=* Gfeature :G commit<bang> -v -m "🚀 FEATURE: <args> 🚀"')
	end
}
