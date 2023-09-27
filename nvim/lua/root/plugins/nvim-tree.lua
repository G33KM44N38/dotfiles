return {
	"nvim-tree/nvim-tree.lua",
	dependencies = {
		"nvim-tree/nvim-web-devicons"
	},
	config = function()
		local nvimtree = require("nvim-tree")

		nvimtree.setup({})


		local keymap = vim.keymap
		keymap.set("n", "<C-p>", "<cmd>NvimTreeToggle<CR>")
		keymap.set("n", "<leader>f", "<cmd>NvimTreeFindFile<CR>")
	end
}
