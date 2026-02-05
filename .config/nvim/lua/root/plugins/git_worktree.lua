local function update_tmux_windows()
	local session_name = vim.fn.system("tmux display-message -p '#S'"):gsub("\n", "")

	os.execute("/Users/boss/.dotfiles/bin/tmux-cleanup.sh window " .. session_name .. " 2 2>/dev/null || true")
	os.execute("/Users/boss/.dotfiles/bin/tmux-cleanup.sh window " .. session_name .. " 3 2>/dev/null || true")
	os.execute("/Users/boss/.dotfiles/bin/tmux-cleanup.sh window " .. session_name .. " 4 2>/dev/null || true")

	os.execute("tmux kill-window -t 2 2>/dev/null || true")
	os.execute("tmux kill-window -t 3 2>/dev/null || true")
	os.execute("tmux kill-window -t 4 2>/dev/null || true")

	os.execute("tmux new-window -dn run")
	os.execute("tmux new-window -dn process")
	os.execute("tmux new-window -dn assistant")
	os.execute('tmux send-keys -t assistant -R "coding-assistant" C-m')
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
				vim.defer_fn(function()
					local harpoon_logger = require("harpoon.logger")
					harpoon_logger:log("git-worktree.nvim: on_tree_change - Inside defer_fn")
					harpoon_logger:log("git-worktree.nvim: vim.loop.cwd() is:", vim.loop.cwd())
					harpoon_logger:log(
						"git-worktree.nvim: git_worktree.get_current_worktree_path() is:",
						Worktree.get_current_worktree_path()
					)

					local harpoon = require("harpoon")

					-- Get the key that Harpoon will use for the current worktree
					local current_harpoon_key = harpoon.config.settings.key()

					-- IMPORTANT: Clear Harpoon's internal list cache for this key
					-- This forces Harpoon to re-read from disk the next time harpoon:list() is called
					harpoon.lists[current_harpoon_key] = nil

					-- Re-initialize Harpoon's data to force it to reload marks
					harpoon.data = require("harpoon.data").Data:new(harpoon.config)

					harpoon_logger:log(
						"git-worktree.nvim: Harpoon data reloaded and list cache cleared for key:",
						current_harpoon_key
					)

					-- Check if we're in a Neovim window/buffer context
					local buf = vim.api.nvim_get_current_buf()
					if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype ~= "nofile" then
						-- Additional check to ensure we have active LSP clients
						local clients = vim.lsp.get_clients()
						if #clients > 0 then
							vim.cmd("LspRestart")
						end
					end
					
					-- Update tmux windows AFTER all worktree switch operations are complete
					update_tmux_windows()
					print("Switched to worktree: " .. metadata.path)
				end, 500)
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
