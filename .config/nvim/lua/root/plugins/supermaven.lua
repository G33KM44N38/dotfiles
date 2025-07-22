local workspace_path = "/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/"

return {
	"supermaven-inc/supermaven-nvim",
	config = function()
		require("supermaven-nvim").setup({
			keymaps = {
				accept_suggestion = "<C-y>",
				clear_suggestion = "<C-c>",
				accept_word = "<C-j>",
			},
		})

		-- Function to check if current buffer is in the workspace
		local function is_in_workspace()
			local bufname = vim.api.nvim_buf_get_name(0)
			return string.match(bufname, "^" .. workspace_path:gsub("([^%w])", "%%%1"))
		end

		-- Stop Supermaven when entering files in the workspace
		vim.api.nvim_create_autocmd("BufEnter", {
			callback = function()
				if is_in_workspace() then
					vim.cmd("silent! SupermavenStop")
				else
					vim.cmd("silent! SupermavenStart")
				end
			end,
		})

		-- Also check on file type changes (for good measure)
		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				if is_in_workspace() then
					vim.cmd("silent! SupermavenStop")
				end
			end,
		})
	end,
}
