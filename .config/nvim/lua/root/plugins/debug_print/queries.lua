--- Tree-sitter query definitions for debug_print plugin
--- Contains all the declarative tree-sitter query strings

local M = {}

--- Build a tree-sitter query for finding console method calls
--- @param methods table|nil: Array of method names to match, or nil for all console methods
--- @return string: Tree-sitter query string
function M.build_console_query(methods)
	if not methods or #methods == 0 then
		return M.QUERY_ALL_METHODS
	elseif #methods == 1 then
		return M:build_single_method_query(methods[1])
	else
		return M:build_multi_method_query(methods)
	end
end

--- Query for all console methods (log, warn, error, debug)
M.QUERY_ALL_METHODS = [[
	(call_expression
		function: (member_expression
			object: (identifier) @console (#eq? @console "console")
			property: (property_identifier) @method (#any-of? @method "log" "warn" "error" "debug"))
		arguments: (arguments) @args) @call
]]

--- Build query for a single console method
--- @param method string: Method name (e.g., "log", "warn")
--- @return string: Tree-sitter query string
function M:build_single_method_query(method)
	return string.format(
		[[
	(call_expression
		function: (member_expression
			object: (identifier) @console (#eq? @console "console")
			property: (property_identifier) @method (#eq? @method "%s"))
		arguments: (arguments) @args) @call
]],
		method
	)
end

--- Build query for multiple console methods
--- @param methods table: Array of method names
--- @return string: Tree-sitter query string
function M:build_multi_method_query(methods)
	local method_list = table.concat(methods, '" "')
	return string.format(
		[[
	(call_expression
		function: (member_expression
			object: (identifier) @console (#eq? @console "console")
			property: (property_identifier) @method (#any-of? @method "%s"))
		arguments: (arguments) @args) @call
]],
		method_list
	)
end

return M
