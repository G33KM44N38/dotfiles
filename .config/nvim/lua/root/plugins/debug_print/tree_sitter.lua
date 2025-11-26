--- Tree-sitter AST operations and parsing
--- Handles all tree-sitter related functionality for finding and manipulating debug statements

local utils = require("root.plugins.debug_print.utils")
local config = require("root.plugins.debug_print.config")
local queries_module = require("root.plugins.debug_print.queries")

local M = {}

--- Find all debug calls in the current buffer using tree-sitter
--- @param method_type string: "all" | "log" | "warn" | "error" | "debug"
--- @return table: Array of debug call locations with {buf, row, col, end_row, end_col, text}
function M.find_debug_calls(method_type)
	local buf = utils.get_current_buf()
	if not buf then return {} end

	local ft = vim.bo.filetype
	if not utils.is_supported_filetype() then
		utils.notify("Not a JavaScript/TypeScript file", config.NOTIFY_LEVELS.warn)
		return {}
	end

	-- Get tree-sitter parser
	local parser = utils.get_treesitter_parser(buf, ft)
	if not parser then return {} end

	-- Get tree root
	local root = utils.get_tree_root(parser)
	if not root then return {} end

	-- Build and parse query
	local methods = method_type == "all" and config.CONSOLE_METHODS or { method_type }
	local query_str = queries_module.build_console_query(methods)
	local query = utils.parse_query(ft, query_str)
	if not query then return {} end

	-- Execute query and collect results
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
		utils.notify_error("Query execution", tostring(err))
		return {}
	end

	-- Sort results by position
	table.sort(results, function(a, b)
		if a.row ~= b.row then
			return a.row < b.row
		end
		return a.col < b.col
	end)

	return results
end

--- Find the call_expression node at cursor position
--- Uses AST traversal to find the encompassing function call
--- @return userdata|nil: The call_expression node or nil if not found
function M.find_call_at_cursor()
	local buf = utils.get_current_buf()
	if not buf then return nil end

	local ft = vim.bo.filetype
	if not utils.is_supported_filetype() then
		utils.notify("Not a JavaScript/TypeScript file", config.NOTIFY_LEVELS.warn)
		return nil
	end

	local cursor_row, cursor_col = utils.get_cursor_position()

	-- Get tree-sitter parser and root
	local parser = utils.get_treesitter_parser(buf, ft)
	if not parser then return nil end

	local root = utils.get_tree_root(parser)
	if not root then return nil end

	-- Find node at cursor
	local target_node = root:named_descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)
	if not target_node then
		target_node = root:descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)
	end

	if not target_node then
		utils.notify("Could not find node at cursor", config.NOTIFY_LEVELS.warn)
		return nil
	end

	-- Traverse up AST to find call_expression
	local current_node = target_node
	while current_node do
		if current_node:type() == "call_expression" then
			return current_node
		end
		current_node = current_node:parent()
	end

	return nil
end

--- Get the range (start/end rows) of a call_expression node
--- @param call_node userdata: The call_expression node
--- @return integer, integer, integer, integer: start_row, start_col, end_row, end_col
function M.get_node_range(call_node)
	return call_node:range()
end

--- Check if a node is a console statement (has console.method pattern)
--- @param node userdata: The node to check
--- @param buf integer: Buffer ID
--- @return boolean: True if node is a console statement
function M.is_console_statement(node, buf)
	local text = vim.treesitter.get_node_text(node, buf)
	return string.match(text, "console%.") ~= nil
end

return M
