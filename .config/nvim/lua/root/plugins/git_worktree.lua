local function update_tmux_windows()
	os.execute("tmux kill-window -t 2")
	os.execute("tmux kill-window -t 3")
	os.execute("tmux kill-window -t 4")
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

	-- Utilise le picker git_branches de Telescope
	require("telescope.builtin").git_branches({
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)

				if selection then
					local branch = selection.value

					-- Demander le chemin personnalisé
					local path = vim.fn.input("Path to subtree > ")

					-- Si aucun chemin n'est fourni, utiliser le nom de la branche
					if path == "" then
						path = branch
					end

					-- Enlever uniquement le préfixe origin/ du chemin (garder feature/, bugfix/, etc.)
					path = path:gsub("^origin/", "")

					-- Nettoyer aussi le nom de la branche pour éviter le double origin/
					-- Si la branche est origin/feature/X, on veut juste feature/X
					local clean_branch = branch:gsub("^origin/", "")

					-- Créer le worktree avec le chemin et la branche nettoyés
					git_worktree.create_worktree(path, clean_branch)
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
				end, 500)
				update_tmux_windows()
				print("Switched to worktree: " .. metadata.path)
			end
		end)

		vim.api.nvim_set_keymap(
			"n",
			"<leader>ws",
			":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>",
			Opts
		)
		vim.api.nvim_set_keymap(
			"n",
			"<leader>wc",
			":lua _G.git_worktree_module.create_worktree_wrapper()<CR>",
			Opts
		)
	end,
}
