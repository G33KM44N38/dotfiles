local username = "Re0A4ua8hc"
local password = "*?u6^IY8#OrU$d:[oKb?"
local instanceId = "46fcc609-ed63-45b8-a012-f0b149651b14"
local region = "fr-par"

return {
	'tpope/vim-dadbod',
	'kristijanhusak/vim-dadbod-completion',
	{
		'kristijanhusak/vim-dadbod-ui',
		lazy = true,
		cmd = { 'DBUIToggle', 'DBUI' },
		dependencies = { 'tpope/vim-dadbod' },
		config = function()
			local Opts = { noremap = true, silent = true }
			vim.api.nvim_set_keymap("n", "<leader>DB", "<cmd>DBUIToggle<CR>", Opts)

			local function urlencode(str)
				if str then
					str = string.gsub(str, "\n", "\r\n")
					str = string.gsub(str, "([^%w%-%.%_%~])", function(c)
						return string.format("%%%02X", string.byte(c))
					end)
					str = string.gsub(str, " ", " ")
				end
				return str
			end

			-- Debugging variables
			vim.notify("Setting up DB config...")

			if not username then
				vim.notify("Warning: 'username' is nil")
			end
			if not password then
				vim.notify("Warning: 'password' is nil")
			end
			if not instanceId then
				vim.notify("Warning: 'instanceId' is nil")
			end
			if not region then
				vim.notify("Warning: 'region' is nil")
			end

			local encoded_password = urlencode(password or "")
			local db_url = 'mongodb://' ..
			    (username or "user") ..
			    ':' ..
			    encoded_password ..
			    '@' .. (instanceId or "instance") .. '.mgdb.' .. (region or "region") .. '.scw.cloud?tls=false'

			vim.notify("Generated DB URL: " .. db_url)

			vim.g.dbs = {
				{
					name = 'babacoiffure_preprod',
					url = db_url,
				},
			}
		end,
	},
}
