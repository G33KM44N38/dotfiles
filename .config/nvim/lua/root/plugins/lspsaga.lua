return {
	"nvimdev/lspsaga.nvim",
	branch = "main",
	config = function()
		require("lspsaga").setup({})

		local opts = { noremap = true, silent = true }

		vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts)

		vim.keymap.set("n", "]d", "<cmd>Lspsaga diagnostic_jump_next<CR>", { desc = "Go to next diagnostic" })

		vim.keymap.set("n", "[d", "<cmd>Lspsaga diagnostic_jump_prev<CR>", { desc = "Go to previous diagnostic" })

		-- go to definition in a vertical split
		vim.keymap.set("n", "gsd", function()
			vim.cmd("vsplit")
			vim.cmd("Lspsaga goto_definition")
		end, { desc = "Go to definition in a vertical split" })

		-- example: horizontal split
		vim.keymap.set("n", "<leader>gsD", function()
			vim.cmd("split")
			vim.cmd("Lspsaga goto_definition")
		end, { desc = "Go to definition in a horizontal split" })
	end,
}
