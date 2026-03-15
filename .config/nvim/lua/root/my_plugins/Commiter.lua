local model = "opencode/minimax-m2.5-free"

local preprompt = "Generate a git commit message for the staged changes below. "
	.. "Follow conventional commits format (feat/fix/refactor/docs/chore/etc with optional scope). "
	.. "Respond ONLY with the commit message text — no explanation, no markdown fences, nothing else."

local function strip_ansi(str)
	return str:gsub("\27%[[%d;]*m", ""):gsub("\27%[%?%d+[hl]", ""):gsub("\27%[[%d]*[A-Za-z]", ""):gsub("\r", "")
end

-- Fill a specific buffer (captured at job-start time)
local function fill_commit_editmsg(buf, message)
	local lines = vim.split(message, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
	-- switch to that buffer's window and move cursor to top
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			vim.api.nvim_win_set_cursor(win, { 1, 0 })
			break
		end
	end
	vim.notify("Commit message filled — edit then :wq to commit.", vim.log.levels.INFO)
end

-- Open a floating scratch buffer, commit on confirm
local function open_commit_float(message)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].filetype = "gitcommit"
	vim.bo[buf].modifiable = true

	local lines = vim.split(message, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = math.min(100, vim.o.columns - 4)
	local height = math.min(30, vim.o.lines - 6)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = "rounded",
		title = " Commit Message — <C-s> confirm · q cancel ",
		title_pos = "center",
	})
	vim.wo[win].wrap = true

	local function do_commit()
		local commit_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local commit_msg = table.concat(commit_lines, "\n"):match("^%s*(.-)%s*$")
		if commit_msg == "" then
			vim.notify("Empty commit message, aborting.", vim.log.levels.WARN)
			return
		end
		vim.api.nvim_win_close(win, true)
		local tmpfile = vim.fn.tempname()
		vim.fn.writefile(vim.split(commit_msg, "\n"), tmpfile)
		local result = vim.fn.system("git commit -F " .. vim.fn.shellescape(tmpfile))
		vim.fn.delete(tmpfile)
		if vim.v.shell_error ~= 0 then
			vim.notify("Commit failed:\n" .. result, vim.log.levels.ERROR)
		else
			vim.notify(result:match("^%s*(.-)%s*$"), vim.log.levels.INFO)
		end
	end

	vim.keymap.set("n", "<C-s>", do_commit, { buffer = buf, noremap = true, desc = "Confirm commit" })
	vim.keymap.set("i", "<C-s>", function()
		vim.cmd("stopinsert")
		do_commit()
	end, { buffer = buf, noremap = true, desc = "Confirm commit" })
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
		vim.notify("Commit cancelled.", vim.log.levels.INFO)
	end, { buffer = buf, noremap = true, desc = "Cancel commit" })
end

local function commit()
	local staged_files = vim.fn.systemlist("git diff --staged --name-only")
	if #staged_files == 0 then
		vim.notify("No staged files to commit.", vim.log.levels.WARN)
		return
	end

	-- Capture context before async work starts
	local current_buf = vim.api.nvim_get_current_buf()
	local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(current_buf), ":t")
	local in_commit_buf = buf_name == "COMMIT_EDITMSG"

	vim.notify("Generating commit message…", vim.log.levels.INFO)

	vim.system({ "git", "diff", "--staged" }, { text = true }, function(diff_result)
		vim.schedule(function()
			if diff_result.code ~= 0 or not diff_result.stdout or diff_result.stdout == "" then
				local err = (diff_result.stderr or ""):match("^%s*(.-)%s*$")
				vim.notify("Failed to get staged diff." .. (err ~= "" and ("\n" .. err) or ""), vim.log.levels.ERROR)
				return
			end

			local diff = diff_result.stdout
			local prompt = preprompt .. "\n\n" .. diff
			vim.notify("preparing the prompt")

			vim.system({
				"opencode",
				"run",
				"-m",
				model,
				prompt,
			}, {
				text = true,
			}, function(result)
				vim.schedule(function()
					if result.code ~= 0 then
						local err = (result.stderr or ""):match("^%s*(.-)%s*$")
						vim.notify(
							"opencode exited with code " .. result.code .. (err ~= "" and (": " .. err) or ""),
							vim.log.levels.ERROR
						)
						return
					end

					local response = strip_ansi(result.stdout or "")
					response = response:match("^%s*(.-)%s*$")

					if response == "" then
						vim.notify("opencode returned an empty response.", vim.log.levels.ERROR)
						return
					end

					if in_commit_buf and vim.api.nvim_buf_is_valid(current_buf) then
						fill_commit_editmsg(current_buf, response)
					else
						open_commit_float(response)
					end
				end)
			end)
		end)
	end)
end

vim.api.nvim_create_user_command("Commiter", commit, {})
vim.keymap.set("n", "<leader>ai", "<cmd>Commiter<CR>", { noremap = true, silent = true, desc = "AI commit message" })

return {
	strip_ansi = strip_ansi,
	is_commit_editmsg = function()
		local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
		return name == "COMMIT_EDITMSG"
	end,
	fill_commit_editmsg = fill_commit_editmsg,
	open_commit_float = open_commit_float,
}
