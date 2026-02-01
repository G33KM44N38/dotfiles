-- Inline Wiki-Link completion for blink.cmp
-- Triggers on any text, wraps accepted matches in [[ ]]
-- Type "Ky" → select "Kylian" → becomes "[[Kylian]]"

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

-- File cache
local file_cache = {
	files = {},
	workspace_path = nil,
	last_update = 0,
	cache_ttl = 30,
}

local function refresh_cache(workspace_path)
	local now = os.time()
	if file_cache.workspace_path == workspace_path and (now - file_cache.last_update) < file_cache.cache_ttl then
		return file_cache.files
	end

	if workspace_path:sub(-1) ~= "/" then
		workspace_path = workspace_path .. "/"
	end

	local files = vim.fs.find(function(name)
		return name:match("%.md$") ~= nil
	end, {
		path = workspace_path,
		type = "file",
		limit = math.huge,
	})

	local processed = {}
	for _, file_path in ipairs(files) do
		local relative_path = file_path:gsub(workspace_path, ""):gsub("%.md$", "")
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

	file_cache.files = processed
	file_cache.workspace_path = workspace_path
	file_cache.last_update = now
	return processed
end

function source.new(opts)
	vim.validate("source.opts.workspace_path", opts.workspace_path, { "string" }, true)

	local self = setmetatable({}, { __index = source })
	self.opts = opts or {}
	self.workspace_path = self.opts.workspace_path
	self.max_items = self.opts.max_items or 15

	return self
end

function source:enabled()
	return vim.bo.filetype == "markdown"
end

-- No trigger characters - rely on keyword detection
function source:get_trigger_characters()
	return {}
end

function source:get_completions(ctx, callback)
	local line = ctx.line or ""
	local cursor_col = ctx.cursor and ctx.cursor[2] or 0
	local line_to_cursor = line:sub(1, cursor_col)

	-- Don't show if we're inside [[ ]] (let the other wikilinks source handle that)
	if line_to_cursor:find("%[%[[^%]]*$") then
		callback({ items = {}, is_incomplete = false })
		return
	end

	-- Get workspace path
	local workspace_path = self.workspace_path
	if not workspace_path or workspace_path == "" then
		callback({ items = {}, is_incomplete = false })
		return
	end

	-- Refresh file cache
	local all_files = refresh_cache(workspace_path)
	vim.notify("wikilinks_inline: found " .. #all_files .. " files", vim.log.levels.DEBUG)
	local current_file = vim.api.nvim_buf_get_name(0) or ""
	local current_basename = current_file ~= "" and vim.fs.basename(current_file):gsub("%.md$", "") or ""

	-- Calculate word boundaries for text replacement
	local word_start = cursor_col
	for i = cursor_col, 1, -1 do
		local char = line:sub(i, i)
		if char:match("%s") or char:match("[%[%]%(%)]") then
			word_start = i
			break
		end
		word_start = i - 1
	end

	-- Build completion items
	-- Return ALL files and let blink.cmp fuzzy match and filter
	local items = {}
	for _, file in ipairs(all_files) do
		if file.filename ~= current_basename then
			table.insert(items, {
				label = file.filename,
				filterText = file.filename,
				sortText = file.filename:lower(),
				kind = require("blink.cmp.types").CompletionItemKind.File,
				textEdit = {
					newText = "[[" .. file.filename .. "]]",
					range = {
						start = { line = ctx.cursor[1] - 1, character = word_start },
						["end"] = { line = ctx.cursor[1] - 1, character = cursor_col },
					},
				},
			})
		end
	end

	-- Return ALL items - let blink.cmp fuzzy match and filter
	callback({
		items = items,
		is_incomplete_forward = false,
		is_incomplete_backward = false,
	})
end

return source
