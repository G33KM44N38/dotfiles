return {
	"andrewferrier/debugprint.nvim",

	opts = {
		keymaps = {
			normal = {
				plain_below = "g?p",
				plain_above = "g?P",
				variable_below = "g?v",
				variable_above = "g?V",
				variable_below_alwaysprompt = "",
				variable_above_alwaysprompt = "",
				surround_plain = "g?sp",
				surround_variable = "g?sv",
				surround_variable_alwaysprompt = "",
				textobj_below = "g?o",
				textobj_above = "g?O",
				textobj_surround = "g?so",
				toggle_comment_debug_prints = "",
				delete_debug_prints = "",
			},
			insert = {
				plain = "<C-G>p",
				variable = "<C-G>v",
			},
			visual = {
				variable_below = "g?v",
				variable_above = "g?V",
			},
		},
		-- … Other options
	},

	config = function(_, opts)
		require("debugprint").setup(opts)

		local debug_calls = {}
		local current_index = 0

		-- Tree-sitter integration to find console.log and console.warn calls
		local function find_debug_calls(method_type)
			local buf = vim.api.nvim_get_current_buf()
			local ft = vim.bo.filetype

			if ft ~= "javascript" and ft ~= "typescript" and ft ~= "javascriptreact" and ft ~= "typescriptreact" then
				vim.notify("Not a JavaScript/TypeScript file", vim.log.levels.WARN)
				return {}
			end

			local ts = vim.treesitter
			local query_str

			if method_type == "all" then
				query_str = [[
					(call_expression
						function: (member_expression
							object: (identifier) @console (#eq? @console "console")
							property: (property_identifier) @method (#any-of? @method "log" "warn" "error" "debug"))
						arguments: (arguments) @args) @call
				]]
			elseif method_type == "log" then
				query_str = [[
					(call_expression
						function: (member_expression
							object: (identifier) @console (#eq? @console "console")
							property: (property_identifier) @method (#eq? @method "log"))
						arguments: (arguments) @args) @call
				]]
			elseif method_type == "warn" then
				query_str = [[
					(call_expression
						function: (member_expression
							object: (identifier) @console (#eq? @console "console")
							property: (property_identifier) @method (#eq? @method "warn"))
						arguments: (arguments) @args) @call
				]]
			end

			-- Check if parser exists
			local parser = ts.get_parser(buf, ft)
			if not parser then
				vim.notify("Tree-sitter parser not available for " .. ft, vim.log.levels.WARN)
				return {}
			end

			-- Parse the tree
			local trees = parser:parse()
			if not trees or #trees == 0 then
				vim.notify("Failed to parse tree", vim.log.levels.WARN)
				return {}
			end

			local tree = trees[1]
			local root = tree:root()
			if not root then
				vim.notify("Failed to get tree root", vim.log.levels.WARN)
				return {}
			end

			-- Parse query
			local ok, query = pcall(ts.query.parse, ft, query_str)
			if not ok then
				vim.notify("Invalid query: " .. tostring(query), vim.log.levels.WARN)
				return {}
			end

			local results = {}
			local pcall_ok, err = pcall(function()
				for capture_id, node in query:iter_captures(root, buf) do
					local capture_name = query.captures[capture_id]
					if capture_name == "call" then
						local start_row, start_col, end_row, end_col = node:range()
						table.insert(results, {
							buf = buf,
							row = start_row,
							col = start_col,
							end_row = end_row,
							end_col = end_col,
							text = vim.treesitter.get_node_text(node, buf),
						})
					end
				end
			end)

			if not pcall_ok then
				vim.notify("Error iterating captures: " .. tostring(err), vim.log.levels.WARN)
				return {}
			end

			-- Sort by row, then by col
			table.sort(results, function(a, b)
				if a.row ~= b.row then
					return a.row < b.row
				end
				return a.col < b.col
			end)

			return results
		end

		local function go_to_next_debug(method_type)
			method_type = method_type or "all"
			debug_calls = find_debug_calls(method_type)

			if #debug_calls == 0 then
				vim.notify("No " .. method_type .. " calls found", vim.log.levels.WARN)
				return
			end

			local current_row = vim.api.nvim_win_get_cursor(0)[1] - 1
			local current_col = vim.api.nvim_win_get_cursor(0)[2]

			-- Find next debug call after current position
			current_index = 0
			for i, call in ipairs(debug_calls) do
				if call.row > current_row or (call.row == current_row and call.col > current_col) then
					current_index = i
					break
				end
			end

			-- If no next call found, wrap to first
			if current_index == 0 then
				current_index = 1
			end

			local target = debug_calls[current_index]
			vim.api.nvim_win_set_cursor(0, { target.row + 1, target.col })
			vim.cmd("normal! zz") -- Center the view
			vim.notify(string.format("Debug call %d/%d", current_index, #debug_calls), vim.log.levels.INFO)
		end

		local function go_to_prev_debug(method_type)
			method_type = method_type or "all"
			debug_calls = find_debug_calls(method_type)

			if #debug_calls == 0 then
				vim.notify("No " .. method_type .. " calls found", vim.log.levels.WARN)
				return
			end

			local current_row = vim.api.nvim_win_get_cursor(0)[1] - 1
			local current_col = vim.api.nvim_win_get_cursor(0)[2]

			-- Find previous debug call before current position
			current_index = #debug_calls + 1
			for i = #debug_calls, 1, -1 do
				local call = debug_calls[i]
				if call.row < current_row or (call.row == current_row and call.col < current_col) then
					current_index = i
					break
				end
			end

			-- If no previous call found, wrap to last
			if current_index == #debug_calls + 1 then
				current_index = #debug_calls
			end

			local target = debug_calls[current_index]
			vim.api.nvim_win_set_cursor(0, { target.row + 1, target.col })
			vim.cmd("normal! zz") -- Center the view
			vim.notify(string.format("Debug call %d/%d", current_index, #debug_calls), vim.log.levels.INFO)
		end

		-- Create commands
		vim.api.nvim_create_user_command("DebugprintNextLog", function()
			go_to_next_debug("log")
		end, {})

		vim.api.nvim_create_user_command("DebugprintPrevLog", function()
			go_to_prev_debug("log")
		end, {})

		vim.api.nvim_create_user_command("DebugprintNextWarn", function()
			go_to_next_debug("warn")
		end, {})

		vim.api.nvim_create_user_command("DebugprintPrevWarn", function()
			go_to_prev_debug("warn")
		end, {})

		vim.api.nvim_create_user_command("DebugprintNextAll", function()
			go_to_next_debug("all")
		end, {})

		vim.api.nvim_create_user_command("DebugprintPrevAll", function()
			go_to_prev_debug("all")
		end, {})

		-- Delete debug statement at cursor (handles multi-line statements)
		local function delete_debug_at_cursor()
			local buf = vim.api.nvim_get_current_buf()
			local ft = vim.bo.filetype

			if ft ~= "javascript" and ft ~= "typescript" and ft ~= "javascriptreact" and ft ~= "typescriptreact" then
				vim.notify("Not a JavaScript/TypeScript file", vim.log.levels.WARN)
				return
			end

			local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
			local cursor_col = vim.api.nvim_win_get_cursor(0)[2]

			-- Get the tree-sitter tree
			local ts = vim.treesitter
			local parser = ts.get_parser(buf, ft)
			if not parser then
				vim.notify("Tree-sitter parser not available", vim.log.levels.WARN)
				return
			end

			local trees = parser:parse()
			if not trees or #trees == 0 then
				vim.notify("Failed to parse tree", vim.log.levels.WARN)
				return
			end

			local tree = trees[1]
			local root = tree:root()
			if not root then
				vim.notify("Failed to get tree root", vim.log.levels.WARN)
				return
			end

			-- Find the deepest node at cursor position
			local target_node = root:named_descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)
			if not target_node then
				target_node = root:descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)
			end

			if not target_node then
				vim.notify("Could not find node at cursor", vim.log.levels.WARN)
				return
			end

			-- Traverse up to find the call_expression
			local call_node = nil
			local current_node = target_node
			while current_node do
				if current_node:type() == "call_expression" then
					call_node = current_node
					break
				end
				current_node = current_node:parent()
			end

			if not call_node then
				vim.notify("No debug call found at cursor position", vim.log.levels.WARN)
				return
			end

			-- Get the full range of the call expression (handles multi-line)
			local start_row, start_col, end_row, end_col = call_node:range()

			-- Check if this is actually a console method call
			local text = vim.treesitter.get_node_text(call_node, buf)
			if not string.match(text, "console%.") then
				vim.notify("Not a console statement", vim.log.levels.WARN)
				return
			end

			-- Find the start of the line where the call begins
			local line_start = start_row
			-- Find the end of the line where the call ends (or the semicolon)
			local line_end = end_row

			-- Check if there's a semicolon after the call expression
			local lines = vim.api.nvim_buf_get_lines(buf, line_end, line_end + 1, false)
			if lines and lines[1] then
				local line_text = lines[1]
				-- Check if semicolon is on the same line after the call
				local semi_pos = string.find(line_text, ";", end_col)
				if semi_pos then
					-- Semicolon is on the same line, don't extend further
				else
					-- Semicolon might be on the next line or not exist
					-- Just use end_row as is
				end
			end

			-- Delete the entire statement (all lines from start to end)
			vim.api.nvim_buf_set_lines(buf, line_start, line_end + 1, false, {})
			vim.notify("Deleted debug statement", vim.log.levels.INFO)
		end

		-- Keymaps
		vim.keymap.set("n", "g?n", function()
			go_to_next_debug("all")
		end, { noremap = true, silent = true })
		vim.keymap.set("n", "g?N", function()
			go_to_prev_debug("all")
		end, { noremap = true, silent = true })
		vim.keymap.set("n", "g?l", function()
			go_to_next_debug("log")
		end, { noremap = true, silent = true })
		vim.keymap.set("n", "g?L", function()
			go_to_prev_debug("log")
		end, { noremap = true, silent = true })
		vim.keymap.set("n", "g?w", function()
			go_to_next_debug("warn")
		end, { noremap = true, silent = true })
		vim.keymap.set("n", "g?W", function()
			go_to_prev_debug("warn")
		end, { noremap = true, silent = true })

		-- Delete debug call at cursor
		vim.keymap.set("n", "<leader>dil", function()
			delete_debug_at_cursor()
		end, { noremap = true, silent = true })
	end,

	dependencies = {
		"echasnovski/mini.nvim",
		"echasnovski/mini.hipatterns",
		"ibhagwan/fzf-lua",
		"nvim-telescope/telescope.nvim",
		"folke/snacks.nvim",
	},

	lazy = false,
	version = "*",
}
