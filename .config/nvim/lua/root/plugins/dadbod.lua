return {
	"tpope/vim-dadbod",
	"kristijanhusak/vim-dadbod-completion",
	{
		"kristijanhusak/vim-dadbod-ui",
		cmd = { "DBUIToggle", "DBUI" },
		dependencies = { "tpope/vim-dadbod" },
		init = function()
			local username = os.getenv("BABACOIFFURE_DB_USERNAME")
			local password = os.getenv("BABACOIFFURE_DB_PASSWORD")

			-- db.providerschedules.getIndexes()
			--
			-- db.providerschedules.dropIndex("timePeriods.timePeriod_1")

			vim.keymap.set("n", "<leader>DB", "<cmd>DBUIToggle<CR>", {})

			local function urlencode(str)
				if not str then
					return ""
				end
				return string.gsub(str, "([^%w%-%.%_%~])", function(c)
					return string.format("%%%02X", string.byte(c))
				end)
			end

			vim.g.dbs = {
				{
					name = "babacoiffure_local",
					url = "mongodb://localhost:27017/test",
				},
			}

			if username and password then
				table.insert(vim.g.dbs, {
					name = "babacoiffure_preprod",
					url = string.format(
						"mongodb+srv://%s:%s@cluster0.k2k9ux7.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0",
						urlencode(username),
						urlencode(password)
					),
				})
				table.insert(vim.g.dbs, {
					name = "babacoiffure_production",
					url = string.format(
						"mongodb+srv://%s:%s@cluster0.k2k9ux7.mongodb.net/production?retryWrites=true&w=majority&appName=Cluster0",
						urlencode(username),
						urlencode(password)
					),
				})
			end
		end,
	},
}
