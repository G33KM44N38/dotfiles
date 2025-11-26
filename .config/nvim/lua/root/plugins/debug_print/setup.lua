--- Main orchestration module for debug_print plugin
--- Registers all keymaps and user commands

local navigation = require("root.plugins.debug_print.navigation")
local deletion = require("root.plugins.debug_print.deletion")
local config = require("root.plugins.debug_print.config")

local M = {}

--- Register all keymaps for debug navigation and deletion
function M.register_keymaps()
	-- Navigation keymaps - All console methods
	vim.keymap.set("n", config.KEYMAPS.next_all, function()
		navigation.go_to_next_debug("all")
	end, { noremap = true, silent = true })

	vim.keymap.set("n", config.KEYMAPS.prev_all, function()
		navigation.go_to_prev_debug("all")
	end, { noremap = true, silent = true })

	-- Navigation keymaps - log methods
	vim.keymap.set("n", config.KEYMAPS.next_log, function()
		navigation.go_to_next_debug("log")
	end, { noremap = true, silent = true })

	vim.keymap.set("n", config.KEYMAPS.prev_log, function()
		navigation.go_to_prev_debug("log")
	end, { noremap = true, silent = true })

	-- Navigation keymaps - warn methods
	vim.keymap.set("n", config.KEYMAPS.next_warn, function()
		navigation.go_to_next_debug("warn")
	end, { noremap = true, silent = true })

	vim.keymap.set("n", config.KEYMAPS.prev_warn, function()
		navigation.go_to_prev_debug("warn")
	end, { noremap = true, silent = true })

	-- Deletion keymap
	vim.keymap.set("n", config.KEYMAPS.delete, function()
		deletion.delete_debug_at_cursor()
	end, { noremap = true, silent = true })
end

--- Register all user commands for debug operations
function M.register_commands()
	vim.api.nvim_create_user_command(config.COMMANDS.next_log, function()
		navigation.go_to_next_debug("log")
	end, {})

	vim.api.nvim_create_user_command(config.COMMANDS.prev_log, function()
		navigation.go_to_prev_debug("log")
	end, {})

	vim.api.nvim_create_user_command(config.COMMANDS.next_warn, function()
		navigation.go_to_next_debug("warn")
	end, {})

	vim.api.nvim_create_user_command(config.COMMANDS.prev_warn, function()
		navigation.go_to_prev_debug("warn")
	end, {})

	vim.api.nvim_create_user_command(config.COMMANDS.next_all, function()
		navigation.go_to_next_debug("all")
	end, {})

	vim.api.nvim_create_user_command(config.COMMANDS.prev_all, function()
		navigation.go_to_prev_debug("all")
	end, {})
end

--- Initialize the debug_print plugin
function M.setup()
	M.register_keymaps()
	M.register_commands()
end

return M
