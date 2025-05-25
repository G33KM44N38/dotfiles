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

		-- Stop Supermaven in markdown buffers
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "markdown",
			callback = function()
				vim.cmd("silent! SupermavenStop")
			end,
		})

		-- Start Supermaven in other filetypes
		vim.api.nvim_create_autocmd("BufEnter", {
			callback = function()
				local ft = vim.bo.filetype
				if ft ~= "markdown" then
					vim.cmd("silent! SupermavenStart")
				end
			end,
		})
	end,
}
