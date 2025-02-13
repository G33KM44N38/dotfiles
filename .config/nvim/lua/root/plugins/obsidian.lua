-- Function to edit frontmatter values
local function edit_frontmatter(key, new_value)
	-- Get all lines in the current buffer
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local start_index = nil
	local end_index = nil
	local found_first = false
	local key_line_index = nil

	-- Find the frontmatter boundaries
	for i, line in ipairs(lines) do
		if line:match("^%-%-%-") then
			if not found_first then
				start_index = i
				found_first = true
			else
				end_index = i
				break
			end
		elseif found_first then
			-- Look for the key while we're between the --- marks
			if line:match("^" .. key .. ":%s*.*$") then
				key_line_index = i
			end
		end
	end

	-- If we found the frontmatter and the key
	if start_index and end_index and key_line_index then
		-- Create the new line with the updated value
		local new_line = string.format("%s: %s", key, new_value)
		-- Replace the line in the buffer
		vim.api.nvim_buf_set_lines(0, key_line_index - 1, key_line_index, false, { new_line })
		return true
	elseif start_index and end_index then
		-- If we found frontmatter but not the key, add it
		local new_line = string.format("%s: %s", key, new_value)
		vim.api.nvim_buf_set_lines(0, end_index - 1, end_index - 1, false, { new_line })
		return true
	end
	return false
end

-- New function to find previous existing daily note
local function find_previous_daily()
	local current_file = vim.fn.expand('%:t:r') -- Get current file name without extension
	local date_pattern = "(%d+)%-(%d+)%-(%d+)"
	local month, day, year = current_file:match(date_pattern)

	if month and day and year then
		local current_date = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })

		-- Start checking from yesterday, going backwards
		local i = 1
		while true do
			local prev_date = os.date("*t", current_date - (i * 86400)) -- 86400 seconds = 1 day
			local prev_file = string.format("%02d-%02d-%04d.md", prev_date.month, prev_date.day, prev_date.year)
			local daily_folder =
			"/Users/kylian/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/Daily/"
			local full_path = daily_folder .. prev_file

			-- Check if file exists
			local f = io.open(full_path, "r")
			if f then
				f:close()
				-- File exists, open it
				vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
				return true
			end

			-- Prevent infinite loop by checking a reasonable max (e.g., 1000 days)
			if i > 1000 then
				print("No previous daily notes found")
				return false
			end

			i = i + 1
		end
	else
		print("Current file is not a daily note")
		return false
	end
end

-- New function to find previous existing daily note
local function find_next_daily()
	local current_file = vim.fn.expand('%:t:r') -- Get current file name without extension
	local date_pattern = "(%d+)%-(%d+)%-(%d+)"
	local month, day, year = current_file:match(date_pattern)

	if month and day and year then
		local current_date = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })

		-- Start checking from yesterday, going backwards
		local i = 1
		while true do
			local prev_date = os.date("*t", current_date - (i * 86400)) -- 86400 seconds = 1 day
			local prev_file = string.format("%02d-%02d-%04d.md", prev_date.month, prev_date.day, prev_date.year)
			local daily_folder =
			"/Users/kylian/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/Daily/"
			local full_path = daily_folder .. prev_file

			-- Check if file exists
			local f = io.open(full_path, "r")
			if f then
				f:close()
				-- File exists, open it
				vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
				return true
			end

			-- Prevent infinite loop by checking a reasonable max (e.g., 1000 days)
			if i > 1000 then
				print("No previous daily notes found")
				return false
			end

			i = i + 1
		end
	else
		print("Current file is not a daily note")
		return false
	end
end


return {
	"epwalsh/obsidian.nvim",
	version = "*",
	lazy = true,
	ft = "markdown",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = {
		workspaces = {
			{
				name = "personal",
				path = "/Users/kylian/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/",
			},
		},
		date_format = "%m-%d-%Y",
		templates = {
			folder = "Templates",
			date_format = "%m-%d-%Y",
			time_format = "%H:%M",
		},
		disable_frontmatter = true,
		note_id_func = nil,
		daily_notes = {
			folder = "Daily/",
			date_format = "%m-%d-%Y",
			template = "Daily Template.md"
		},
		use_advanced_uri = true,
		mappings = {},
		attachments = {
			img_folder = "Attachments/",
			---@return string
			img_name_func = function()
				-- Prefix image names with timestamp.
				return string.format("%s-", os.time())
			end,
		},
	},
	config = function(_, opts)
		require("obsidian").setup(opts)

		-- Create command to edit frontmatter
		vim.api.nvim_create_user_command("ObsidianEditFrontmatter", function(args)
			if #args.fargs < 2 then
				print("Usage: ObsidianEditFrontmatter <key> <value>")
				return
			end
			local key = args.fargs[1]
			local value = table.concat({ select(2, unpack(args.fargs)) }, " ")
			if edit_frontmatter(key, value) then
				print(string.format("Updated frontmatter: %s = %s", key, value))
			else
				print("Failed to update frontmatter")
			end
		end, {
			nargs = "+",
			complete = function(ArgLead, CmdLine, CursorPos)
				-- Add common frontmatter keys for completion
				return { "tags", "alias", "date", "title", "status", "type" }
			end
		})


		-- Create command to find previous daily
		vim.api.nvim_create_user_command("ObsidianPreviousDaily", function()
			find_previous_daily()
		end, {})

		vim.api.nvim_create_user_command("ObsidianNextDaily", function()
			find_next_daily()
		end, {})

		-- FileType autocommand for markdown files
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "markdown",
			callback = function()
				vim.api.nvim_set_keymap("n", "<leader>dp", "<cmd>ObsidianPreviousDaily<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>dn", "<cmd>ObsidianNextDaily<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "gf", "<cmd>ObsidianFollowLink<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>dd", "<cmd>ObsidianToday<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>bl", "<cmd>ObsidianBacklinks<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>ot", "<cmd>ObsidianTags<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>of", "<cmd>ObsidianTags<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>nt", "<cmd>ObsidianNewFromTemplate<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>it", "<cmd>ObsidianTemplate<cr>",
					{ noremap = true, silent = true })

				-- New keymap for editing frontmatter
				vim.api.nvim_set_keymap("n", "<leader>ef", ":ObsidianEditFrontmatter ",
					{ noremap = true })
			end
		})
	end,
}
