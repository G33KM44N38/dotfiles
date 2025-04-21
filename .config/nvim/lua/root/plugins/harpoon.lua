return {
	'ThePrimeagen/harpoon',
	branch = 'harpoon2',
	dependencies = { 'nvim-lua/plenary.nvim' },
	settings = {
		save_on_toggle = false,
		sync_on_ui_close = true,
	},
	config = function()
		local harpoon = require('harpoon')

		vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end,
			{ desc = "Add file to Harpoon list" })
		vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end,
			{ desc = "Toggle Harpoon quick menu" })

		vim.keymap.set("n", "<C-h>", function() harpoon:list():select(1) end,
			{ desc = "Navigate to Harpoon file 1" })
		vim.keymap.set("n", "<C-j>", function() harpoon:list():select(2) end,
			{ desc = "Navigate to Harpoon file 2" })
		vim.keymap.set("n", "<C-k>", function() harpoon:list():select(3) end,
			{ desc = "Navigate to Harpoon file 3" })
		vim.keymap.set("n", "<C-l>", function() harpoon:list():select(4) end,
			{ desc = "Navigate to Harpoon file 4" })

		harpoon:extend({
			UI_CREATE = function(cx)
				vim.keymap.set("n", "<C-v>", function()
					harpoon.ui:select_menu_item({ vsplit = true })
				end, { buffer = cx.bufnr })

				vim.keymap.set("n", "<C-x>", function()
					harpoon.ui:select_menu_item({ split = true })
				end, { buffer = cx.bufnr })
			end,
		})
	end
}
