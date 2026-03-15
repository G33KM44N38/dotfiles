local model = "anthropic/claude-haiku-4-5"

local opencode_server_host = "127.0.0.1"
local opencode_server_port = 4096
local opencode_server_url = "http://" .. opencode_server_host .. ":" .. opencode_server_port

local server_job_id = nil
local server_starting = false

local preprompt = [[
You are generating a git commit message from a staged diff.

Goal:
Write the most useful commit message for future maintainers reading git history.
Preserve intent and context, not just surface-level file changes.

Requirements:
- Use Conventional Commits format: type(scope): subject
- Choose the most accurate type (feat, fix, refactor, docs, test, chore, perf, build, ci, style, revert)
- Add a scope when it improves clarity
- The subject must be specific and descriptive, not generic
- Focus on why the change exists and what behavior changed
- Infer the higher-level purpose from the diff when possible
- Mention important side effects, constraints, fixes, or refactors if they are central
- Avoid vague subjects like:
  - update code
  - fix issue
  - refactor stuff
  - improve commit
- Do not mention irrelevant implementation noise
- Do not invent behavior that is not supported by the diff

Output format:
- First line: a single concise Conventional Commit subject
- Then a blank line
- Then a body as bullet points only if it adds important context
- Keep the body brief but information-dense
- Include in the body only the most important details:
  - behavior change
  - motivation
  - important refactor
  - edge case handled
  - risk or migration impact

Rules:
- Return only the commit message
- No markdown fences
- No explanation before or after
- Prefer a strong descriptive subject over a short vague one
- If the change is simple, subject only is fine
- If the change is nuanced, include a short body

Staged diff:
]]

local function strip_ansi(str)
	return str:gsub("\27%[[%d;]*m", ""):gsub("\27%[%?%d+[hl]", ""):gsub("\27%[[%d]*[A-Za-z]", ""):gsub("\r", "")
end

local function is_commit_editmsg(buf)
	buf = buf or 0
	local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
	return name == "COMMIT_EDITMSG"
end

local function is_server_ready()
	local ok, chan =
		pcall(vim.fn.sockconnect, "tcp", opencode_server_host .. ":" .. opencode_server_port, { rpc = false })

	if not ok or not chan or chan <= 0 then
		return false
	end

	pcall(vim.fn.chanclose, chan)
	return true
end

local function ensure_server()
	if is_server_ready() then
		return true
	end

	if server_job_id and server_job_id > 0 then
		return false
	end

	if server_starting then
		return false
	end

	server_starting = true

	server_job_id = vim.fn.jobstart({
		"opencode",
		"serve",
		"--hostname",
		opencode_server_host,
		"--port",
		tostring(opencode_server_port),
	}, {
		detach = false,
		on_stderr = function(_, data)
			if not data then
				return
			end

			local msg = table.concat(data, "\n"):match("^%s*(.-)%s*$")
			if msg == "" then
				return
			end

			vim.schedule(function()
				vim.notify("opencode serve: " .. msg, vim.log.levels.WARN)
			end)
		end,
		on_exit = function(_, code)
			server_job_id = nil
			server_starting = false

			if code ~= 0 then
				vim.schedule(function()
					vim.notify("opencode server exited with code " .. code, vim.log.levels.ERROR)
				end)
			end
		end,
	})

	if server_job_id <= 0 then
		server_job_id = nil
		server_starting = false
		vim.notify("Failed to start opencode server.", vim.log.levels.ERROR)
		return false
	end

	vim.defer_fn(function()
		server_starting = false
		if is_server_ready() then
			vim.notify("opencode server ready.", vim.log.levels.INFO)
		end
	end, 1200)

	return false
end

local function fill_commit_editmsg(buf, message)
	local lines = vim.split(message, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			vim.api.nvim_win_set_cursor(win, { 1, 0 })
			break
		end
	end

	vim.notify("Commit message filled — edit then :wq to commit.", vim.log.levels.INFO)
end

local function open_commit_float(message)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].filetype = "gitcommit"
	vim.bo[buf].modifiable = true

	local lines = vim.split(message, "\n", { plain = true })
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

		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end

		local tmpfile = vim.fn.tempname()
		vim.fn.writefile(vim.split(commit_msg, "\n", { plain = true }), tmpfile)

		vim.system({ "git", "commit", "-F", tmpfile }, { text = true }, function(result)
			vim.schedule(function()
				vim.fn.delete(tmpfile)

				local stdout = (result.stdout or ""):match("^%s*(.-)%s*$")
				local stderr = (result.stderr or ""):match("^%s*(.-)%s*$")

				if result.code ~= 0 then
					vim.notify("Commit failed:\n" .. (stderr ~= "" and stderr or stdout), vim.log.levels.ERROR)
				else
					vim.notify(stdout ~= "" and stdout or "Commit created.", vim.log.levels.INFO)
				end
			end)
		end)
	end

	vim.keymap.set("n", "<C-s>", do_commit, { buffer = buf, noremap = true, silent = true, desc = "Confirm commit" })
	vim.keymap.set("i", "<C-s>", function()
		vim.cmd("stopinsert")
		do_commit()
	end, { buffer = buf, noremap = true, silent = true, desc = "Confirm commit" })
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		vim.notify("Commit cancelled.", vim.log.levels.INFO)
	end, { buffer = buf, noremap = true, silent = true, desc = "Cancel commit" })
end

local function commit()
	local staged_files = vim.fn.systemlist("git diff --staged --name-only")
	if #staged_files == 0 then
		vim.notify("No staged files to commit.", vim.log.levels.WARN)
		return
	end

	if not is_server_ready() then
		ensure_server()
		vim.notify("Starting opencode server, run the command again in a moment.", vim.log.levels.INFO)
		return
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local in_commit_buf = is_commit_editmsg(current_buf)

	vim.notify("Generating commit message… with the model " .. model, vim.log.levels.INFO)

	vim.system({ "git", "diff", "--staged" }, { text = true }, function(diff_result)
		vim.schedule(function()
			local start = vim.loop.hrtime()
			if diff_result.code ~= 0 or not diff_result.stdout or diff_result.stdout == "" then
				local err = (diff_result.stderr or ""):match("^%s*(.-)%s*$")
				vim.notify("Failed to get staged diff." .. (err ~= "" and ("\n" .. err) or ""), vim.log.levels.ERROR)
				return
			end

			local diff = diff_result.stdout
			local prompt = preprompt .. "\n\n" .. diff

			vim.system({
				"opencode",
				"run",
				"--attach",
				opencode_server_url,
				"-m",
				model,
				prompt,
			}, {
				text = true,
			}, function(result)
				vim.schedule(function()
					if result.code ~= 0 then
						local err = (result.stderr or ""):match("^%s*(.-)%s*$")
						if err:match("ECONNREFUSED") or err:match("connect") then
							vim.notify(
								"Could not reach opencode server at " .. opencode_server_url,
								vim.log.levels.ERROR
							)
						else
							vim.notify(
								"opencode exited with code " .. result.code .. (err ~= "" and (": " .. err) or ""),
								vim.log.levels.ERROR
							)
						end
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
					local elapsed_sec = (vim.loop.hrtime() - start) / 1e9

					vim.notify(string.format("Commit message generated in %.2f ms", elapsed_sec), vim.log.levels.INFO)
				end)
			end)
		end)
	end)
end

vim.api.nvim_create_user_command("Commiter", commit, {})

vim.keymap.set("n", "<leader>ai", "<cmd>Commiter<CR>", {
	noremap = true,
	silent = true,
	desc = "AI commit message",
})

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
	pattern = "COMMIT_EDITMSG",
	callback = function()
		pcall(ensure_server)
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		if server_job_id and server_job_id > 0 then
			pcall(vim.fn.jobstop, server_job_id)
		end
	end,
})

return {
	strip_ansi = strip_ansi,
	is_commit_editmsg = is_commit_editmsg,
	fill_commit_editmsg = fill_commit_editmsg,
	open_commit_float = open_commit_float,
	ensure_server = ensure_server,
}
