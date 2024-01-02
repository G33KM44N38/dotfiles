return {
	'tpope/vim-fugitive',
	config = function()
		function InputArgs(format)
			local message = vim.fn.input(format)
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
		vim.cmd('command -bar -bang -nargs=* Gstyle lua InputArgs("🖌 APPEARANCE: ")')
		vim.cmd('command -bar -bang -nargs=* Gtest lua InputArgs("🧪 UNIT-TEST: ")')
		vim.cmd('command -bar -bang -nargs=* Grefacto lua InputArgs("🧨 REFACTO: ")')
		vim.cmd('command -bar -bang -nargs=* Gdebug lua InputArgs("💬 DEBUG: " )')
	end
}
