local M = {}

local default_path
if vim.fn.has("macunix") == 1 then
	default_path = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"
else
	default_path = "~/Documents/Second_Brain"
end

M.path = vim.fs.normalize(vim.fn.expand(vim.env.OBSIDIAN_VAULT or default_path))
if M.path:sub(-1) ~= "/" then
	M.path = M.path .. "/"
end
M.daily_path = M.path .. "Daily/"
M.weekly_path = M.path .. "Weekly/"

local function normalized_directory(path)
	if not path or path == "" then
		return ""
	end

	path = vim.fs.normalize(path)
	return path:sub(-1) == "/" and path or (path .. "/")
end

local normalized_path = normalized_directory(M.path)

function M.contains(path)
	if not path or path == "" then
		return false
	end

	return normalized_directory(path):sub(1, #normalized_path) == normalized_path
end

function M.contains_buffer(bufnr)
	return M.contains(vim.api.nvim_buf_get_name(bufnr or 0))
end

return M
