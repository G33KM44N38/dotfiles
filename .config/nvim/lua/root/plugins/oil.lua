return {
	'stevearc/oil.nvim',
	dependencies = { { "echasnovski/mini.icons", opts = {} } },
	config = function()
		require("oil").setup()
		vim.keymap.set("n", "<leader>f", "<CMD>Oil<CR>", { desc = "Open parent directory" })
	end
}
