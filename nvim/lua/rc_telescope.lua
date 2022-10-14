local M = {}
M.search_dotfiles = function()
	require("telescope.builtin").find_files({
		prompt_title = "< Dotfiles >",
		cwd = "~/.dotfiles/.config/",
	})
end

M.config = function()
	require("telescope.builtin").find_files({
		prompt_title = "< Config >",
		cmd = "~/.dotfiles/.config/config/",
	})
end
return M

