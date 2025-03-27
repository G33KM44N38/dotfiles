return {
	"ThePrimeagen/git-worktree.nvim",
	config = function()
		if vim.g.vscode then
			vim.keymap.set("n", "<leader>ws", function()
				require('vscode').action('git-worktree.list')
			end)
			vim.keymap.set("n", "<leader>wc", function()
				require('vscode').action('git-worktree.add')
			end)
			vim.keymap.set("n", "<leader>wd", function()
				require('vscode').action('git-worktree.remove')
			end)
		else
			require("telescope").load_extension("git_worktree")
			local Worktree = require("git-worktree")
			local opts = { noremap = true, silent = true }

			-- Function to update tmux windows in the current client
			local function update_tmux_windows()
				os.execute("tmux kill-window -t 2")
				os.execute("tmux kill-window -t 3")
				os.execute("tmux new-window")
				os.execute("tmux new-window")
				os.execute("tmux select-window -t 1")
			end

			vim.api.nvim_set_keymap("n", "<leader>ws",
				":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", opts)
			vim.api.nvim_set_keymap("n", "<leader>wc",
				":lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>", opts)
			vim.api.nvim_set_keymap("n", "<leader>wt",
				":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", opts)

			Worktree.on_tree_change(function(op, metadata)
				if op == Worktree.Operations.Switch then
					print("Switched from " .. metadata.prev_path .. " to " .. metadata.path)

					-- Restart LSP
					vim.api.nvim_command("LspRestart")

					-- Update tmux windows in the current client to the new worktree path
					update_tmux_windows()
				end
			end)
		end
	end
}
