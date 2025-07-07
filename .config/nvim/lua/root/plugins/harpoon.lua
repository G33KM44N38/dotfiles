return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"ThePrimeagen/git-worktree.nvim", -- Ensure this is listed as a dependency
	},
	settings = {
		save_on_toggle = false,
		sync_on_ui_close = true,
		-- IMPORTANT: Updated 'key' function to use get_current_worktree_path()
		key = function()
			local git_worktree = require("git-worktree")
			local current_worktree = git_worktree.get_current_worktree_path()
			if current_worktree then
				return current_worktree
			else
				-- Fallback to vim.fn.getcwd() for robustness
				return vim.fn.getcwd()
			end
		end,
	},
	config = function()
		local harpoon = require("harpoon")

		vim.keymap.set("n", "<leader>a", function()
			harpoon:list():add()
		end, { desc = "Add file to Harpoon list" })
		vim.keymap.set("n", "<C-e>", function()
			harpoon.ui:toggle_quick_menu(harpoon:list())
		end, { desc = "Toggle Harpoon quick menu" })

		vim.keymap.set("n", "<C-h>", function()
			harpoon:list():select(1)
		end, { desc = "Navigate to Harpoon file 1" })
		vim.keymap.set("n", "<C-j>", function()
			harpoon:list():select(2)
		end, { desc = "Navigate to Harpoon file 2" })
		vim.keymap.set("n", "<C-k>", function()
			harpoon:list():select(3)
		end, { desc = "Navigate to Harpoon file 3" })
		vim.keymap.set("n", "<C-l>", function()
			harpoon:list():select(4)
		end, { desc = "Navigate to Harpoon file 4" })

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
	end,
}
