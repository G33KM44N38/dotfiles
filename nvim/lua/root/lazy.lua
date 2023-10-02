local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)


require("lazy").setup({
	{ import = "root.plugins" },
	{ import = "root.plugins.lsp" },
}, {
	install = {
	},
	checker = {
		enabled = true,
		notify = false, -- get a notification when new updates are found
		-- frequency = 3600, -- check for updates every hour

	},
	change_detection = {
		notify = false,
	},
})
