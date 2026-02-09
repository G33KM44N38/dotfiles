local uv = vim.uv or vim.loop
local TMUX_REFRESH_DEBOUNCE_MS = 400
local LSP_RESTART_DEBOUNCE_MS = 1500
local last_tmux_refresh_ms = 0
local last_lsp_restart_ms = 0
local lsp_restart_nonce = 0

local function now_ms()
	if not uv or not uv.hrtime then
		return math.floor(os.clock() * 1000)
	end
	return math.floor(uv.hrtime() / 1000000)
end

local function shell_escape(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function run_async_shell(command)
	vim.fn.jobstart({ "/bin/sh", "-c", command }, { detach = true })
end

local function update_tmux_windows()
	local session_name = vim.fn.system("tmux display-message -p '#S'"):gsub("\n", "")
	if session_name == "" then
		return
	end

	local now = now_ms()
	if (now - last_tmux_refresh_ms) < TMUX_REFRESH_DEBOUNCE_MS then
		return
	end
	last_tmux_refresh_ms = now

	local session_target = shell_escape(session_name)
	local target2 = shell_escape(session_name .. ":2")
	local target3 = shell_escape(session_name .. ":3")
	local target4 = shell_escape(session_name .. ":4")
	local assistant_target = shell_escape(session_name .. ":assistant")
	local cleanup_script = shell_escape("/Users/boss/.dotfiles/bin/tmux-cleanup.sh")
	local cleanup_log = shell_escape("/tmp/tmux-cleanup.log")

	local tmux_refresh_cmd = table.concat({
		cleanup_script .. " window " .. session_target .. " 2 3 4 >/dev/null 2>>" .. cleanup_log .. " || true;",
		"tmux kill-window -t " .. target2 .. " >/dev/null 2>&1 || true;",
		"tmux kill-window -t " .. target3 .. " >/dev/null 2>&1 || true;",
		"tmux kill-window -t " .. target4 .. " >/dev/null 2>&1 || true;",
		"tmux new-window -t " .. session_target .. " -dn run >/dev/null 2>&1 || true;",
		"tmux new-window -t " .. session_target .. " -dn process >/dev/null 2>&1 || true;",
		"tmux new-window -t " .. session_target .. " -dn assistant >/dev/null 2>&1 || true;",
		"tmux send-keys -t " .. assistant_target .. " -R coding-assistant C-m >/dev/null 2>&1 || true",
	}, " ")

	-- Keep UI switch path fast; run one detached sequence to avoid cleanup/rebuild races.
	run_async_shell(tmux_refresh_cmd)
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
				vim.schedule(function()
					local ok_harpoon, harpoon = pcall(require, "harpoon")
					if ok_harpoon then
						local current_harpoon_key = harpoon.config.settings.key()
						harpoon.lists[current_harpoon_key] = nil
						harpoon.data = require("harpoon.data").Data:new(harpoon.config)
					end

					schedule_lsp_restart()
					update_tmux_windows()
					print("Switched to worktree: " .. metadata.path)
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
