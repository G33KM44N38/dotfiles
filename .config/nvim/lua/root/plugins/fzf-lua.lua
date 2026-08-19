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
		local workspace_path = "/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/"

		-- Neovim native (fzf-lua)
		local fzf = require("fzf-lua")

		local function normalize_path(path)
			if path:sub(-1) ~= "/" then
				path = path .. "/"
			end
			return path
		end

		local function path_is_under(path, target_path)
			if not path or path == "" then
				return false
			end

			path = normalize_path(vim.fs.normalize(path))
			target_path = normalize_path(vim.fs.normalize(target_path))

			return path:sub(1, #target_path) == target_path
		end

		local function in_obsidian_workspace()
			local current_file = vim.api.nvim_buf_get_name(0)
			if path_is_under(current_file, workspace_path) then
				return true
			end

			return path_is_under(vim.fn.getcwd(), workspace_path)
		end

		local function run_command_lines(cmd, cwd)
			local shell_cmd = cmd .. " 2>/dev/null"
			if cwd then
				shell_cmd = "cd " .. vim.fn.shellescape(cwd) .. " && " .. shell_cmd
			end

			local lines = vim.fn.systemlist(shell_cmd)
			if vim.v.shell_error ~= 0 then
				return {}
			end

			return lines
		end

		local function merge_unique_lists(...)
			local merged = {}
			local seen = {}

			for _, list in ipairs({ ... }) do
				for _, item in ipairs(list) do
					if item ~= "" and not seen[item] then
						seen[item] = true
						table.insert(merged, item)
					end
				end
			end

			return merged
		end

		local function smart_files()
			local is_obsidian = in_obsidian_workspace()
			local search_cwd = is_obsidian and workspace_path or vim.fn.getcwd()
			local fd_cmd = is_obsidian and "fd --type f --extension md --exclude Attachments --exclude .obsidian --exclude .smart-env --exclude .opencode"
				or "fd --type f --hidden --exclude node_modules --exclude dist"
			local tracked_ignored_cmd = "git ls-files -ci --exclude-standard"
			local picker_opts = {
				previewer = "builtin",
				winopts = {
					preview = {
						hidden = false,
					},
				},
			}

			if is_obsidian then
				tracked_ignored_cmd = tracked_ignored_cmd .. " -- " .. vim.fn.shellescape("*.md")
			end

			local tracked_ignored = run_command_lines(tracked_ignored_cmd, search_cwd)

			if #tracked_ignored == 0 then
				if is_obsidian then
					fzf.files(vim.tbl_deep_extend("force", picker_opts, {
						cmd = fd_cmd,
						cwd = workspace_path,
					}))
				else
					fzf.files(picker_opts)
				end
				return
			end

			local visible_files = run_command_lines(fd_cmd, search_cwd)
			local files = merge_unique_lists(visible_files, tracked_ignored)

			fzf.fzf_exec(
				files,
				vim.tbl_deep_extend("force", picker_opts, {
					cwd = search_cwd,
					prompt = "Files> ",
					actions = fzf.defaults.actions.files,
				})
			)
		end

		local function smart_grep(live)
			if not in_obsidian_workspace() then
				if live then
					fzf.live_grep()
				else
					fzf.grep()
				end
				return
			end

			local picker = live and fzf.live_grep or fzf.grep
			picker({
				cwd = workspace_path,
				rg_opts = table.concat({
					"--column",
					"--line-number",
					"--no-heading",
					"--color=always",
					"--smart-case",
					"--glob '*.md'",
					"--glob '!Attachments/**'",
					"--glob '!.obsidian/**'",
					"--glob '!.smart-env/**'",
					"--glob '!.opencode/**'",
				}, " "),
				previewer = "builtin",
			})
		end

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
			fzf.files({
				cmd = "fd --type f --hidden --follow --exclude node_modules",
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
		vim.keymap.set("n", "<C-p>", smart_files, opts)
		vim.keymap.set("n", "<C-s>", function()
			smart_grep(false)
		end, opts)
		vim.keymap.set("n", "<C-q>", function()
			smart_grep(true)
		end, opts)
		vim.api.nvim_set_keymap("n", "<leader>fb", "<cmd>FzfLua buffers<CR>", opts)
		vim.api.nvim_set_keymap("n", "<leader>ke", "<cmd>FzfLua keymaps<CR>", opts)
		vim.api.nvim_set_keymap("n", "<leader>ds", "<cmd>FzfLua lsp_document_symbols<CR>", opts)
		vim.keymap.set({ "n", "v" }, "<leader>c", "<cmd>FzfLua lsp_code_actions<CR>", { desc = "Code Actions" })
	end,
}
