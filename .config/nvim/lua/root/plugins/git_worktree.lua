local function harpoon_sync_worktree()
	local harpoon = require('harpoon')
	local list = harpoon:list().items
	for index, item in ipairs(list) do
		harpoon:list().add(item)
	end
end

-- Function to run shell commands asynchronously
local function async_exec(cmd, callback)
	vim.fn.jobstart(cmd, {
		on_exit = function(_, code)
			if callback then
				callback(code == 0)
			end
		end,
		stdout_buffered = true,
		stderr_buffered = true
	})
end

-- Function to synchronize submodules to match the root branch
local function sync_submodules_to_root_branch()
	-- Initialize and update submodules first
	print("Initializing and updating submodules...")

	-- Run submodule initialization in background
	async_exec("git submodule init > /dev/null 2>&1", function(success)
		if not success then return end

		async_exec("git submodule update --jobs=8 > /dev/null 2>&1", function(success)
			if not success then return end

			-- Get the current branch name
			vim.fn.jobstart("git rev-parse --abbrev-ref HEAD 2>/dev/null", {
				on_stdout = function(_, data)
					if not data or #data < 1 or data[1] == "" then return end

					local current_branch = data[1]:gsub("%s+$", "")

					-- Get list of submodules
					vim.fn.jobstart("git submodule foreach --quiet 'echo $name'", {
						on_stdout = function(_, submodule_data)
							if not submodule_data or #submodule_data < 1 then
								print("No submodules found")
								return
							end

							local submodules = {}
							for _, line in ipairs(submodule_data) do
								if line and line ~= "" then
									table.insert(submodules, line)
								end
							end

							if #submodules == 0 then
								print("No submodules found")
								return
							end

							print("Synchronizing submodules to branch: " .. current_branch)

							-- Process submodules in parallel by launching jobs
							for _, submodule in ipairs(submodules) do
								-- Fetch and branch check in one command for efficiency
								local cmd = string.format(
									"cd '%s' && git fetch -q && " ..
									"(git rev-parse --verify refs/heads/%s >/dev/null 2>&1 && " ..
									"(git checkout %s > /dev/null 2>&1 && git pull -q origin %s > /dev/null 2>&1 && " ..
									"echo 'Switched and updated %s to branch %s') || " ..
									"(git ls-remote --heads origin %s | grep -q %s && " ..
									"git checkout -b %s --track origin/%s > /dev/null 2>&1 && " ..
									"echo 'Created tracking branch %s in %s') || " ..
									"echo 'Branch %s does not exist for %s')",
									submodule, current_branch,
									current_branch, current_branch,
									submodule, current_branch,
									current_branch, current_branch,
									current_branch, current_branch,
									current_branch, submodule,
									current_branch, submodule
								)

								vim.fn.jobstart(cmd, {
									on_stdout = function(_, output)
										if output and #output > 0 and output[1] ~= "" then
											print(output[1])
										end
									end
								})
							end
						end,
						stdout_buffered = true
					})
				end,
				stdout_buffered = true
			})
		end)
	end)
end

return {
	"ThePrimeagen/git-worktree.nvim",
	dependencies = {
		'ThePrimeagen/harpoon',
		branch = 'harpoon2',
	},
	config = function()
		local harpoon = require('harpoon')
		if vim.g.vscode then
			vim.keymap.set("n", "<leader>ws", function()
				require('vscode').action('git-worktree.list')
			end)
			vim.keymap.set("n", "<leader>wc", function()
				require('vscode').action('git-worktree.add')
			end)
			vim.keymap.set("n", "<leader>wd", function()
				require('vscode').action('git-worktree.remove')
			end)
		else
			require("telescope").load_extension("git_worktree")
			local Worktree = require("git-worktree")
			local opts = { noremap = true, silent = true }

			-- Function to update tmux windows in the current client
			local function update_tmux_windows()
				async_exec(
					"tmux kill-window -t 2 2>/dev/null; tmux kill-window -t 3 2>/dev/null; tmux new-window -n code; tmux new-window -n process; tmux select-window -t 1")
			end

			vim.api.nvim_set_keymap("n", "<leader>ws",
				":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", opts)
			vim.api.nvim_set_keymap("n", "<leader>wc",
				":lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>", opts)
			vim.api.nvim_set_keymap("n", "<leader>wt",
				":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", opts)

			Worktree.on_tree_change(function(op, metadata)
				if op == Worktree.Operations.Switch then
					-- Execute tasks in parallel for speed

					-- Task 1: Synchronize harpoon
					-- harpoon_sync_worktree()

					-- Task 2: Restart LSP (after a short delay to let disk operations complete)
					vim.defer_fn(function()
						vim.api.nvim_command("LspRestart")
					end, 500)

					-- Task 3: Update tmux windows
					update_tmux_windows()

					-- -- Task 4: Update current directory and oil
					-- vim.api.nvim_set_current_dir(metadata.path)
					-- local oil_loaded, oil = pcall(require, "oil")
					-- if oil_loaded then
					-- 	vim.defer_fn(function()
					-- 		-- Only close oil buffers if they exist
					-- 		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					-- 			if vim.bo[buf].filetype == "oil" then
					-- 				vim.api.nvim_buf_delete(buf, { force = true })
					-- 				break -- Only need to close one oil buffer
					-- 			end
					-- 		end
					-- 		oil.open(metadata.path)
					-- 	end, 300)
					-- end

					-- Task 5: Synchronize submodules (in background)
					sync_submodules_to_root_branch()

					print("Switched to worktree: " .. metadata.path)
				end
			end)
		end
	end
}
