return {
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
					colorscheme = "nightfly",
					name = "nightfly-light",
					line_nr = "#334155",
					overrides = {
						Normal = { fg = "#111827", bg = "#f5f7fb" },
						NormalNC = { fg = "#1f2937", bg = "#eef3f9" },
						Comment = { fg = "#334155", italic = true },
						Constant = { fg = "#b45309" },
						Function = { fg = "#0057d8", bold = true },
						Identifier = { fg = "#111827" },
						Keyword = { fg = "#5b21b6", bold = true },
						Number = { fg = "#b45309" },
						Operator = { fg = "#1f2937" },
						Statement = { fg = "#5b21b6", bold = true },
						String = { fg = "#8a3a00" },
						Type = { fg = "#00796b", bold = true },
						CursorLine = { bg = "#dfeaf7" },
						Visual = { bg = "#b9d0ee" },
						Search = { fg = "#111827", bg = "#ffd166" },
						IncSearch = { fg = "#111827", bg = "#ffb703" },
						LineNr = { fg = "#475569" },
						CursorLineNr = { fg = "#0057d8", bold = true },
						SignColumn = { bg = "#f5f7fb" },
						FoldColumn = { fg = "#475569", bg = "#f5f7fb" },
						ColorColumn = { bg = "#dfeaf7" },
						Pmenu = { fg = "#111827", bg = "#dfeaf7" },
						PmenuSel = { fg = "#ffffff", bg = "#0057d8" },
						FloatBorder = { fg = "#1f2937", bg = "#f5f7fb" },
						NormalFloat = { fg = "#111827", bg = "#f5f7fb" },
						["@constant"] = { fg = "#b45309" },
						["@constant.lua"] = { fg = "#b45309" },
						["@function"] = { fg = "#0057d8", bold = true },
						["@function.call"] = { fg = "#0057d8", bold = true },
						["@function.call.lua"] = { fg = "#0057d8", bold = true },
						["@function.lua"] = { fg = "#0057d8", bold = true },
						["@function.method"] = { fg = "#0057d8", bold = true },
						["@function.method.call"] = { fg = "#0057d8", bold = true },
						["@keyword"] = { fg = "#5b21b6", bold = true },
						["@keyword.lua"] = { fg = "#5b21b6", bold = true },
						["@operator"] = { fg = "#1f2937" },
						["@property"] = { fg = "#9f1239" },
						["@property.lua"] = { fg = "#9f1239" },
						["@punctuation"] = { fg = "#1f2937" },
						["@string"] = { fg = "#8a3a00" },
						["@string.documentation"] = { fg = "#8a3a00" },
						["@string.escape"] = { fg = "#b45309", bold = true },
						["@string.lua"] = { fg = "#8a3a00" },
						["@string.regex"] = { fg = "#8a3a00" },
						["@string.special"] = { fg = "#b45309", bold = true },
						["@type"] = { fg = "#00796b", bold = true },
						["@type.lua"] = { fg = "#00796b", bold = true },
						["@variable"] = { fg = "#111827" },
						["@variable.lua"] = { fg = "#111827" },
						["@variable.member"] = { fg = "#9f1239" },
						["@variable.parameter"] = { fg = "#9f1239" },
						["@lsp.type.function"] = { fg = "#0057d8", bold = true },
						["@lsp.type.method"] = { fg = "#0057d8", bold = true },
						["@lsp.type.parameter"] = { fg = "#9f1239" },
						["@lsp.type.property"] = { fg = "#9f1239" },
						["@lsp.type.string"] = { fg = "#8a3a00" },
						["@lsp.type.variable"] = { fg = "#111827" },
					},
				},
			}

			local function apply_theme(mode)
				local theme = themes[mode] or themes.dark
				vim.o.background = theme.background
				vim.cmd.colorscheme(theme.colorscheme)
				vim.o.background = theme.background
				vim.api.nvim_set_hl(0, "LineNr", { fg = theme.line_nr })
				for group, attrs in pairs(theme.overrides or {}) do
					vim.api.nvim_set_hl(0, group, attrs)
				end
				vim.g.colors_name = theme.name or theme.colorscheme
				vim.g.root_theme_mode = mode
			end

			local function system_theme_mode()
				if vim.fn.has("macunix") == 1 then
					local apple_interface_style = vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyle" })
					if vim.v.shell_error == 0 and apple_interface_style:match("Dark") then
						return "dark"
					end

					return "light"
				end

				return "dark"
			end

			local function preferred_theme_mode()
				local env_mode = vim.env.NVIM_THEME or vim.env.THEME_MODE
				if env_mode == "light" or env_mode == "dark" then
					return env_mode
				end

				return system_theme_mode()
			end

			local function sync_system_theme()
				if vim.env.NVIM_THEME == "light" or vim.env.NVIM_THEME == "dark" then
					return
				end
				if vim.env.THEME_MODE == "light" or vim.env.THEME_MODE == "dark" then
					return
				end

				local mode = system_theme_mode()
				if mode ~= vim.g.root_theme_mode then
					apply_theme(mode)
				end
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

			vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
				group = vim.api.nvim_create_augroup("root-system-theme", { clear = true }),
				callback = sync_system_theme,
			})

			if vim.fn.has("macunix") == 1 then
				vim.fn.timer_start(5000, function()
					vim.schedule(sync_system_theme)
				end, { ["repeat"] = -1 })
			end
		end,
	},
}
