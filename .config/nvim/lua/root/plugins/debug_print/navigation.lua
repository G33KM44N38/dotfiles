--- Navigation module for debug_print plugin
--- Handles navigation between debug statements (next/previous)

local utils = require("root.plugins.debug_print.utils")
local config = require("root.plugins.debug_print.config")
local tree_sitter = require("root.plugins.debug_print.tree_sitter")

local M = {}

--- State management for navigation
local debug_calls = {}
local current_index = 0

--- Navigate to the next debug call of specified type
--- @param method_type string: "all" | "log" | "warn" | "error" | "debug"
function M.go_to_next_debug(method_type)
	method_type = method_type or "all"
	debug_calls = tree_sitter.find_debug_calls(method_type)

	if #debug_calls == 0 then
		utils.notify("No " .. method_type .. " calls found", config.NOTIFY_LEVELS.warn)
		return
	end

	local current_row, current_col = utils.get_cursor_position()

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
	utils.set_cursor_position(target.row, target.col)
	utils.center_view()
	utils.notify(string.format("Debug call %d/%d", current_index, #debug_calls), config.NOTIFY_LEVELS.info)
end

--- Navigate to the previous debug call of specified type
--- @param method_type string: "all" | "log" | "warn" | "error" | "debug"
function M.go_to_prev_debug(method_type)
	method_type = method_type or "all"
	debug_calls = tree_sitter.find_debug_calls(method_type)

	if #debug_calls == 0 then
		utils.notify("No " .. method_type .. " calls found", config.NOTIFY_LEVELS.warn)
		return
	end

	local current_row, current_col = utils.get_cursor_position()

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
	utils.set_cursor_position(target.row, target.col)
	utils.center_view()
	utils.notify(string.format("Debug call %d/%d", current_index, #debug_calls), config.NOTIFY_LEVELS.info)
end

return M
