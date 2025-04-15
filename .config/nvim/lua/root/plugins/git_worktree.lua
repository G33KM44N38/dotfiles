local function harpoon_sync_worktree()
	local harpoon = require('harpoon')
	local list = harpoon:list().items
	for index, item in ipairs(list) do
		print(index, vim.inspect(item.value))
		harpoon:list().add(item)
	end
end

-- Function to synchronize submodules to match the root branch
local function sync_submodules_to_root_branch()
	-- Initialize and update submodules first
	print("Initializing and updating submodules...")
	os.execute("git submodule init > /dev/null 2>&1")
	os.execute("git submodule update > /dev/null 2>&1")

	-- Get the current branch name
	local current_branch_handle = io.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null")
	if not current_branch_handle then return end

	local current_branch = current_branch_handle:read("*a")
	current_branch_handle:close()

	if not current_branch then return end
	current_branch = current_branch:gsub("%s+$", "")

	if current_branch == "" then
		print("Could not determine current branch")
		return
	end

	-- Get list of submodules
	local submodules_handle = io.popen("git submodule foreach --quiet 'echo $name'")
	if not submodules_handle then return end

	local submodules_output = submodules_handle:read("*a")
	submodules_handle:close()

	if not submodules_output then return end

	local submodules = {}
	for submodule in submodules_output:gmatch("[^\r\n]+") do
		table.insert(submodules, submodule)
	end

	if #submodules == 0 then
		print("No submodules found")
		return
	end

	print("Synchronizing submodules to branch: " .. current_branch)

	-- Try to check out the same branch in each submodule
	for _, submodule in ipairs(submodules) do
		-- Fetch the latest from remote first
		print("Fetching latest updates for submodule " .. submodule)
		local fetch_cmd = string.format("cd '%s' && git fetch > /dev/null 2>&1", submodule)
		os.execute(fetch_cmd)

		-- First verify if the branch exists in the submodule
		local check_branch_cmd = string.format(
			"cd '%s' && git rev-parse --verify refs/heads/%s >/dev/null 2>&1 && echo 'exists' || echo 'not_exists'",
			submodule, current_branch)
		local branch_exists_handle = io.popen(check_branch_cmd)
		if not branch_exists_handle then
			print("Failed to check branch in submodule " .. submodule)
			goto continue
		end

		local branch_exists = branch_exists_handle:read("*a")
		branch_exists_handle:close()

		if not branch_exists then
			print("Failed to read branch status in submodule " .. submodule)
			goto continue
		end

		branch_exists = branch_exists:gsub("%s+$", "")

		if branch_exists == "exists" then
			print("Switching submodule " .. submodule .. " to branch " .. current_branch)
			local checkout_cmd = string.format("cd '%s' && git checkout %s > /dev/null 2>&1", submodule,
				current_branch)
			os.execute(checkout_cmd)

			-- Pull latest changes from remote
			print("Pulling latest changes for submodule " .. submodule)
			local pull_cmd = string.format("cd '%s' && git pull origin %s > /dev/null 2>&1", submodule, current_branch)
			os.execute(pull_cmd)
		else
			print("Branch " .. current_branch .. " does not exist in submodule " .. submodule)

			-- Try to check if the branch exists on the remote
			local remote_branch_cmd = string.format(
				"cd '%s' && git ls-remote --heads origin %s | grep -q %s && echo 'exists' || echo 'not_exists'",
				submodule, current_branch, current_branch)
			local remote_exists_handle = io.popen(remote_branch_cmd)
			if remote_exists_handle then
				local remote_exists = remote_exists_handle:read("*a")
				remote_exists_handle:close()

				if remote_exists and remote_exists:gsub("%s+$", "") == "exists" then
					print("Branch exists on remote. Creating and tracking in submodule " .. submodule)
					local create_cmd = string.format(
						"cd '%s' && git checkout -b %s --track origin/%s > /dev/null 2>&1",
						submodule, current_branch, current_branch)
					os.execute(create_cmd)
				end
			end
		end

		::continue::
	end
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
				os.execute("tmux kill-window -t 2")
				os.execute("tmux kill-window -t 3")
				os.execute("tmux new-window -n code")
				os.execute("tmux new-window -n process")
				os.execute("tmux select-window -t 1")
			end

			vim.api.nvim_set_keymap("n", "<leader>ws",
				":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", opts)
			vim.api.nvim_set_keymap("n", "<leader>wc",
				":lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>", opts)
			vim.api.nvim_set_keymap("n", "<leader>wt",
				":lua require('telescope').extensions.git_worktree.git_worktrees()<CR>", opts)

			Worktree.on_tree_change(function(op, metadata)
				if op == Worktree.Operations.Switch then
					harpoon_sync_worktree()
					vim.api.nvim_command("LspRestart")

					-- Update tmux windows in the current client to the new worktree path
					update_tmux_windows()

					-- Synchronize submodules to match the same branch as the root
					sync_submodules_to_root_branch()

					-- Set the current directory for Neovim and Oil
					vim.api.nvim_set_current_dir(metadata.path)

					-- If oil is loaded, refresh it to show the new directory
					local oil_loaded, oil = pcall(require, "oil")
					if oil_loaded then
						-- Close any open oil buffers first
						for _, buf in ipairs(vim.api.nvim_list_bufs()) do
							if vim.bo[buf].filetype == "oil" then
								vim.api.nvim_buf_delete(buf, { force = true })
							end
						end
						-- Open oil in the new directory
						vim.defer_fn(function()
							oil.open(metadata.path)
						end, 100)
					end
				end
			end)
		end
	end
}
