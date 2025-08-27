return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		files = {
			-- Use 'fd' with exclude options
			cmd = "fd --type f --hidden --exclude node_modules --exclude dist",
		},
		grep = {
			-- Use 'rg' with glob exclude patterns
			rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob '!node_modules/*' --glob '!dist/*'",
		},
	},
	config = function()
		local opts = { noremap = true, silent = true }

		if vim.g.vscode then
			-- VS Code specific keymaps
			vim.keymap.set("n", "<C-p>", function()
				vim.fn.VSCodeNotify("extension.fuzzySearch")
			end, opts)

			vim.keymap.set("n", "<C-s>", function()
				vim.fn.VSCodeNotify("workbench.action.findInFiles")
			end, opts)

			vim.keymap.set("n", "gi", function()
				vim.fn.VSCodeNotify("editor.action.goToImplementation")
			end, opts)

			vim.keymap.set("n", "gd", function()
				vim.fn.VSCodeNotify("editor.action.revealDefinition")
			end, opts)

			vim.keymap.set("n", "gr", function()
				vim.fn.VSCodeNotify("editor.action.goToReferences")
			end, opts)

			vim.keymap.set({ "n", "v" }, "<leader>c", function()
				vim.fn.VSCodeNotify("editor.action.quickFix")
			end, { desc = "VSCode Code Actions" })

			return
		end

		-- Neovim native (fzf-lua)
		local fzf = require("fzf-lua")

		fzf.hidden_files_lua = function()
			local hidden_files = {}

			local function scan_dir(dir)
				local fs = vim.loop.fs_scandir(dir)
				if not fs then
					return
				end

				while true do
					local name, type = vim.loop.fs_scandir_next(fs)
					if not name then
						break
					end

					local full_path = dir .. "/" .. name

					-- Ignore node_modules and dist
					if name == "node_modules" or name == "dist" then
						goto continue
					end

					-- If file is hidden and is a file, add to results
					if name:sub(1, 1) == "." then
						if type == "file" then
							table.insert(hidden_files, full_path)
						elseif type == "directory" then
							scan_dir(full_path)
						end
					else
						-- Still scan non-hidden directories (like .git inside .config)
						if type == "directory" then
							scan_dir(full_path)
						end
					end

					::continue::
				end
			end

			scan_dir(".")

			require("fzf-lua").fzf_exec(hidden_files, {
				prompt = "Hidden Files> ",
				actions = require("fzf-lua").defaults.actions.files,
			})
		end

		vim.api.nvim_set_keymap("n", "<leader>hi", "<cmd>lua require('fzf-lua').hidden_files_lua()<CR>", opts)

		vim.keymap.set("n", "<leader>sw", "<cmd>FzfLua lsp_workspace_symbols<CR>", { desc = "Workspace Symbols" })
		vim.api.nvim_set_keymap("n", "gi", "<cmd>FzfLua lsp_implementations<CR>", opts)
		vim.api.nvim_set_keymap("n", "gt", "<cmd>FzfLua lsp_typedefs<CR>", opts) -- Go to type definition
		vim.api.nvim_set_keymap("n", "gd", "<cmd>FzfLua lsp_definitions<CR>", opts)
		vim.api.nvim_set_keymap("n", "gr", "<cmd>FzfLua lsp_references<CR>", opts)
		vim.api.nvim_set_keymap("n", "<C-p>", "<cmd>FzfLua files<CR>", opts)
		vim.api.nvim_set_keymap("n", "<C-s>", "<cmd>FzfLua grep<CR>", opts)
		vim.api.nvim_set_keymap("n", "<leader>fb", "<cmd>FzfLua buffers<CR>", opts)
		vim.api.nvim_set_keymap("n", "<leader>ke", "<cmd>FzfLua keymaps<CR>", opts)
		vim.keymap.set({ "n", "v" }, "<leader>c", "<cmd>FzfLua lsp_code_actions<CR>", { desc = "Code Actions" })
	end,
}
