local THINKING_END_BALISE = "</think>"

local EXAMPLE_OF_COMMIT = [[

Here are five **Conventional Commit** examples based on different types of changes:

### 1️⃣ **Feature Addition**
feat(ui): add dark mode toggle

Implemented a dark mode toggle in the settings menu. Users can now switch between light and dark themes, with preferences saved in local storage.

- Added a toggle switch in the UI
- Implemented theme persistence using localStorage
- Updated styles for dark mode compatibility

Closes #15

### 2️⃣ **Bug Fix**
Fixed an issue where expired JWT tokens were not being properly invalidated, leading to authentication errors.

- Updated token validation logic
- Added better error handling for expired tokens
- Improved logging for debugging authentication issues

Closes #27

### 3️⃣ **Performance Improvement**
perf(database): optimize query for user search

Refactored the user search query to improve response times by 40%. Added indexing for better performance on large datasets.

- Replaced full table scan with indexed search
- Reduced query execution time from 2s to 200ms
- Updated tests to cover edge cases

Closes #33

### 4️⃣ **Code Refactoring**
refactor(auth): modularize authentication logic

Reorganized authentication functions into separate modules for better maintainability and reusability.

- Moved token generation and validation to separate files
- Improved function documentation
- No changes in functionality


### 5️⃣ **Chore (Tooling/CI Updates)**
chore(deps): upgrade Next.js to v14

Updated Next.js to the latest version to benefit from performance improvements and new features.

- Upgraded Next.js from v13 to v14
- Fixed minor compatibility issues
- Updated package-lock.json


Would you like me to tailor these to a specific project or context ? ]]

local PREPROMPT = [[
You are an AI specialized in generating precise and informative Git commit messages. Given a diff, your task is to analyze the changes and generate a commit message that follows best practices.

Commit Message Structure:

Type and Scope:

Use conventional commit types: feat, fix, docs, refactor, chore, etc.
Specify the scope if relevant, e.g., docs(readme).
Brief Summary:

Concisely describe the primary change.
Detailed Explanation:

Explain what was changed.
Justify why the change was made.
Mention any implications.
Formatting Rules:

Use imperative mood (e.g., "Update README" instead of "Updated README").
Capitalize the first letter of the summary.
No period at the end of the summary.
Use bullet points for clarity if necessary.
Example Output:
docs(readme): Fix typo in README

Fixed an unintended addition of "eh+" in the README file.
Ensured the formatting remains clean and correct.

Instructions:

Analyze the diff carefully.
Identify the core change (e.g., typo fix, content addition, formatting update).
Generate a structured commit message following the guidelines.
Respond ONLY with the commit message, no extra explanations.
Do not summarize the entire document. Focus ONLY on the changes made in the diff. If the change is a typo fix, mention it explicitly. If it is a content addition, specify what was added. Respond ONLY with a structured commit message following the guidelines.

]] .. EXAMPLE_OF_COMMIT

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
	-- vim.notify(table.concat(staged_diff), vim.log.levels.INFO, {})


	local diff_content = table.concat(staged_diff, "\n")

	local prompt = [[
		Changes:
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
		-- vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(commit_message, "\n"))
		-- insert commit message at the beginning of the buffer
		vim.api.nvim_buf_set_lines(0, 0, 0, false, vim.split(commit_message, "\n"))

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
				model = "gpt-4o-mini",
				messages = {
					{
						role = "system",
						content = PREPROMPT
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
						content = PREPROMPT
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
				-- split the message in to parts before THINKING_END_BALISE and after
				local parts = vim.split(result.message.content, THINKING_END_BALISE)
				local commit_message = parts[2]:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
				process_ai_response(commit_message)
				-- local commit_message = result.message.content:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
				-- process_ai_response(commit_message)
			end)
		})
	else
		vim.notify("Unsupported AI provider: " .. provider, vim.log.levels.ERROR)
	end
end

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

return {
	'tpope/vim-fugitive',
	config = function()
		vim.api.nvim_set_keymap('n', '<leader>q', ':lua QuitMenu()<CR>', { noremap = true, silent = true })

		vim.cmd('command -bar -bang -nargs=* Gcommit lua InputArgs()')
		vim.keymap.set('n', 'gj', '<cmd>diffget //2<CR>')
		vim.keymap.set('n', 'gf', '<cmd>diffget //3<CR>')

		vim.api.nvim_create_user_command('AICommitMessage', function()
			GenerateCommitMessageWithAI('openai')
		end, {})

		vim.api.nvim_create_user_command('OllamaCommitMessage', function()
			GenerateCommitMessageWithAI('ollama')
		end, {})

		-- vim.api.nvim_create_autocmd('BufReadPost', {
		-- 	pattern = 'COMMIT_EDITMSG',
		-- 	callback = function()
		-- 		-- Automatically generate commit message using Ollama
		-- 		vim.defer_fn(function()
		-- 			GenerateCommitMessageWithAI('ollama')
		-- 		end, 100) -- Small delay to ensure buffer is fully loaded
		-- 	end
		-- })

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
