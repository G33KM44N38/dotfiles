local workspace_path = "/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/"
local daily_folder =
"/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/Daily/"
local weekly_folder = "/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/Weekly/"

-- Global date format to be used throughout the file
local date_format = "%m-%d-%Y"
local time_format = "%H:%M"

local function find_todos_line()
	-- Iterate through all lines in the current buffer
	for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		if line:match("^%s*##%s*TODOS%s*$") then
			-- Return the line number (Neovim uses 0-based indexing)
			return i
		end
	end
	return nil
end

local function find_next_non_empty_line(start_line)
	-- Get total number of lines in the buffer
	local total_lines = vim.api.nvim_buf_line_count(0)

	-- Start from the next line
	for i = start_line + 1, total_lines do
		-- Get the line content
		local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]

		-- Check if line is not empty (trim whitespace)
		if line:match("%S") then
			return i
		end
	end

	-- Return nil if no non-empty line found
	return nil
end


local function sort_with_nested_children(start_line, end_line)
	local lines_info = {}

	-- Step 1: Collect all lines with their indentation information
	for line = start_line, end_line do
		local line_content = vim.fn.getline(line)
		local indent = vim.fn.indent(line)

		table.insert(lines_info, {
			line_num = line,
			indent = indent,
			content = line_content
		})
	end

	-- Step 2: Build a hierarchical structure of the lines
	local function build_hierarchy()
		local hierarchy = {}
		local stack = {}
		local current_level = hierarchy

		for i, line_info in ipairs(lines_info) do
			-- Create node for this line
			local node = {
				line_info = line_info,
				children = {},
				parent = nil
			}

			-- Find the appropriate parent for this node based on indentation
			while #stack > 0 and line_info.indent <= stack[#stack].line_info.indent do
				table.remove(stack)
			end

			if #stack == 0 then
				-- This is a top-level node
				table.insert(hierarchy, node)
			else
				-- This is a child node
				local parent = stack[#stack]
				node.parent = parent
				table.insert(parent.children, node)
			end

			-- Add this node to the stack as a potential parent for future nodes
			table.insert(stack, node)
		end

		return hierarchy
	end

	-- Step 3: Sort the hierarchy at all levels
	local function sort_hierarchy(nodes)
		-- Sort children recursively first
		for _, node in ipairs(nodes) do
			if #node.children > 0 then
				sort_hierarchy(node.children)
			end
		end

		-- Sort nodes at this level
		table.sort(nodes, function(a, b)
			return a.line_info.content < b.line_info.content
		end)
	end

	-- Step 4: Flatten the sorted hierarchy back to a list
	local function flatten_hierarchy(nodes)
		local result = {}

		for _, node in ipairs(nodes) do
			table.insert(result, node.line_info)
			if #node.children > 0 then
				local children = flatten_hierarchy(node.children)
				for _, child in ipairs(children) do
					table.insert(result, child)
				end
			end
		end

		return result
	end

	-- Build the hierarchical structure
	local hierarchy = build_hierarchy()

	-- Sort at all levels
	sort_hierarchy(hierarchy)

	-- Flatten the hierarchy back to a list
	local sorted_lines = flatten_hierarchy(hierarchy)

	-- Apply the sorted lines back to the buffer
	for i, line_info in ipairs(sorted_lines) do
		vim.fn.setline(start_line + i - 1, line_info.content)
	end
end

vim.api.nvim_create_user_command("SortWithChildren", function()
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")

	sort_with_nested_children(start_line, end_line)
end, { range = true })

local function line_has_content(line_number)
	-- Get line content
	local line_content = vim.fn.getline(line_number)

	-- Check if line is nil or empty
	if not line_content or line_content == "" then
		return false
	end

	-- Remove all whitespace
	local trimmed = line_content:gsub("%s+", "")

	return trimmed ~= ""
end

local function get_indent_group()
	-- Get current line's indent
	local current_line = vim.fn.line('.')
	local current_indent = vim.fn.indent(current_line)

	-- Start from next line
	local next_line = current_line + 1
	local total_lines = vim.fn.line('$')

	while next_line <= total_lines do
		if not line_has_content(next_line) then
			break
		end
		local next_indent = vim.fn.indent(next_line)

		-- Stop if indent is less than or equal to current indent
		if next_indent < current_indent then
			break
		end

		next_line = next_line + 1
	end

	return current_line, next_line - 1 -- Last line of the block
end

function TODOSort()
	local cursor_position = vim.api.nvim_win_get_cursor(0)
	local todo_line = find_todos_line()
	local start_of_todo_list = find_next_non_empty_line(todo_line)

	vim.api.nvim_win_set_cursor(0, { start_of_todo_list, 0 })

	local _, end_of_indent_group = get_indent_group()

	sort_with_nested_children(start_of_todo_list, end_of_indent_group)

	vim.api.nvim_win_set_cursor(0, { cursor_position[1], cursor_position[2] })
end

-- Sample function to read the content of a file
---@param file_path string Path to the file to read
---@return string The content of the file
local function readFile(file_path)
	local file = io.open(file_path, "r")
	if not file then return "" end
	local content = file:read("*all")
	file:close()
	return content
end

-- Parse the YAML-like metadata from the file content
---@param content string The content of the file
---@return table The parsed metadata (tags and created)
local function parseMetadata(content)
	local metadata = {}
	-- Search for tags (e.g., tags: - daily) and created (e.g., created: 02-14-2025)
	local tags = {}
	for tag in content:gmatch("tags:%s*%-?%s*(%w+)") do
		table.insert(tags, tag)
	end
	metadata.tags = tags
	metadata.created = content:match("created:%s*(%d+-%d+-%d+)") -- Match date format (e.g., 02-14-2025)

	return metadata
end

-- Scan the workspace and return a list of files with metadata
---@param workspace string Path to the workspace directory
---@return table A list of files with their metadata
local function scanWorkspace(workspace)
	local files = {}
	local scan = require("plenary.scandir")
	local results = scan.scan_dir(workspace_path, {
		hidden = false,
		add_dirs = false,
		respect_gitignore = true,
		depth = 1,
		search_pattern = "%.md$"
	})

	for _, file_path in ipairs(results) do
		local file = vim.fn.fnamemodify(file_path, ":t")
		local content = readFile(file_path)
		local metadata = parseMetadata(content)
		table.insert(files, { name = file, metadata = metadata })
	end
	return files
end

local function markdown_headings()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	-- Get current buffer contents
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local headings = {}

	-- Find all headings with their line numbers
	for i, line in ipairs(lines) do
		if line:match("^#+ ") then
			table.insert(headings, {
				line = i,
				text = line:gsub("^#+%s*", ""), -- Remove #s from display
				raw = line
			})
		end
	end

	pickers.new({}, {
		prompt_title = "Markdown Headings",
		finder = finders.new_table({
			results = headings,
			entry_maker = function(entry)
				return {
					value = entry,
					display = string.format("%d: %s", entry.line, entry.text),
					ordinal = string.format("%d %s", entry.line, entry.text),
					lnum = entry.line
				}
			end
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
			end)
			return true
		end,
	}):find()
end

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
	-- Get the current file's full path and name
	local current_file_path = vim.fn.expand('%:p')
	local current_file = vim.fn.expand('%:t:r') -- Get current file name without extension

	-- Skip files in the Templates folder
	if current_file_path:match("Templates/") then
		return false
	end

	-- Get the file's modification time
	local file_stats = vim.uv.fs_stat(current_file_path)
	if not file_stats then
		-- print("Could not get file stats")
		return false
	end

	-- Convert file modification time to a formatted date string
	local file_date = os.date("%m-%d-%Y", file_stats.mtime.sec)

	-- Extract frontmatter
	local frontmatter = extract_frontmatter()
	if not frontmatter then
		-- No frontmatter, so we'll add it
		edit_frontmatter("created", file_date)
		return true
	end

	-- Check if date exists in frontmatter
	local frontmatter_date = frontmatter:match("created:%s*(.-)%s*$")

	-- Handle template placeholder for any markdown file
	if frontmatter_date and frontmatter_date:match("<%% tp%.date%.now%(%) %%>") then
		-- print("Replacing template placeholder with actual created date")
		edit_frontmatter("created", file_date)
		return true
	end

	-- If no date is set, add the current file's date
	if not frontmatter_date then
		edit_frontmatter("created", file_date)
		return true
	end

	return true
end

local function import_todos_from_previous_daily()
	local current_file = vim.fn.expand('%:t:r') -- Get current file name without extension
	local date_pattern = "(%d+)%-(%d+)%-(%d+)"
	local month, day, year = current_file:match(date_pattern)


	if not (month and day and year) then
		return false
	end

	local current_date = os.time({ year = year, month = month, day = day })


	-- Find previous daily note
	local i = 1
	while true do
		local prev_date = os.date("*t", current_date - (i * 86400)) -- 86400 seconds = 1 day
		local prev_file = string.format("%02d-%02d-%04d.md", prev_date.month, prev_date.day, prev_date.year)
		local full_path = daily_folder .. prev_file


		-- Check if file exists
		local f = io.open(full_path, "r")
		if f then
			f:close()


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
				elseif in_todos_section and line:match("^##") then
					-- Stop when next section starts
					break
				elseif in_todos_section and line:match("%s*-%s*%[%s*[^xX]%s*%]") then
					-- Unchecked todo item
					table.insert(todos, line)
				end
			end

			-- If todos found, add them to current file
			if #todos > 0 then
				-- Get current buffer
				local bufnr = vim.api.nvim_get_current_buf()

				-- Find the TODOS section in current file
				local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
				local todos_index = nil
				local existing_todos = {}

				-- First, find the TODOS section and collect existing todos
				for i_2, line in ipairs(lines) do
					if line:match("^## TODOS") then
						todos_index = i_2
					elseif todos_index and line:match("%s*-%s*%[") then
						-- Si un todo (coché ou non coché) existe déjà, arrêter l'importation
						print("stop the import TODOS already existing")
						return false
					elseif todos_index and line:match("%s*-%s*%[%s*%]") then
						-- Collect existing unchecked todos
						existing_todos[line:gsub("%s*-%s*%[%s*%]%s*(.*)$", "%1")] = true
					elseif todos_index and line:match("^##") then
						-- Stop when next section starts
						break
					end
				end

				-- Filter out todos that already exist
				local new_todos = {}
				for _, todo in ipairs(todos) do
					local todo_text = todo:gsub("%s*-%s*%[%s*%]%s*(.*)$", "%1")
					if not existing_todos[todo_text] then
						table.insert(new_todos, todo)
					end
				end

				-- Insert new todos if any
				if #new_todos > 0 and todos_index then
					-- Add an empty line after the todos for better readability
					table.insert(new_todos, "")

					vim.api.nvim_buf_set_lines(bufnr, todos_index + 1, todos_index + 1, false, new_todos)
					-- print(string.format("Imported %d new todos from previous daily note", #new_todos))
					return true
				end
			end

			return true
		end

		-- Prevent infinite loop
		if i > 1000 then
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
		local current_date = os.time({ year = year, month = month, day = day })

		-- Start checking from yesterday, going backwards
		local i = 1
		while true do
			local prev_date = os.date("*t", current_date - (i * 86400)) -- 86400 seconds = 1 day
			local prev_file = string.format("%02d-%02d-%04d.md", prev_date.month, prev_date.day, prev_date.year)
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
				-- print("No previous daily notes found")
				return false
			end

			i = i + 1
		end
	else
		-- print("Current file is not a daily note")
		return false
	end
end

local ts = vim.treesitter
local query = ts.query.parse('markdown', [[
  (fenced_code_block
    (info_string) @language
    (#eq? @language "dataview")
  ) @block
]])

local function is_dataview_block(lines)
	-- Check if the block starts and ends with triple backticks and contains 'dataview' keyword
	return lines[1]:match("```") and
	    lines[#lines]:match("```") and
	    vim.fn.join(lines, " "):match("dataview")
end

---@param type string The parameter name
---@return string # Return value description
local function type_of_display(type)
	return type
end

local dataview_query = ""
local function display_virtual_dataview_output()
	local bufnr = vim.api.nvim_get_current_buf()
	local parser = ts.get_parser(bufnr, "markdown")
	local tree = parser:parse()[1]
	local root = tree:root()
	local ns_id = vim.api.nvim_create_namespace("dataview_output_namespace")

	for pattern_id, match, metadata in query:iter_matches(root, bufnr, 0, -1, { all = true }) do
		for capture_id, nodes in pairs(match) do
			for _, node in ipairs(nodes) do
				local start_row, start_col, end_row, end_col = node:range()

				-- Get all lines from the buffer
				local all_lines = vim.api.nvim_buf_get_lines(bufnr, start_row, -1, false)
				local block_end = nil

				-- Find the closing backticks
				for i, line in ipairs(all_lines) do
					if line:match("^```%s*$") then
						block_end = start_row + i - 1
						break
					end
				end

				if block_end then
					-- Get just the content between the backticks (excluding them)
					local content_lines = vim.api.nvim_buf_get_lines(bufnr, start_row + 1, block_end, false)
					dataview_query = table.concat(content_lines, " ")

					if is_dataview_block(content_lines) then
						local bloc_type = type_of_display("table")
						local dataview_output = { bloc_type }

						vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
						for idx, text in ipairs(dataview_output) do
							vim.api.nvim_buf_set_extmark(bufnr, ns_id, block_end + idx, 0, {
								virt_text = { { text, "inline" } },
								virt_text_pos = "inline"
							})
						end
						return
					end
				end
			end
		end
	end
	-- print("No dataview block found.")
end

local table_dataview_query = {}

---@param query_string string The query string to parse
---@return table Parsed query components (request type, condition, assignment)
local function parseDataViewQuery(query_string)
	-- Clean up the input string by trimming extra spaces and newlines
	query_string = query_string:gsub("\n", " "):gsub("%s+", " "):trim()

	-- Split the query string into words
	local words = {}
	for word in query_string:gmatch("%S+") do
		table.insert(words, word)
	end

	-- Initialize the parsed components
	local parsed_query = {
		request_type = words[1],         -- First word is the request type (e.g., 'table')
		condition = words[2],            -- Second word is the condition (e.g., 'where')
		assignment = table.concat(words, " ", 3) -- The rest is the assignment (e.g., 'created = this.created')
	}

	-- Print parsed components for debugging
	-- print("Request Type:", parsed_query.request_type)
	-- print("Condition:", parsed_query.condition)
	-- print("Assignment:", parsed_query.assignment)

	return parsed_query
end

-- Helper function to trim spaces
function string.trim(s)
	return s:match("^%s*(.-)%s*$")
end

-- Function to execute the query and filter files based on metadata
---@param query_string string The query string to parse
---@param files table A list of files with metadata to search through
---@return table A list of files matching the query
local function executeQuery(query_string, files)
	local parsed_query = parseDataViewQuery(query_string)

	-- Initialize result table
	local results = {}

	-- Check the condition (e.g., 'where')
	if parsed_query.condition == "where" then
		-- Match the assignment (e.g., 'created = this.created')
		local field, value = parsed_query.assignment:match("(%w+) = (.+)")

		-- If we matched the assignment, filter files based on the field and value
		if field and value then
			for _, file in ipairs(files) do
				-- Check if the field exists in the metadata
				if file.metadata[field] then
					-- Compare the field value with the query value
					if type(file.metadata[field]) == "table" then
						-- For tags (which can be a list), check if the value exists in the list
						for _, tag in ipairs(file.metadata[field]) do
							if tag == value then
								table.insert(results, file)
								break
							end
						end
					else
						-- For non-list fields (like created), directly compare the values
						if file.metadata[field] == value then
							table.insert(results, file)
						end
					end
				end
			end
		end
	end

	-- Return the filtered results
	return results
end

local function find_next_daily()
	local current_file = vim.fn.expand('%:t:r')
	local date_pattern = "(%d+)%-(%d+)%-(%d+)"
	local month, day, year = current_file:match(date_pattern)

	if month and day and year then
		local current_date = os.time({ year = year, month = month, day = day })

		local i = 1
		while true do
			local next_date = os.date("*t", current_date + (i * 86400))
			local prev_file = string.format("%02d-%02d-%04d.md", next_date.month, next_date.day, next_date.year)
			local full_path = daily_folder .. prev_file

			local f = io.open(full_path, "r")
			if f then
				f:close()
				vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
				return true
			end

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
	-- Use Telescope to find files, but with custom sorting
	require('telescope.builtin').find_files({
		prompt_title = "Find Weekly Notes",
		cwd = weekly_folder,
		hidden = true,
		find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
		sorter = require('telescope.sorters').get_generic_fuzzy_sorter(),
		attach_mappings = function(prompt_bufnr, map)
			-- Override default sorting to sort files chronologically
			local custom_sorter = require('telescope.sorters').get_generic_fuzzy_sorter()

			-- Custom function to sort files
			custom_sorter.scoring_function = function(_, prompt, entry)
				-- Extract year, month, and week from filename
				local year, month, week = entry.value:match("(%d+)%-([%a]+) (%d+)%a+")

				-- Convert month to number
				local month_names = {
					"January", "February", "March", "April", "May", "June",
					"July", "August", "September", "October", "November", "December"
				}
				local month_num = 0
				for i, m in ipairs(month_names) do
					if m == month then
						month_num = i
						break
					end
				end

				-- Create a sortable key
				local sort_key = tonumber(year) * 10000 + month_num * 100 + tonumber(week)

				return sort_key -- Positive to sort chronologically (oldest at top)
			end

			return true
		end
	})
end

local function apply_template_by_folder()
	local current_file_path = vim.fn.expand('%:p')
	local relative_path = current_file_path:sub(#workspace_path + 1)

	local template_mappings = {
		["Daily/"] = "Daily Template.md",
		["Weekly/"] = "Weekly Template.md"
	}

	for folder, template in pairs(template_mappings) do
		if relative_path:match("^" .. folder) then
			local template_path = workspace_path .. "Templates/" .. template

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			if #lines <= 1 and (lines[1] == "" or lines[1]:match("^%s*$")) then
				local template_content = {}
				for line in io.lines(template_path) do
					line = line:gsub("%%DATE%%", os.date("%m-%d-%Y"))
					table.insert(template_content, line)
				end

				vim.api.nvim_buf_set_lines(0, 0, -1, false, template_content)

				-- print(string.format("Applied template: %s for folder %s", template, folder))
				return true
			end
		end
	end

	return false
end

local function create_weekly_note()
	local current_time = os.time()
	local current_date = os.date("*t", current_time)

	local month_names = {
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	}
	local month_name = month_names[current_date.month]

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

	local filename = string.format("%d-%s %d%s.md",
		current_date.year, month_name, week_number, week_suffix)
	local full_path = weekly_folder .. filename

	local f = io.open(full_path, "a")
	if f then
		f:close()
		vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
	else
		print("Failed to create weekly note")
	end
end


local function find_previous_weekly()
	local current_file = vim.fn.expand('%:t:r')

	-- Parse the current weekly note filename (e.g., "2025-January 1st")
	local year, month, week_number = current_file:match("(%d+)%-([%a]+) (%d+)%a+")

	if year and month and week_number then
		local month_names = {
			"January", "February", "March", "April", "May", "June",
			"July", "August", "September", "October", "November", "December"
		}

		-- Convert month name to number
		local month_number
		for i, name in ipairs(month_names) do
			if name == month then
				month_number = i
				break
			end
		end

		-- Start checking from the previous week
		local i = 1
		while true do
			local prev_week_number = tonumber(week_number) - i
			local prev_year = tonumber(year)
			local prev_month_number = month_number

			-- Adjust week number, month, and year
			while prev_week_number < 1 do
				prev_week_number = prev_week_number + 4
				prev_month_number = prev_month_number - 1
				if prev_month_number < 1 then
					prev_month_number = 12
					prev_year = prev_year - 1
				end
			end

			local prev_month_name = month_names[prev_month_number]

			-- Determine week suffix
			local week_suffix
			if prev_week_number == 1 then
				week_suffix = "st"
			elseif prev_week_number == 2 then
				week_suffix = "nd"
			elseif prev_week_number == 3 then
				week_suffix = "rd"
			else
				week_suffix = "th"
			end

			local prev_file = string.format("%d-%s %d%s.md", prev_year, prev_month_name, prev_week_number, week_suffix)
			local full_path = weekly_folder .. prev_file

			-- Check if file exists
			local f = io.open(full_path, "r")
			if f then
				f:close()
				vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
				return true
			end

			-- Prevent infinite loop
			if i > 1000 then
				print("No previous weekly notes found")
				return false
			end

			i = i + 1
		end
	else
		print("Current file is not a weekly note")
		return false
	end
end

local function find_next_weekly()
	local current_file = vim.fn.expand('%:t:r')

	-- Parse the current weekly note filename (e.g., "2025-January 1st")
	local year, month, week_number = current_file:match("(%d+)%-([%a]+) (%d+)%a+")

	if year and month and week_number then
		local month_names = {
			"January", "February", "March", "April", "May", "June",
			"July", "August", "September", "October", "November", "December"
		}

		-- Convert month name to number
		local month_number
		for i, name in ipairs(month_names) do
			if name == month then
				month_number = i
				break
			end
		end

		-- Start checking from the next week
		local i = 1
		while true do
			local next_week_number = tonumber(week_number) + i
			local next_year = tonumber(year)
			local next_month_number = month_number

			-- Adjust week number, month, and year
			while next_week_number > 4 do
				next_week_number = next_week_number - 4
				next_month_number = next_month_number + 1
				if next_month_number > 12 then
					next_month_number = 1
					next_year = next_year + 1
				end
			end

			local next_month_name = month_names[next_month_number]

			-- Determine week suffix
			local week_suffix
			if next_week_number == 1 then
				week_suffix = "st"
			elseif next_week_number == 2 then
				week_suffix = "nd"
			elseif next_week_number == 3 then
				week_suffix = "rd"
			else
				week_suffix = "th"
			end

			local next_file = string.format("%d-%s %d%s.md", next_year, next_month_name, next_week_number, week_suffix)
			local full_path = weekly_folder .. next_file

			-- Check if file exists
			local f = io.open(full_path, "r")
			if f then
				f:close()
				vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
				return true
			end

			-- Prevent infinite loop
			if i > 1000 then
				print("No next weekly notes found")
				return false
			end

			i = i + 1
		end
	else
		print("Current file is not a weekly note")
		return false
	end
end

local function find_current_weekly()
	local current_time = os.time()
	local current_date = os.date("*t", current_time)

	local month_names = {
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	}
	local month_name = month_names[current_date.month]

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

	local filename = string.format("%d-%s %d%s.md",
		current_date.year, month_name, week_number, week_suffix)
	local full_path = weekly_folder .. filename

	local f = io.open(full_path, "r")
	if f then
		f:close()
		vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
		return true
	else
		vim.cmd("WeeklyCreate")
		-- print("Current weekly note not found")
		return false
	end
end

local function toggle_checkbox_with_timestamp()
	-- Get the current line
	local line = vim.api.nvim_get_current_line()

	-- Check if the line has a checkbox
	local checkbox_pattern = "(%s*-%s*%[)([%s%a%d])(])(.*)"
	local indent, prefix, mark, suffix = line:match(checkbox_pattern)

	if indent and prefix and mark and suffix then
		local new_line

		-- Use the date_format variable
		local timestamp = os.date(date_format .. " " .. time_format)
		new_line = indent .. "x" .. "] " .. suffix .. " [completed: " .. timestamp .. "]"

		-- Update the line
		vim.api.nvim_set_current_line(new_line)
	else
		-- If no checkbox pattern found, use the built-in toggle function
		vim.cmd("ObsidianToggleCheckbox")
	end
end

local function find_completed_todos_with_timestamps()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local scan = require("plenary.scandir")

	local completed_todos = {}

	-- Get all markdown files in the daily folder
	local files = scan.scan_dir(daily_folder, {
		hidden = false,
		add_dirs = false,
		respect_gitignore = true,
		depth = 1,
		search_pattern = "%.md$"
	})

	-- Sort files by date (most recent first)
	table.sort(files, function(a, b)
		local a_filename = vim.fn.fnamemodify(a, ":t:r")
		local b_filename = vim.fn.fnamemodify(b, ":t:r")
		return a_filename > b_filename
	end)

	-- Process each file
	for _, file_path in ipairs(files) do
		local file_handle = io.open(file_path, "r")
		if file_handle then
			local filename = vim.fn.fnamemodify(file_path, ":t:r")
			local content = file_handle:read("*all")
			file_handle:close()

			-- Process the file line by line
			local line_num = 1
			for line in content:gmatch("[^\r\n]+") do
				-- Match checked todos with timestamp pattern: - [x] Todo text [completed: MM-DD-YYYY HH:MM]
				local todo_text, timestamp = line:match("%s*-%s*%[x%]%s*(.-)%s*%[completed:%s*(.-)%]")
				if todo_text and timestamp then
					table.insert(completed_todos, {
						file_path = file_path,
						filename = filename,
						line = line_num,
						text = todo_text,
						timestamp = timestamp,
						raw = line
					})
				end
				line_num = line_num + 1
			end
		end
	end

	-- Sort by timestamp (most recent first)
	table.sort(completed_todos, function(a, b)
		return a.timestamp > b.timestamp
	end)

	pickers.new({}, {
		prompt_title = "Completed TODOs Across All Daily Notes",
		finder = finders.new_table({
			results = completed_todos,
			entry_maker = function(entry)
				return {
					value = entry,
					display = string.format("[%s] [%s] %s", entry.timestamp, entry.filename, entry.text),
					ordinal = entry.timestamp .. " " .. entry.filename .. " " .. entry.text,
					filename = entry.file_path,
					lnum = entry.line
				}
			end
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				-- Open the file and go to that line
				vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))
				vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
			end)
			return true
		end,
	}):find()
end

vim.api.nvim_create_user_command("CompletedTodos", function()
	find_completed_todos_with_timestamps()
end, {})

vim.api.nvim_create_user_command("ObsdianDaily", function()
	-- Get current date
	local date_time = os.date("*t")
	local year = date_time.year
	local month = date_time.month
	local day = date_time.day

	-- Format month and day with leading zeros if needed
	local month_str = string.format("%02d", month)
	local day_str = string.format("%02d", day)

	-- Create filename
	local daily_folder = "Daily/" -- Adjust this path as needed
	local filename = daily_folder .. month_str .. "-" .. day_str .. "-" .. year .. ".md"

	-- Check if the folder exists
	local folder_exists = vim.fn.isdirectory(daily_folder)
	if folder_exists == 0 then
		-- Create the folder if it doesn't exist
		vim.fn.mkdir(daily_folder, "p")
	end

	-- Open or create the file in Neovim
	vim.cmd("edit " .. filename)
end, {})

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
				path = "/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/",
			},
		},
		date_format = date_format,
		templates = {
			folder = "Templates",
			date_format = date_format,
			time_format = time_format,
		},
		disable_frontmatter = true,
		note_id_func = function(title)
			return title
		end,
		daily_notes = {
			folder = "Daily/",
			date_format = date_format,
			template = "Daily Template.md"
		},
		use_advanced_uri = true,
		mappings = {},
		attachments = {
			img_folder = "Attachments/",
			---@return string
			img_name_func = function()
				return string.format("%s-", os.time())
			end,
		},
		follow_url_func = function(url)
			vim.fn.jobstart({ "open", url })
		end
	},
	config = function(_, opts)
		vim.cmd("set conceallevel=1")
		require("obsidian").setup(opts)

		vim.api.nvim_create_user_command("ObsidianPreviousWeekly", function()
			find_previous_weekly()
		end, {})

		vim.api.nvim_create_user_command("ObsidianCurrentWeekly", function()
			find_current_weekly()
		end, {})

		vim.api.nvim_create_user_command("ObsidianNextWeekly", function()
			find_next_weekly()
		end, {})

		vim.api.nvim_create_user_command("ObsidianFindWeekly", function()
			find_weekly()
		end, {})
		vim.api.nvim_create_user_command("WeeklyCreate", function()
			create_weekly_note()
		end, {})

		vim.api.nvim_create_user_command("ObsidianEditFrontmatter", function(args)
			if #args.fargs < 2 then
				-- print("Usage: ObsidianEditFrontmatter <key> <value>")
				return
			end
			local key = args.fargs[1]
			local value = table.concat({ select(2, unpack(args.fargs)) }, " ")
		end, {
			nargs = "+",
			complete = function(ArgLead, CmdLine, CursorPos)
				return { "tags", "alias", "date", "title", "status", "type" }
			end
		})


		vim.api.nvim_create_user_command("ObsidianPreviousDaily", function()
			find_previous_daily()
		end, {})

		vim.api.nvim_create_user_command("ObsidianNextDaily", function()
			find_next_daily()
		end, {})

		vim.api.nvim_create_user_command("Headings", markdown_headings, {})

		vim.api.nvim_create_autocmd("BufReadPost", {
			pattern = "*.md",
			callback = function()
				local current_file = vim.fn.expand('%:t:r')
				local date_pattern = "(%d+)%-(%d+)%-(%d+)"
				local month, day, year = current_file:match(date_pattern)

				if month and day and year then
					import_todos_from_previous_daily()
				end
			end,
		})


		vim.api.nvim_create_autocmd("FileType", {
			pattern = "markdown",
			callback = function()
				vim.api.nvim_set_keymap("n", "<leader>ts", "<cmd>TODOSort<CR>", {})

				vim.keymap.set('n', '<leader>fh', ':Headings<CR>',
					{ noremap = true, silent = true, desc = "Find headings" })
				vim.api.nvim_set_keymap("n", "[#", "?^#\\+\\s<CR>",
					{ noremap = true, silent = true, desc = "Go to previous heading" })
				vim.api.nvim_set_keymap("n", "]#", "/^#\\+\\s<CR>",
					{ noremap = true, silent = true, desc = "Go to next heading" })
				-- Weekly
				vim.api.nvim_set_keymap("n", "<leader>ww", "<cmd>ObsidianCurrentWeekly<cr>",
					{ noremap = true, silent = true, desc = "Current Weekly Note" })
				vim.api.nvim_set_keymap("n", "<leader>wa", "<cmd>ObsidianFindWeekly<CR>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>wn", "<cmd>WeeklyCreate<CR>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>wp", "<cmd>ObsidianPreviousWeekly<cr>",
					{ noremap = true, silent = true, desc = "Previous Weekly Note" })
				vim.api.nvim_set_keymap("n", "<leader>wn", "<cmd>ObsidianNextWeekly<cr>",
					{ noremap = true, silent = true, desc = "Next Weekly Note" })
				-- Daily
				vim.api.nvim_set_keymap("n", "<leader>da", "<cmd>ObsidianDailies<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>dd", "<cmd>ObsidianToday<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>dp", "<cmd>ObsidianPreviousDaily<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "<leader>dn", "<cmd>ObsidianNextDaily<cr>",
					{ noremap = true, silent = true })
				-- Commands
				vim.api.nvim_set_keymap("n", "gf", "<cmd>ObsidianFollowLink<cr>",
					{ noremap = true, silent = true })
				vim.api.nvim_set_keymap("n", "ch", "<cmd>ToggleCheckboxWithTimestamp<cr>",
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
				vim.api.nvim_set_keymap("n", "<leader>ef", ":ObsidianEditFrontmatter ",
					{ noremap = true })
				-- Add keymap for finding completed todos
				vim.api.nvim_set_keymap("n", "<leader>td", "<cmd>CompletedTodos<cr>",
					{ noremap = true, silent = true, desc = "Find completed TODOs" })
				-- Create command to check metadata
				vim.api.nvim_create_user_command("ObsidianCheckMetadata", function()
					check_metadata()
				end, {})

				check_metadata()
				display_virtual_dataview_output()
				local files_in_workspace = scanWorkspace(workspace_path)
				local result_files = executeQuery(dataview_query, files_in_workspace)
				-- print(result_files)
			end
		})

		-- Autocmd to apply template based on folder
		vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
			pattern = "*.md",
			callback = function()
				apply_template_by_folder()
			end
		})

		vim.api.nvim_create_autocmd({ "BufWritePre" }, {
			pattern = "*.md",
			callback = function()
				TODOSort()
			end
		})

		vim.api.nvim_create_user_command("ToggleCheckboxWithTimestamp", function()
			toggle_checkbox_with_timestamp()
		end, {})

		vim.api.nvim_create_user_command("TmuxNavigateSecondBrain", function()
			-- Use vim.fn.system() for better handling of shell commands in Neovim
			vim.fn.system("tmux-navigate.sh Second_Brain")
		end, {})

		-- Set the keymap with proper options
		vim.keymap.set("n", "<leader>sb", ":TmuxNavigateSecondBrain<CR>", {
			noremap = true, -- Prevent recursive mapping
			silent = true -- Prevent command from being echoed
		})
	end,
}
