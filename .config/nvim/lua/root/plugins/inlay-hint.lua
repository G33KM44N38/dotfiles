return {
	"MysticalDevil/inlay-hints.nvim",
	event = "LspAttach",
	dependencies = { "neovim/nvim-lspconfig" },
	opts = {},
	config = function(_, opts)
		require("inlay-hints").setup(opts)
	end,
}
