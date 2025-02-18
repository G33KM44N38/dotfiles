local function GenerateCommitMessageWithAI(provider)
	-- Default to OpenAI if no provider specified
	provider = provider or "openai"

	-- Check if in a commit message buffer
	if vim.bo.filetype ~= 'gitcommit' or
	    not (vim.fn.expand('%:t') == 'COMMIT_EDITMSG' or
		    vim.fn.expand('%:t'):match('%.git/COMMIT_EDITMSG$')) then
		vim.notify("Not in a commit message buffer", vim.log.levels.ERROR)
		return
	end

	-- Get staged changes (files)
	local staged_changes = vim.fn.systemlist('git diff --staged --name-status')

	if #staged_changes == 0 then
		vim.notify("No staged changes found.", vim.log.levels.INFO)
		return
	end

	-- Get detailed diff
	local staged_diff = vim.fn.systemlist('git diff --staged')

	-- Combine diff into a single string
	local diff_content = table.concat(staged_diff, "\n")

	-- Prepare the prompt
	local prompt = [[
You are an AI assistant specialized in generating concise, informative Git commit messages. When presented with a set of changes, follow these guidelines:

Commit Message Structure:
1. Start with a clear, descriptive type and scope
2. Write a brief summary line explaining the primary change
3. Provide a detailed description with key changes and motivation

Analyze the following changes and generate an appropriate commit message:
]] .. diff_content


	-- Show loading notification
	local loading_notification
	loading_notification = vim.notify("Generating commit message...", vim.log.levels.INFO, {
		title = "AI Commit Message",
		timeout = false,
		on_close = function()
			-- Ensure notification is cleared
			if loading_notification then
				loading_notification.close()
			end
		end
	})

	-- Curl library
	local curl = require('plenary.curl')

	-- Function to generate commit message
	local function process_ai_response(commit_message)
		-- Close loading notification
		if loading_notification then
			loading_notification.close()
		end

		-- Clear existing content and set new commit message
		vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(commit_message, "\n"))

		-- Notify success
		vim.notify("Commit message generated successfully", vim.log.levels.INFO, {
			title = "AI Commit Message"
		})
	end

	-- Provider-specific logic
	if provider == "openai" then
		local api_key = os.getenv("OPENAI_API_KEY")

		if not api_key then
			vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
			return
		end

		curl.post({
			url = "https://api.openai.com/v1/chat/completions",
			headers = {
				Authorization = "Bearer " .. api_key,
				["Content-Type"] = "application/json"
			},
			body = vim.fn.json_encode({
				model = "gpt-3.5-turbo",
				messages = {
					{
						role = "system",
						content = "You are a Git commit message generator."
					},
					{
						role = "user",
						content = prompt
					}
				},
				max_tokens = 300,
				temperature = 0.7
			}),
			callback = vim.schedule_wrap(function(response)
				if response.status ~= 200 then
					vim.notify("Error generating commit message: " .. vim.inspect(response), vim.log.levels.ERROR)
					return
				end

				local result = vim.fn.json_decode(response.body)
				local commit_message = result.choices[1].message.content:gsub("^%s+", ""):gsub("%s+$", "")
				process_ai_response(commit_message)
			end)
		})
	elseif provider == "ollama" then
		-- Ollama local API endpoint
		curl.post({
			url = "http://localhost:11434/api/chat",
			headers = {
				["Content-Type"] = "application/json"
			},
			body = vim.fn.json_encode({
				model = "deepseek-r1:1.5b", -- You can change this to your preferred model
				messages = {
					{
						role = "system",
						content =
						"You are a Git commit message generator. Generate a concise and descriptive commit message."
					},
					{
						role = "user",
						content = prompt
					}
				},
				stream = false
			}),
			callback = vim.schedule_wrap(function(response)
				if response.status ~= 200 then
					vim.notify("Error generating commit message from Ollama: " .. vim.inspect(response),
						vim.log.levels.ERROR)
					return
				end

				local result = vim.fn.json_decode(response.body)
				local commit_message = result.message.content:gsub("^%s+", ""):gsub("%s+$", "")
				process_ai_response(commit_message)
			end)
		})
	else
		vim.notify("Unsupported AI provider: " .. provider, vim.log.levels.ERROR)
	end
end

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

		-- Autocommand to trigger the staged changes when entering a commit buffer
		-- vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		-- 	pattern = { "COMMIT_EDITMSG", "*.git/COMMIT_EDITMSG" },
		-- 	callback = GenerateCommitMessageWithAI
		-- })


		vim.api.nvim_set_keymap('n', '<leader>q', ':lua QuitMenu()<CR>', { noremap = true, silent = true })

		vim.cmd('command -bar -bang -nargs=* Gcommit lua InputArgs()')
		vim.keymap.set('n', 'gj', '<cmd>diffget //2<CR>')
		vim.keymap.set('n', 'gf', '<cmd>diffget //3<CR>')

		-- COMMIT AUTOGENERATED
		vim.api.nvim_create_user_command('AICommitMessage', function()
			GenerateCommitMessageWithAI('openai')
		end, {})

		vim.api.nvim_create_user_command('OllamaCommitMessage', function()
			GenerateCommitMessageWithAI('ollama')
		end, {})

		vim.api.nvim_set_keymap('n', '<leader>ai', ':AICommitMessage<CR>', { noremap = true, silent = true })
		vim.api.nvim_set_keymap('n', '<leader>oi', ':OllamaCommitMessage<CR>', { noremap = true, silent = true })

		vim.api.nvim_create_autocmd('FileType', {
			pattern = 'gitcommit',
			callback = function()
				vim.api.nvim_buf_set_keymap(0, 'n', '<leader>ai', ':AICommitMessage<CR>',
					{ noremap = true, silent = true })
				vim.api.nvim_buf_set_keymap(0, 'n', '<leader>oi', ':OllamaCommitMessage<CR>',
					{ noremap = true, silent = true })
			end
		})
	end
}
