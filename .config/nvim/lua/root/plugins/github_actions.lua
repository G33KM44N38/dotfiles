return {
	"topaxi/pipeline.nvim",
	cmd = "GhActions",
	keys = {
		{ "<leader>gh", "<cmd>Pipeline<cr>", desc = "Open Github Actions" },
	},
	-- optional, you can also install and use `yq` instead.
	-- build = 'make',
	dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
	opts = {},
	config = function(_, opts)
		require("gh-actions").setup(opts)
	end,
}
