return {
	"roobert/tailwindcss-colorizer-cmp.nvim",
	-- optionally, override the default options:
	build = function()
		require("tailwindcss-colorizer-cmp").setup({
			color_square_width = 2,
		})
	end

}
