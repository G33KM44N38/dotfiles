return {
	"topaxi/pipeline.nvim",
	cmd = "Pipeline",
	keys = {
		{ "<leader>gh", "<cmd>Pipeline<cr>", desc = "Open Github Actions" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
	},
	opts = {}, -- Ajoute ici les options si besoin
	config = function(_, opts)
		require("pipeline").setup(opts)
	end,
}
