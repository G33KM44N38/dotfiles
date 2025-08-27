return {
	"topaxi/pipeline.nvim",
	keys = {
		{ "<leader>gh", "<cmd>Pipeline<cr>", desc = "Open GitHub Actions" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
	},
	-- opts = {
	-- 	refresh_interval = 10, -- for example
	-- },
	config = function(_, opts)
		require("pipeline").setup(opts)
	end,
}
