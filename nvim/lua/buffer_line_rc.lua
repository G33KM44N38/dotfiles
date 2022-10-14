local status, bufferline = pcall(require, 'bufferline')
if (not status) then return end

bufferline.setup{
	options = {
		mode = 'buffers',
		separator_style = 'padded_slant',
		always_show_bufferline = true,
		show_close_icon = true,
		color_icons = true,
    		buffer_close_icon = '',
	},
	highlights = {
        	tab = {
        	    fg = '#002b36',
        	    bg = '#002b36'
        	},
        	close_button = {
        	    fg = '#ffffff',
        	    bg = '#002b36'
        	},
        	close_button_visible = {
        	    fg = '#EE3B31',
        	    bg = '#002b36'
        	},
        	close_button_selected = {
        	    fg = '#EE3B31',
        	    bg = '#002b36'
        	},
        	buffer_visible = {
        	    fg = '#13A6DA',
        	    bg = '#002b36'
        	},
        	buffer_selected = {
		    fg = '#FF6C37',
        	    bg = '#002b36',
        	},
		separator = {
			fg = '#073642',
			bg = '#002b36',
		},
		separator_selected = {
			fg = '#073642',
	},
        };

}
