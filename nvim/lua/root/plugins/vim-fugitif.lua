return {
	'tpope/vim-fugitive',
	config = function()
		function InputArgs(format)
			local message = vim.fn.input('Enter your message: ')
			if message ~= '' then
				vim.cmd('echo "Message entered: "')
				vim.cmd('echo "' .. message .. '"')
				vim.cmd('G commit -v -m "' .. format .. message .. '"')
			else
				vim.cmd('echo "No message entered. Action canceled"')
			end
		end


		vim.cmd('command -bar -bang -nargs=* Gfix lua InputArgs("🔧 FIX: ")')
		vim.cmd('command -bar -bang -nargs=* Gfeature lua InputArgs("🚀 FEATURE: ")')
	end
}
