--- Deletion module for debug_print plugin
--- Handles deletion of debug statements (multi-line safe)

local utils = require("root.plugins.debug_print.utils")
local config = require("root.plugins.debug_print.config")
local tree_sitter = require("root.plugins.debug_print.tree_sitter")

local M = {}

--- Delete the debug statement at cursor position
--- Handles multi-line console statements correctly
function M.delete_debug_at_cursor()
	local buf = utils.get_current_buf()
	if not buf then return end

	if not utils.is_supported_filetype() then
		utils.notify("Not a JavaScript/TypeScript file", config.NOTIFY_LEVELS.warn)
		return
	end

	-- Find the call_expression node at cursor position
	local call_node = tree_sitter.find_call_at_cursor()
	if not call_node then
		utils.notify("No debug call found at cursor position", config.NOTIFY_LEVELS.warn)
		return
	end

	-- Check if this is actually a console statement
	if not tree_sitter.is_console_statement(call_node, buf) then
		utils.notify("Not a console statement", config.NOTIFY_LEVELS.warn)
		return
	end

	-- Get the full range of the call expression (handles multi-line)
	local start_row, start_col, end_row, end_col = tree_sitter.get_node_range(call_node)

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
	utils.notify("Deleted debug statement", config.NOTIFY_LEVELS.info)
end

return M
