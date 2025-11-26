--- Utility functions for debug_print plugin
--- Shared helper functions and error handling

local config = require("root.plugins.debug_print.config")
local M = {}

--- Notify user with formatted message
--- @param message string: Message to display
--- @param level integer|nil: Vim notification level (defaults to INFO)
function M.notify(message, level)
	level = level or config.NOTIFY_LEVELS.info
	vim.notify(string.format("[debug_print] %s", message), level)
end

--- Safely notify with error context
--- @param context string: Where the error occurred
--- @param error_msg string: Error message
--- @param level integer|nil: Vim notification level
function M.notify_error(context, error_msg, level)
	level = level or config.NOTIFY_LEVELS.warn
	local message = string.format("%s: %s", context, error_msg)
	M.notify(message, level)
end

--- Check if current buffer is a supported file type
--- @return boolean: True if current file type is supported
function M.is_supported_filetype()
	local ft = vim.bo.filetype
	return vim.tbl_contains(config.SUPPORTED_FILETYPES, ft)
end

--- Get current buffer and validate it
--- @return integer|nil: Current buffer ID or nil if invalid
function M.get_current_buf()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		M.notify_error("Buffer validation", "Current buffer is invalid", config.NOTIFY_LEVELS.error)
		return nil
	end
	return buf
end

--- Get current cursor position (0-indexed)
--- @return integer, integer: Row and column of cursor (0-indexed)
function M.get_cursor_position()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1  -- Convert to 0-indexed
	local col = cursor[2]
	return row, col
end

--- Set cursor to specific position
--- @param row integer: Row (0-indexed)
--- @param col integer: Column (0-indexed)
function M.set_cursor_position(row, col)
	vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

--- Get tree-sitter parser for current buffer
--- @param buf integer: Buffer ID
--- @param ft string: File type
--- @return userdata|nil: Tree-sitter parser or nil if unavailable
function M.get_treesitter_parser(buf, ft)
	local ts = vim.treesitter
	local parser = ts.get_parser(buf, ft)
	if not parser then
		M.notify_error("Tree-sitter", "Parser not available for " .. ft, config.NOTIFY_LEVELS.warn)
		return nil
	end
	return parser
end

--- Parse tree-sitter tree and get root node
--- @param parser userdata: Tree-sitter parser
--- @return userdata|nil: Root node or nil if parsing failed
function M.get_tree_root(parser)
	local trees = parser:parse()
	if not trees or #trees == 0 then
		M.notify_error("Tree-sitter", "Failed to parse tree", config.NOTIFY_LEVELS.warn)
		return nil
	end

	local tree = trees[1]
	local root = tree:root()
	if not root then
		M.notify_error("Tree-sitter", "Failed to get tree root", config.NOTIFY_LEVELS.warn)
		return nil
	end

	return root
end

--- Safely parse tree-sitter query
--- @param ft string: File type
--- @param query_str string: Query string
--- @return userdata|nil: Tree-sitter query or nil if parsing failed
function M.parse_query(ft, query_str)
	local ts = vim.treesitter
	local ok, query = pcall(ts.query.parse, ft, query_str)
	if not ok then
		M.notify_error("Query parsing", "Invalid query: " .. tostring(query), config.NOTIFY_LEVELS.warn)
		return nil
	end
	return query
end

--- Center view after cursor movement
function M.center_view()
	vim.cmd("normal! zz")
end

--- Convert 0-indexed row to 1-indexed for display
--- @param row integer: 0-indexed row
--- @return integer: 1-indexed row
function M.row_to_display(row)
	return row + 1
end

--- Convert 1-indexed row to 0-indexed for internal use
--- @param row integer: 1-indexed row
--- @return integer: 0-indexed row
function M.row_from_display(row)
	return row - 1
end

return M
