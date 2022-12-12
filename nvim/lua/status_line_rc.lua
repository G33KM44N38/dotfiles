local status, line = pcall(require, 'lualine')
if (not status) then return end

local function mac()
  return [[  ]]
end

line.setup {
	options = {
		icons_enabled = true,
		theme = 'solarized_dark',
		component_separators = { left = '', right = ''},
		section_separators = { left = '', right = ''},
		disabled_filetypes = {
		  statusline = {},
		  winbar = {},
		},
		ignore_focus = {},
		always_divide_middle = true,
		globalstatus = false,
		refresh = {
		  statusline = 1000,
		  tabline = 1000,
		  winbar = 1000,
		}
	},
	sections = {
		lualine_a = {'mode'},
    		lualine_b = {'branch'},
		lualine_c = {'filename', 'diagnostics'},
    		lualine_x = {mac},
		lualine_y = {'progress', 'location'},
		lualine_z = {"os.date('%H:%M:%S')"}
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = {'filename'},
		lualine_x = {'location'},
		lualine_y = {},
		lualine_z = {}
	},
	symbols = {
        	modified = ' ●',      -- Text to show when the buffer is modified
        	alternate_file = '#', -- Text to show to identify the alternate file
        	directory =  '',     -- Text to show when the buffer is a directory
         },
	tabline = {},
	winbar = {},
	inactive_winbar = {},
	extensions = {}
}
