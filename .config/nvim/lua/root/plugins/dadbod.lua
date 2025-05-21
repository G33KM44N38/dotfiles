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
			local instanceId = os.getenv("BABACOIFFURE_DB_INSTANCEID")
			local region = os.getenv("BABACOIFFURE_DB_REGION")

			-- db.providerschedules.getIndexes()
			--
			-- db.providerschedules.dropIndex("timePeriods.timePeriod_1")

			vim.keymap.set("n", "<leader>DB", "<cmd>DBUIToggle<CR>", {})

			local function log_error(msg)
				vim.notify(msg, vim.log.levels.ERROR)
			end

			if not username then
				log_error("Username is missing!")
			end
			if not password then
				log_error("Password is missing!")
			end

			local function urlencode(str)
				if not str then
					return ""
				end
				return string.gsub(str, "([^%w%-%.%_%~])", function(c)
					return string.format("%%%02X", string.byte(c))
				end)
			end

			local babacoiffure_preprod = string.format(
				"mongodb+srv://%s:%s@cluster0.k2k9ux7.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0",
				urlencode(username),
				urlencode(password)
			)

			local babacoiffure_production = string.format(
				"mongodb+srv://%s:%s@cluster0.k2k9ux7.mongodb.net/production?retryWrites=true&w=majority&appName=Cluster0",
				urlencode(username),
				urlencode(password)
			)

			vim.g.dbs = {
				{
					name = "babacoiffure_preprod",
					url = babacoiffure_preprod,
				},
				{
					name = "babacoiffure_production",
					url = babacoiffure_production,
				},
				{
					name = "babacoiffure_local",
					url = "mongodb://localhost:27017/my_local_db",
				},
			}
		end,
	},
}
