return {
	'tpope/vim-fugitive',
	config = function()
		local menu_options = {
			{ key = 'build', desc = 'Build', emoji = '🏗️' },
			{ key = 'ci', desc = 'Continuous Integration', emoji = '🤖' },
			{ key = 'docs', desc = 'Documentation', emoji = '📚' },
			{ key = 'feat', desc = 'Feature', emoji = '✨' },
			{ key = 'fix', desc = 'Bug Fix', emoji = '🐛' },
			{ key = 'perf', desc = 'Performance Improvement', emoji = '⚡' },
			{ key = 'refactor', desc = 'Code Refactoring', emoji = '🛠️' },
			{ key = 'test', desc = 'Testing', emoji = '🧪' }
		}

		function ShowMenu()
			local menu_items = { 'Select a commit type:' }
			for index, option in ipairs(menu_options) do
				table.insert(menu_items, index .. '. ' .. option.emoji .. ' ' .. option.desc)
			end
			local choice = vim.fn.inputlist(menu_items)
			return choice > 0 and menu_options[choice] or nil
		end

		function InputArgs()
			local selected_option = ShowMenu()
			if selected_option then
				vim.cmd('redraw')
				vim.cmd('echo "You selected: ' .. selected_option.emoji .. ' - ' .. selected_option.key .. '"')
				local message = vim.fn.input('Message: ')
				if message ~= '' then
					vim.cmd('redraw') -- Optionally redraw again if needed
					vim.cmd('echo "Message entered: "')
					vim.cmd('echo "' .. message .. '"')
					local commitMessage = selected_option.key .. ': ' .. message .. ' ' .. selected_option.emoji
					vim.cmd('G commit -v -m "' .. commitMessage .. '"')
				else
					vim.cmd('redraw') -- Clear the screen before showing the message
					vim.cmd('echo "No message entered. Action canceled"')
				end
			else
				vim.cmd('redraw') -- Clear the screen before showing the message
				vim.cmd('echo "No commit type selected. Action canceled"')
			end
		end

		function QuitMenu()
			vim.cmd('redraw')
			vim.cmd('echo "Menu closed. Action canceled"')
		end

		vim.api.nvim_set_keymap('n', '<leader>q', ':lua QuitMenu()<CR>', { noremap = true, silent = true })

		vim.cmd('command -bar -bang -nargs=* Gcommit lua InputArgs()')
		-- vim.api.nvim_set_keymap('n', '<leader>gc', ':Gcommit<CR>', { noremap = true, silent = true })
		vim.keymap.set('n', 'gj', '<cmd>diffget //2<CR>')
		vim.keymap.set('n', 'gf', '<cmd>diffget //3<CR>')
	end
}
