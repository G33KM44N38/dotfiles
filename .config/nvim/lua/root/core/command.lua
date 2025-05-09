vim.api.nvim_create_user_command("FoldCurrentLevel", function()
	vim.cmd("normal! zMzv")
end, {})
