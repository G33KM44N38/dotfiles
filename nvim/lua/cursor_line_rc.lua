local status, cursor = pcall(require, 'nvim-cursorline')
if (not status)then return end

cursor.setup{
	cursorline = {
		enable = true,
		timeout = 10,
		number = false,
	},
	cursorword = {
		enable = true,
		min_length = 3,
    		hl = { underline = true },
	}
}
