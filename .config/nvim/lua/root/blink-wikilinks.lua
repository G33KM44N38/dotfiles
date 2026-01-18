-- Custom blink.cmp source for Obsidian wiki-style links [[filename]]
-- Searches your Obsidian vault for markdown files when typing [[

-- Get the workspace path - try multiple sources
local function get_workspace_path()
	-- Common Obsidian vault paths for your setup
	local obsidian_paths = {
		"/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/",
	}

	for _, p in ipairs(obsidian_paths) do
		if vim.fn.isdirectory(p) == 1 then
			return p
		end
	end

	-- Try environment variable
	local env_path = os.getenv("OBSIDIAN_VAULT")
	if env_path and vim.fn.isdirectory(env_path) == 1 then
		return env_path
	end

	-- Fallback to common locations
	local fallback_paths = {
		vim.fn.expand("~/Documents/Obsidian"),
		vim.fn.expand("~/Obsidian"),
		vim.fn.expand("~/Documents/Second Brain"),
	}

	for _, p in ipairs(fallback_paths) do
		if vim.fn.isdirectory(p) == 1 then
			return p
		end
	end

	-- Return empty string if nothing found
	return ""
end

local source = {}

-- File cache to avoid scanning filesystem on every keystroke
local file_cache = {
	files = {},
	workspace_path = nil,
	last_update = 0,
	cache_ttl = 30, -- seconds before cache expires
}

-- Refresh the file cache
local function refresh_cache(workspace_path)
	local now = os.time()
	if file_cache.workspace_path == workspace_path and (now - file_cache.last_update) < file_cache.cache_ttl then
		return file_cache.files
	end

	-- Normalize path
	if workspace_path:sub(-1) ~= "/" then
		workspace_path = workspace_path .. "/"
	end

	-- Find ALL markdown files (no limit on search)
	local files = vim.fs.find(function(name)
		return name:match("%.md$") ~= nil
	end, {
		path = workspace_path,
		type = "file",
		limit = math.huge, -- No limit
	})

	-- Process files into relative paths
	local processed = {}
	for _, file_path in ipairs(files) do
		local relative_path = file_path:gsub(workspace_path, ""):gsub("%.md$", "")
		-- Skip templates, trash, and hidden folders
		if not relative_path:match("^Templates/")
			and not relative_path:match("^%.")
			and not relative_path:match("^%.trash/")
			and not relative_path:match("^%.obsidian/") then
			table.insert(processed, {
				full_path = file_path,
				relative_path = relative_path,
				filename = vim.fs.basename(relative_path),
			})
		end
	end

	-- Update cache
	file_cache.files = processed
	file_cache.workspace_path = workspace_path
	file_cache.last_update = now

	return processed
end

-- Constructor
function source.new(opts)
	vim.validate("source.opts.workspace_path", opts.workspace_path, { "string" }, true)

	local self = setmetatable({}, { __index = source })
	self.opts = opts or {}
	self.workspace_path = self.opts.workspace_path or get_workspace_path()
	self.max_items = self.opts.max_items or 20

	return self
end

-- Enable only for markdown files
function source:enabled()
	return vim.bo.filetype == "markdown"
end

-- Trigger on [
function source:get_trigger_characters()
	return { "[" }
end

-- Get completions
function source:get_completions(ctx, callback)
	-- blink.cmp context structure:
	-- ctx.line = current line content (string)
	-- ctx.cursor = { line_number, col_number } (1-indexed)

	local line = ctx.line or ""
	local cursor_col = ctx.cursor and ctx.cursor[2] or 0
	local line_to_cursor = line:sub(1, cursor_col)

	-- Check if we're inside [[
	local _, bracket_start = line_to_cursor:find("%[%[")
	if not bracket_start then
		callback({ items = {}, is_incomplete = false })
		return
	end

	-- Extract query between [[ and cursor
	local query = line_to_cursor:sub(bracket_start + 1)

	-- Get workspace path
	local workspace_path = self.workspace_path
	if not workspace_path or workspace_path == "" then
		vim.notify_once("WikiLinks: No Obsidian workspace found", vim.log.levels.WARN)
		callback({ items = {}, is_incomplete = false })
		return
	end

	-- Verify workspace exists
	if vim.fn.isdirectory(workspace_path) ~= 1 then
		vim.notify_once("WikiLinks: Workspace not found", vim.log.levels.WARN)
		callback({ items = {}, is_incomplete = false })
		return
	end

	-- Get all files from cache
	local all_files = refresh_cache(workspace_path)

	-- Get current file to exclude
	local current_file = vim.api.nvim_buf_get_name(0) or ""
	local current_basename = current_file ~= "" and vim.fs.basename(current_file):gsub("%.md$", "") or ""

	-- Filter and score files based on query
	local scored_items = {}
	local query_lower = query:lower()

	for _, file in ipairs(all_files) do
		-- Skip current file
		if file.relative_path ~= current_basename then
			local filename_lower = file.filename:lower()
			local relative_path_lower = file.relative_path:lower()

			-- Calculate match score
			local score = 0
			local matches = false

			if query == "" then
				matches = true
				score = 0
			elseif filename_lower:find(query_lower, 1, true) then
				matches = true
				-- Higher score for prefix match
				if filename_lower:sub(1, #query_lower) == query_lower then
					score = 100
				else
					score = 50
				end
			elseif relative_path_lower:find(query_lower, 1, true) then
				matches = true
				score = 25
			end

			if matches then
				table.insert(scored_items, {
					label = file.relative_path,
					insertText = file.relative_path .. "]]",
					filterText = file.relative_path,
					sortText = string.format("%03d%s", 100 - score, file.relative_path),
					kind = 17, -- File kind
					score_offset = score,
				})
			end
		end
	end

	-- Sort by score (highest first), then alphabetically
	table.sort(scored_items, function(a, b)
		if a.score_offset ~= b.score_offset then
			return a.score_offset > b.score_offset
		end
		return a.label < b.label
	end)

	-- Apply limit AFTER filtering and sorting
	local items = {}
	for i = 1, math.min(#scored_items, self.max_items) do
		table.insert(items, scored_items[i])
	end

	callback({
		items = items,
		is_incomplete_forward = #scored_items > self.max_items,
		is_incomplete_backward = false,
	})
end

return source
