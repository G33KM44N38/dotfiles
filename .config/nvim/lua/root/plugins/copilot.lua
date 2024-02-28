return {
	'github/copilot.vim',
	init = function()
		vim.g.copilot_no_tab_map = true
	end,
	config = function()
		vim.keymap.set('i', '<C-y>', [[copilot#Accept("\<CR>")]], {
			silent = true,
			expr = true,
			script = true,
			replace_keycodes = false,
		})
	end,
}

-- return {
-- 	"zbirenbaum/copilot.lua",
-- 	config = function()
-- 		require("copilot").setup({
-- 			suggestion = { enabled = false },
-- 			panel = { enabled = false },
-- 		})
-- 	end
-- }
