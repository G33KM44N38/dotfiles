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

		-- Neovim native (fzf-lua)
		local fzf = require("fzf-lua")

		fzf.staged_files_live_grep = function()
			-- get staged files
			local handle = io.popen("git diff --name-only --cached --diff-filter=ACMRTUXB")
			if not handle then
				return
			end
			local result = handle:read("*a")
			handle:close()
			if result == "" then
				print("No staged files.")
				return
			end
			-- split into Lua table (newline separated)
			local files = {}
			for s in result:gmatch("[^\n]+") do
				table.insert(files, s)
			end
			-- build a pattern string for rg to restrict to these files
			-- use --files-from-style: prepare a temporary file with paths and pass to rg via --files-from
			local tmpname = vim.fn.tempname()
			local f = io.open(tmpname, "w")
			for _, p in ipairs(files) do
				f:write(p .. "\n")
			end
			f:close()
			-- call fzf-lua grep with rg, restricting files via --files-from
			local fzf = require("fzf-lua")
			fzf.grep({
				rg_opts = "--line-number --hidden --smart-case --files-from " .. tmpname,
				rg_glob = nil, -- disable glob
				previewer = "bat", -- optional: bat preview
				-- you can pass any fzf-lua opts here
			})
			-- remove temp file after a short delay (so rg can read it)
			vim.defer_fn(function()
				os.remove(tmpname)
			end, 500)
		end

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

		vim.keymap.set(
			"n",
			"<leader>sg",
			"<cmd>lua require('fzf-lua').staged_files_live_grep()<CR>",
			{ desc = "Live grep staged files" }
		)
		vim.keymap.set("n", "<leader>sw", "<cmd>FzfLua lsp_workspace_symbols<CR>", { desc = "Workspace Symbols" })
		vim.api.nvim_set_keymap("n", "gi", "<cmd>FzfLua lsp_implementations<CR>", opts)
		vim.api.nvim_set_keymap("n", "gt", "<cmd>FzfLua lsp_typedefs<CR>", opts) -- Go to type definition
		vim.api.nvim_set_keymap("n", "gd", "<cmd>FzfLua lsp_definitions<CR>", opts)
		vim.api.nvim_set_keymap("n", "gr", "<cmd>FzfLua lsp_references<CR>", opts)
		vim.api.nvim_set_keymap("n", "<C-p>", "<cmd>lua require('root.plugins.obsidian').smart_files()<CR>", opts)
		vim.api.nvim_set_keymap("n", "<C-s>", "<cmd>FzfLua grep<CR>", opts)
		vim.api.nvim_set_keymap("n", "<C-q>", "<cmd>FzfLua live_grep<CR>", opts)
		vim.api.nvim_set_keymap("n", "<leader>fb", "<cmd>FzfLua buffers<CR>", opts)
		vim.api.nvim_set_keymap("n", "<leader>ke", "<cmd>FzfLua keymaps<CR>", opts)
		vim.keymap.set({ "n", "v" }, "<leader>c", "<cmd>FzfLua lsp_code_actions<CR>", { desc = "Code Actions" })
	end,
}
