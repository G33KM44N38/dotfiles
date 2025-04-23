local function update_tmux_windows()
	os.execute("tmux kill-window -t 2")
	os.execute("tmux kill-window -t 3")
	os.execute("tmux new-window -dn code")
	os.execute("tmux new-window -dn process")
end

return {
	"ThePrimeagen/git-worktree.nvim",
	dependencies = {
		"nvim-telescope/telescope.nvim",
		{
			'ThePrimeagen/harpoon',
			branch = 'harpoon2',
		}
	},

	config = function()
		local harpoon = require('harpoon')
		local Worktree = require("git-worktree")

		Worktree.setup({
			autopush = true,
		})


		Worktree.on_tree_change(function(op, metadata)
			if op == Worktree.Operations.Switch then
				vim.defer_fn(function()
					vim.api.nvim_command("LspRestart")
				end, 500)

				update_tmux_windows()


				print("Switched to worktree: " .. metadata.path)
			end
		end)

		-- vim.api.nvim_create_user_command("CreateGitWorktree", function()
		--   vim.ui.input({ prompt = "Path: " }, function(path)
		--     if not path then return end
		--     vim.ui.input({ prompt = "Branch: " }, function(branch)
		--       if not branch then return end
		--       Worktree.create_worktree(path, branch, branch)
		--     end)
		--   end)
		-- end, {})

		vim.api.nvim_set_keymap("n", "<leader>ws",
			":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", Opts)
		vim.api.nvim_set_keymap("n", "<leader>wc",
			":lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>", Opts)
		vim.api.nvim_set_keymap("n", "<leader>wt",
			":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", Opts)
	end
}
