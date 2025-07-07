local function update_tmux_windows()
	os.execute("tmux kill-window -t 2")
	os.execute("tmux kill-window -t 3")
	os.execute("tmux new-window -dn run")
	os.execute("tmux new-window -dn process")
end

return {
	"ThePrimeagen/git-worktree.nvim",

	config = function()
		local Worktree = require("git-worktree")

		Worktree.setup({
			autopush = true,
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
			":lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>",
			Opts
		)
	end,
}
