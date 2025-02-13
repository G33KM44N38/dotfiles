-- Function to extract frontmatter
local function extract_frontmatter()
	-- Get all lines in the current buffer
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local start_index = nil
	local end_index = nil
	local found_first = false

	-- Find the start and end indices of the --- blocks
	for i, line in ipairs(lines) do
		if line:match("^%-%-%-") then
			if not found_first then
				start_index = i
				found_first = true
			else
				end_index = i
				break
			end
		end
	end

	-- If we found both markers, extract and return the content
	if start_index and end_index then
		local content = table.concat(
			vim.api.nvim_buf_get_lines(0, start_index, end_index - 1, false),
			"\n"
		)
		return content
	end
	return nil
end

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

local function check_metadata()
	-- Extract the filename date
	local current_file = vim.fn.expand('%:t:r') -- Get current file name without extension
	local date_pattern = "(%d+)%-(%d+)%-(%d+)"
	local month, day, year = current_file:match(date_pattern)

	if not (month and day and year) then
		print("Current file is not a daily note")
		return false
	end

	-- Format the filename date as per the configured date format
	local filename_date = string.format("%02d-%02d-%04d", tonumber(month), tonumber(day), tonumber(year))

	-- Extract frontmatter
	local frontmatter = extract_frontmatter()
	if not frontmatter then
		print("No frontmatter found")
		return false
	end

	-- Check if date exists in frontmatter
	local frontmatter_date = frontmatter:match("created:%s*(.-)%s*$")

	-- Handle template placeholder
	if frontmatter_date and frontmatter_date:match("<%% tp%.date%.now%(%) %%>") then
		print("Replacing template placeholder with actual created")
		edit_frontmatter("created", filename_date)
		frontmatter_date = filename_date
	end

	if not frontmatter_date then
		edit_frontmatter("created", filename_date)
		return true
	end

	-- Compare dates
	if frontmatter_date ~= filename_date then
		print(string.format("Date mismatch! Filename: %s, Frontmatter: %s", filename_date, frontmatter_date))
		-- Update frontmatter to match filename
		edit_frontmatter("created", filename_date)
		return false
	end

	return true
end

local function import_todos_from_previous_daily()
	-- print("[DEBUG] Starting import_todos_from_previous_daily()")
	local current_file = vim.fn.expand('%:t:r') -- Get current file name without extension
	local date_pattern = "(%d+)%-(%d+)%-(%d+)"
	local month, day, year = current_file:match(date_pattern)

	-- print(string.format("[DEBUG] Current file: %s, Extracted date: %s-%s-%s", current_file, month, day, year))

	if not (month and day and year) then
		-- print("[DEBUG] Current file is not a daily note")
		return false
	end

	local current_date = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
	local daily_folder = "/Users/kylian/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/Daily/"

	-- print(string.format("[DEBUG] Current date: %s, Daily folder: %s", os.date("%Y-%m-%d", current_date), daily_folder))

	-- Find previous daily note
	local i = 1
	while true do
		local prev_date = os.date("*t", current_date - (i * 86400)) -- 86400 seconds = 1 day
		local prev_file = string.format("%02d-%02d-%04d.md", prev_date.month, prev_date.day, prev_date.year)
		local full_path = daily_folder .. prev_file

		-- print(string.format("[DEBUG] Checking previous daily note: %s", full_path))

		-- Check if file exists
		local f = io.open(full_path, "r")
		if f then
			f:close()

			-- print("[DEBUG] Previous daily note found")

			-- Read the previous daily note
			local content = {}
			for line in io.lines(full_path) do
				table.insert(content, line)
			end

			-- Find the TODOS section
			local todos = {}
			local in_todos_section = false
			for _, line in ipairs(content) do
				if line:match("^## TODOS") then
					in_todos_section = true
					-- print("[DEBUG] Found TODOS section")
				elseif in_todos_section and line:match("^##") then
					-- Stop when next section starts
					break
				elseif in_todos_section and line:match("%s*-%s*%[%s*%]") then
					-- Unchecked todo item
					table.insert(todos, line)
					-- print(string.format("[DEBUG] Found unchecked todo: %s", line))
				end
			end

			-- If todos found, add them to current file
			if #todos > 0 then
				-- print(string.format("[DEBUG] Found %d unchecked todos", #todos))

				-- Get current buffer
				local bufnr = vim.api.nvim_get_current_buf()

				-- Find the TODOS section in current file
				local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
				local todos_index = nil
				for i, line in ipairs(lines) do
					if line:match("^## TODOS") then
						todos_index = i
						break
					end
				end

				if todos_index then
					-- print(string.format("[DEBUG] Inserting todos at index %d", todos_index + 1))
					-- Insert todos after the TODOS header
					vim.api.nvim_buf_set_lines(bufnr, todos_index + 1, todos_index + 1, false, todos)
					print(string.format("Imported %d todos from previous daily note", #todos))
					return true
				end
			else
				-- print("[DEBUG] No unchecked todos found in previous daily note")
			end

			return true
		end

		-- Prevent infinite loop
		if i > 1000 then
			-- print("[DEBUG] No previous daily notes found after 1000 iterations")
			return false
		end

		i = i + 1
	end
end

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

local function find_weekly()
	local weekly_folder = "/Users/kylian/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/Weekly/"
	require('telescope.builtin').find_files({
		prompt_title = "Find Weekly Notes",
		cwd = weekly_folder,
		hidden = true,
		find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
	})
end

local function apply_template_by_folder()
	-- Get the full path of the current buffer
	local current_file_path = vim.fn.expand('%:p')
	local workspace_path = "/Users/kylian/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/"

	-- Remove the workspace path to get the relative path
	local relative_path = current_file_path:sub(#workspace_path + 1)

	-- Define template mappings
	local template_mappings = {
		["Daily/"] = "Daily Template.md",
		["Weekly/"] = "Weekly Template.md"
	}

	-- Check if the file is in a specific folder and needs a template
	for folder, template in pairs(template_mappings) do
		if relative_path:match("^" .. folder) then
			local template_path = workspace_path .. "Templates/" .. template

			-- Check if the file is empty
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			if #lines <= 1 and (lines[1] == "" or lines[1]:match("^%s*$")) then
				-- Read template content
				local template_content = {}
				for line in io.lines(template_path) do
					-- You can add dynamic replacements here if needed
					-- For example, replacing date placeholders
					line = line:gsub("%%DATE%%", os.date("%m-%d-%Y"))
					table.insert(template_content, line)
				end

				-- Insert template content
				vim.api.nvim_buf_set_lines(0, 0, -1, false, template_content)

				print(string.format("Applied template: %s for folder %s", template, folder))
				return true
			end
		end
	end

	return false
end

local function create_weekly_note()
	local weekly_folder =
	"/Users/kylian/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/Weekly/"

	-- Get the current date and calculate the week number
	local current_time = os.time()
	local current_date = os.date("*t", current_time)

	-- Get the month name
	local month_names = {
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	}
	local month_name = month_names[current_date.month]

	-- Determine the week number and add appropriate ordinal suffix
	local week_number = math.ceil(current_date.day / 7)
	local week_suffix
	if week_number == 1 then
		week_suffix = "st"
	elseif week_number == 2 then
		week_suffix = "nd"
	elseif week_number == 3 then
		week_suffix = "rd"
	else
		week_suffix = "th"
	end

	-- Create filename in the new format
	local filename = string.format("%d-%s %d%s.md",
		current_date.year, month_name, week_number, week_suffix)
	local full_path = weekly_folder .. filename

	-- Create the file if it doesn't exist
	local f = io.open(full_path, "a")
	if f then
		f:close()
		vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
	else
		print("Failed to create weekly note")
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
		follow_url_func = function(url)
			vim.fn.jobstart({ "open", url })
		end
	},
	config = function(_, opts)
		require("obsidian").setup(opts)

		vim.api.nvim_create_user_command("ObsidianFindWeekly", function()
			find_weekly()
		end, {})
		vim.api.nvim_create_user_command("WeeklyCreate", function()
			create_weekly_note()
		end, {})

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

		vim.api.nvim_create_user_command("ObsidianOpenDaily", function()
			vim.api.nvim_command("ObsidianToday")
		end, {})

		vim.api.nvim_create_autocmd("BufReadPost", {
			pattern = "*.md",
			callback = function()
				-- Check if the current file is a daily note by matching the filename pattern
				local current_file = vim.fn.expand('%:t:r')
				local date_pattern = "(%d+)%-(%d+)%-(%d+)"
				local month, day, year = current_file:match(date_pattern)

				if month and day and year then
					import_todos_from_previous_daily()
				end
			end,
		})


		-- FileType autocommand for markdown files
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "markdown",
			callback = function()
				-- Weekly
				vim.api.nvim_set_keymap("n", "<leader>wa", "<cmd>ObsidianFindWeekly<CR>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>wn", "<cmd>WeeklyCreate<CR>",
					{ noremap = true, silent = true })
				-- Daily
				vim.api.nvim_set_keymap("n", "<leader>da", "<cmd>ObsidianDailies<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>dd", "<cmd>ObsidianOpenDaily<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>dp", "<cmd>ObsidianPreviousDaily<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>dn", "<cmd>ObsidianNextDaily<cr>",
					{ noremap = true, silent = true })
				-- Commands
				vim.api.nvim_set_keymap("n", "gf", "<cmd>ObsidianFollowLink<cr>",
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
				vim.api.nvim_set_keymap("n", "<c-P>", "<cmd>ObsidianSearch<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>ef", ":ObsidianEditFrontmatter ",
					{ noremap = true })
				-- Create command to check metadata
				vim.api.nvim_create_user_command("ObsidianCheckMetadata", function()
					check_metadata()
				end, {})

				-- Automatically check metadata when opening a daily note
				check_metadata()
			end
		})

		-- Autocmd to apply template based on folder
		vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
			pattern = "*.md",
			callback = function()
				apply_template_by_folder()
			end
		})
	end,
}
