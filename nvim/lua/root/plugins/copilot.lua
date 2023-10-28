return {
	"zbirenbaum/copilot.lua",
	-- "github/copilot.vim",
	config = function()
		require("copilot").setup({
			suggestion = { enabled = false },
			panel = { enabled = false },
		})
	end
}
