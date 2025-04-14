return {
	"tpope/vim-dadbod",
	"kristijanhusak/vim-dadbod-completion",
	{
		"kristijanhusak/vim-dadbod-ui",
		config = function()
			vim.api.nvim_set_keymap("n", "<leader>dbt", "<cmd>DBUIToggle<CR>", {})
		end
	}
}
