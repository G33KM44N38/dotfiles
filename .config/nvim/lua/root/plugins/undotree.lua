return {
	"mbbill/undotree",
	config = function()
		vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
		vim.o.undofile = true

		vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
			desc = "Disable persistent undo for directory buffers",
			callback = function(args)
				if vim.fn.isdirectory(args.file) == 1 then
					vim.bo[args.buf].undofile = false
				end
			end,
		})
	end,
}
