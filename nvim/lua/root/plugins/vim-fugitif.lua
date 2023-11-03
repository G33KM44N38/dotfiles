function InputArgs()
	local message = vim.fn.input('🔧 FIX: ')
	vim.fn.execute('G commit' .. (vim.fn.v:count() > 0 and '!' or '') .. ' -v -m "🔧 FIX: ' .. message .. ' 🔧"')
end

return {

	'tpope/vim-fugitive',
	config = function()
		vim.cmd('command -bar -bang -nargs=* Gfix :G commit<bang> -v -m "🔧 FIX: call InputArgs() 🔧"')
		vim.cmd('command -bar -bang -nargs=* Gfeature :G commit<bang> -v -m "🚀 FEATURE: <args> 🚀"')
	end
}
