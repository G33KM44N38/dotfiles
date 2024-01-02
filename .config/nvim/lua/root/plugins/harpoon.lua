return {
	'ThePrimeagen/harpoon',
	config = function()
		local success1, mark = pcall(require, "harpoon.mark")
		local success2, ui = pcall(require, "harpoon.ui")

		if success1 and success2 then
			vim.keymap.set("n", "<leader>a", mark.add_file)
			vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)
			vim.keymap.set("n", "<C-k>", function() ui.nav_file(1) end)
			vim.keymap.set("n", "<C-m>", function() ui.nav_file(2) end)
			vim.keymap.set("n", "<C-h>", function() ui.nav_file(3) end)
			vim.keymap.set("n", "<C-n>", function() ui.nav_file(4) end)
		else
			print("Error loading Harpoon mark or UI module")
		end
	end
}
