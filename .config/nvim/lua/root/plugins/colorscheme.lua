return {
	{
		"projekt0n/github-nvim-theme",
		name = "github-theme",
		lazy = false,
		priority = 999,
		opts = {
			options = {
				transparent = false,
				terminal_colors = true,
			},
		},
	},
	{
		"bluz71/vim-nightfly-guicolors",
		lazy = false,
		priority = 1000,
		config = function()
			vim.g.nightflyTransparent = true
			vim.g.nightflyVirtualTextColor = true

			local themes = {
				dark = {
					background = "dark",
					colorscheme = "nightfly",
					line_nr = "white",
				},
				light = {
					background = "light",
					colorscheme = "github_light_high_contrast",
					line_nr = "#24292f",
				},
			}

			local function apply_theme(mode)
				local theme = themes[mode] or themes.dark
				vim.o.background = theme.background
				vim.cmd.colorscheme(theme.colorscheme)
				vim.api.nvim_set_hl(0, "LineNr", { fg = theme.line_nr })
				vim.g.root_theme_mode = mode
			end

			local function preferred_theme_mode()
				local env_mode = vim.env.NVIM_THEME or vim.env.THEME_MODE
				if env_mode == "light" or env_mode == "dark" then
					return env_mode
				end

				return "dark"
			end

			vim.api.nvim_create_user_command("ThemeLight", function()
				apply_theme("light")
			end, {})

			vim.api.nvim_create_user_command("ThemeDark", function()
				apply_theme("dark")
			end, {})

			vim.api.nvim_create_user_command("ThemeToggle", function()
				apply_theme(vim.g.root_theme_mode == "light" and "dark" or "light")
			end, {})

			apply_theme(preferred_theme_mode())
		end,
	},
}
