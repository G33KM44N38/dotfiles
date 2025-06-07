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
