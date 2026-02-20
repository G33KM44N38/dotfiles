local uv = vim.uv or vim.loop
local LSP_RESTART_DEBOUNCE_MS = 1500
local SWITCH_UI_MIN_VISIBLE_MS = 180
local last_lsp_restart_ms = 0
local lsp_restart_nonce = 0
local switch_ui_nonce = 0
local switch_ui_started_at_ms = 0
local pending_tmux_refresh_path = nil
local tmux_refresh_running = false

local function now_ms()
	if not uv or not uv.hrtime then
		return math.floor(os.clock() * 1000)
	end
	return math.floor(uv.hrtime() / 1000000)
end

local function shell_escape(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function run_async_shell(command, on_exit)
	local job_id = vim.fn.jobstart({ "/bin/sh", "-c", command }, {
		detach = false,
		on_exit = function(_, exit_code, _)
			if on_exit then
				vim.schedule(function()
					on_exit(exit_code)
				end)
			end
		end,
	})

	if job_id <= 0 and on_exit then
		on_exit(job_id)
	end
end

local function worktree_label(path)
	if type(path) ~= "string" or path == "" then
		return "<unknown>"
	end
	if vim.fs and vim.fs.basename then
		return vim.fs.basename(path)
	end
	return path:match("([^/]+)$") or path
end

local function begin_optimistic_switch(path)
	switch_ui_nonce = switch_ui_nonce + 1
	switch_ui_started_at_ms = now_ms()

	local label = worktree_label(path)
	vim.g.git_worktree_switch_inflight = 1
	vim.g.git_worktree_switch_target = path or ""
	pcall(vim.cmd, "redrawstatus")
	vim.api.nvim_echo({ { "Switching worktree -> " .. label .. " ...", "ModeMsg" } }, false, {})
	return switch_ui_nonce
end

local function finish_optimistic_switch(token, path, ok, err)
	local elapsed = now_ms() - switch_ui_started_at_ms
	local remaining = math.max(0, SWITCH_UI_MIN_VISIBLE_MS - elapsed)

	vim.defer_fn(function()
		if token ~= switch_ui_nonce then
			return
		end
		vim.g.git_worktree_switch_inflight = 0
		vim.g.git_worktree_switch_target = ""
		pcall(vim.cmd, "redrawstatus")

		local label = worktree_label(path)
		if ok then
			vim.api.nvim_echo({ { "Switched to worktree: " .. label, "MoreMsg" } }, false, {})
		else
			local message = tostring(err or "unknown error")
			vim.api.nvim_echo({ { "Worktree switch post-hooks failed: " .. message, "ErrorMsg" } }, true, {})
		end
	end, remaining)
end

local function build_tmux_refresh_command(session_name, target_path)
	local layout_script = shell_escape("/Users/boss/.dotfiles/bin/tmux_layout.sh")
	local session_target = shell_escape(session_name)
	local target_path_escaped = shell_escape(target_path)

	return layout_script .. " reset " .. session_target .. " " .. target_path_escaped
end

local function with_worktree_ready(path, cb)
	if type(path) ~= "string" or path == "" then
		cb(false)
		return
	end

	if vim.system then
		vim.system({ "git", "-C", path, "rev-parse", "--is-inside-work-tree" }, { text = true }, function(obj)
			local ok = obj.code == 0 and type(obj.stdout) == "string" and obj.stdout:find("true", 1, true) ~= nil
			vim.schedule(function()
				cb(ok)
			end)
		end)
		return
	end

	local out = vim.fn.system({ "git", "-C", path, "rev-parse", "--is-inside-work-tree" })
	local ok = vim.v.shell_error == 0 and type(out) == "string" and out:find("true", 1, true) ~= nil
	cb(ok)
end

local function drain_tmux_refresh_queue()
	if tmux_refresh_running then
		return
	end

	local target_path = pending_tmux_refresh_path
	pending_tmux_refresh_path = nil

	if type(target_path) ~= "string" or target_path == "" then
		return
	end

	local session_name = vim.fn.system("tmux display-message -p '#S'"):gsub("\n", "")
	if vim.v.shell_error ~= 0 or session_name == "" then
		return
	end

	tmux_refresh_running = true
	with_worktree_ready(target_path, function(ready)
		if not ready then
			tmux_refresh_running = false
			if pending_tmux_refresh_path ~= nil then
				drain_tmux_refresh_queue()
			end
			return
		end

		run_async_shell(build_tmux_refresh_command(session_name, target_path), function()
			tmux_refresh_running = false
			if pending_tmux_refresh_path ~= nil then
				drain_tmux_refresh_queue()
			end
		end)
	end)
end

local function update_tmux_windows(worktree_path)
	local target_path = worktree_path
	if type(target_path) ~= "string" or target_path == "" then
		target_path = vim.fn.getcwd()
	end
	target_path = vim.fn.fnamemodify(target_path, ":p")

	pending_tmux_refresh_path = target_path
	if tmux_refresh_running then
		return
	end

	drain_tmux_refresh_queue()
end

local function schedule_lsp_restart()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype == "nofile" then
		return
	end

	local clients = vim.lsp.get_clients()
	if #clients == 0 then
		return
	end

	local now = now_ms()
	if (now - last_lsp_restart_ms) < LSP_RESTART_DEBOUNCE_MS then
		return
	end
	last_lsp_restart_ms = now

	lsp_restart_nonce = lsp_restart_nonce + 1
	local current_nonce = lsp_restart_nonce

	vim.defer_fn(function()
		if current_nonce ~= lsp_restart_nonce then
			return
		end
		pcall(vim.cmd, "silent! LspRestart")
	end, 120)
end

-- Module pour exposer les fonctions personnalisées
local M = {}

-- Wrapper pour créer des worktrees en enlevant automatiquement le préfixe origin/
function M.create_worktree_wrapper()
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local git_worktree = require("git-worktree")

	-- Vérifier et configurer le fetch refspec pour bare repos (fix pour l'erreur "origin/X does not exist")
	local function ensure_fetch_refspec()
		local handle = io.popen("git config --get remote.origin.fetch 2>/dev/null")
		local result = handle:read("*a")
		handle:close()

		if result == "" or not result:match("refs/remotes/origin") then
			print("Configuring fetch refspec for bare repo...")
			os.execute('git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"')
			os.execute("git fetch --all")
		end
	end

	ensure_fetch_refspec()

	-- Ensure remote branches are fetched so they appear in the picker
	vim.fn.system("git fetch --all 2>/dev/null")

	-- Utilise le picker git_branches de Telescope
	require("telescope.builtin").git_branches({
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				local prompt_text = action_state.get_current_line()
				actions.close(prompt_bufnr)

				local branch
				local is_new_branch = false

				if selection then
					-- Existing branch selected
					branch = selection.value
				elseif prompt_text and prompt_text ~= "" then
					-- New branch name entered
					branch = prompt_text
					is_new_branch = true
				else
					return -- Nothing selected or typed
				end

				if is_new_branch then
					-- For new branches, ask for base branch via another Telescope picker
					vim.schedule(function()
						require("telescope.builtin").git_branches({
							prompt_title = "Select base branch for: " .. branch,
							attach_mappings = function(base_prompt_bufnr, _)
								actions.select_default:replace(function()
									local base_selection = action_state.get_selected_entry()
									actions.close(base_prompt_bufnr)

									if base_selection then
										local base_branch = base_selection.value:gsub("^origin/", "")

										-- Ask for path
										local path = vim.fn.input("Path to subtree > ")
										if path == "" then
											path = branch
										end

										-- Pre-create the branch from the selected base
										-- This is necessary because git-worktree plugin only creates from HEAD
										local create_branch_cmd = string.format("git branch %s %s", branch, base_branch)
										vim.fn.system(create_branch_cmd)

										-- Now create the worktree - plugin will find the existing branch
										git_worktree.create_worktree(path, branch, "origin")
									end
								end)
								return true
							end,
						})
					end)
				else
					-- Existing branch flow - handle both local and remote branches
					local path = vim.fn.input("Path to subtree > ")
					if path == "" then
						path = branch
					end

					-- Check if selected branch is remote (origin/*)
					local is_remote = branch:match("^origin/")
					if is_remote then
						-- For remote branches: create local tracking branch first, then worktree
						local clean_branch = branch:gsub("^origin/", "")
						vim.fn.system("git branch --track " .. clean_branch .. " " .. branch)
						git_worktree.create_worktree(path, clean_branch, "origin")
					else
						-- Local branch: use as-is
						path = path:gsub("^origin/", "")
						git_worktree.create_worktree(path, branch, "origin")
					end
				end
			end)
			return true
		end,
	})
end

-- Retourner la configuration du plugin ET le module avec les fonctions
_G.git_worktree_module = M

return {
	-- Fork corrigé sur GitHub - Fix du bug "receives from more than one src"
	"G33KM44N38/git-worktree.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },

	config = function()
		local Worktree = require("git-worktree")

		Worktree.setup({
			autopush = true, -- Réactivé grâce au fix local du bug
		})

		Worktree.on_tree_change(function(op, metadata)
			if op == Worktree.Operations.Switch then
				local switch_token = begin_optimistic_switch(metadata and metadata.path or "")
				vim.schedule(function()
					local ok, err = pcall(function()
						local ok_harpoon, harpoon = pcall(require, "harpoon")
						if ok_harpoon then
							local current_harpoon_key = harpoon.config.settings.key()
							harpoon.lists[current_harpoon_key] = nil
							harpoon.data = require("harpoon.data").Data:new(harpoon.config)
						end

						schedule_lsp_restart()
						local current_worktree_path = Worktree.get_current_worktree_path()
						if type(current_worktree_path) ~= "string" or current_worktree_path == "" then
							current_worktree_path = vim.fn.getcwd()
						end
						update_tmux_windows(current_worktree_path)
					end)
					finish_optimistic_switch(switch_token, metadata and metadata.path or "", ok, err)
				end)
			end
		end)

		vim.api.nvim_set_keymap(
			"n",
			"<leader>ws",
			":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>",
			Opts
		)
		vim.api.nvim_set_keymap("n", "<leader>wc", ":lua _G.git_worktree_module.create_worktree_wrapper()<CR>", Opts)
	end,
}
