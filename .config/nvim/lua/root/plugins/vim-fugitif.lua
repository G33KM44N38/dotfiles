return {
	'tpope/vim-fugitive',
	config = function()
		local menu_options = {
			{ key = 'build', desc = 'Build', emoji = '🏗️' },
			{ key = 'ci', desc = 'Continuous Integration', emoji = '🔄' },
			{ key = 'docs', desc = 'Documentation', emoji = '📚' },
			{ key = 'feat', desc = 'Feature', emoji = '✨' },
			{ key = 'fix', desc = 'Bug Fix', emoji = '🐛' },
			{ key = 'perf', desc = 'Performance Improvement', emoji = '🚀' },
			{ key = 'refactor', desc = 'Code Refactoring', emoji = '🧹' },
			{ key = 'test', desc = 'Testing', emoji = '🧪' }
		}

		function ShowMenu()
			local menu_items = { 'Select a commit type:' }
			for index, option in ipairs(menu_options) do
				table.insert(menu_items, index .. '. ' .. option.desc)
			end
			local choice = vim.fn.inputlist(menu_items)
			return choice > 0 and menu_options[choice] or nil -- Return the whole option object.
		end

		function InputArgs()
			local option = ShowMenu() -- This will now hold the entire selected option object.
			if option then
				local message = vim.fn.input('Message: ')
				if message ~= '' then
					vim.cmd('echo "Message entered: "')
					vim.cmd('echo "' .. message .. '"')
					local commitMessage = option.emoji ..
					    ' ' .. option.key .. ': ' .. message -- Include the emoji.
					vim.cmd('G commit -v -m "' .. commitMessage .. '"')
				else
					vim.cmd('echo "No message entered. Action canceled"')
				end
			else
				vim.cmd('echo "No commit type selected. Action canceled"')
			end
		end

		vim.cmd('command -bar -bang -nargs=* Gcommit lua InputArgs()')
		vim.api.nvim_set_keymap('n', '<leader>gc', ':Gcommit<CR>', { noremap = true, silent = true })
	end
}
