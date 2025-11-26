--- Configuration module for debug_print plugin
--- Contains all constants, settings, and configuration values

local M = {}

--- Supported file types for debug statement detection
M.SUPPORTED_FILETYPES = {
	"javascript",
	"typescript",
	"javascriptreact",
	"typescriptreact",
}

--- Console methods supported by the plugin
M.CONSOLE_METHODS = {
	"log",
	"warn",
	"error",
	"debug",
}

--- Keymap configuration
M.KEYMAPS = {
	next_all = "g?n",
	prev_all = "g?N",
	next_log = "g?l",
	prev_log = "g?L",
	next_warn = "g?w",
	prev_warn = "g?W",
	delete = "<leader>dil",
}

--- User command names
M.COMMANDS = {
	next_log = "DebugprintNextLog",
	prev_log = "DebugprintPrevLog",
	next_warn = "DebugprintNextWarn",
	prev_warn = "DebugprintPrevWarn",
	next_all = "DebugprintNextAll",
	prev_all = "DebugprintPrevAll",
}

--- Notification levels for different message types
M.NOTIFY_LEVELS = {
	info = vim.log.levels.INFO,
	warn = vim.log.levels.WARN,
	error = vim.log.levels.ERROR,
}

return M
