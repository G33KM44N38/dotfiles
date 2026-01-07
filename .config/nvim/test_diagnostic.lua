-- Diagnostic test for tree-sitter query
local ts = vim.treesitter
local buf = vim.api.nvim_get_current_buf()
local ft = vim.bo.filetype

print("Current filetype: " .. ft)

-- Check parser
local parser = ts.get_parser(buf, ft)
print("Parser available: " .. tostring(parser ~= nil))

if parser then
	local trees = parser:parse()
	print("Number of trees: " .. #trees)

	if trees and #trees > 0 then
		local tree = trees[1]
		local root = tree:root()
		print("Root node type: " .. root:type())

		-- Try the query
		local query_str = [[
			(call_expression
				function: (member_expression
					object: (identifier) @console (#eq? @console "console")
					property: (property_identifier) @method (#any-of? @method "log" "warn" "error" "debug"))
				arguments: (arguments) @args) @call
		]]

		local ok, query = pcall(ts.query.parse, ft, query_str)
		print("Query parsed: " .. tostring(ok))

		if ok and query then
			print("Available captures: " .. table.concat(query.captures, ", "))

			local results = {}
			local match_count = 0
			print("\n=== Detailed Match Analysis ===")
			for item1, item2, item3 in query:iter_matches(root, buf) do
				match_count = match_count + 1
				print(string.format("\nMatch %d:", match_count))
				print(string.format("  Arg1: type=%s, value=%s", type(item1), tostring(item1)))
				print(string.format("  Arg2: type=%s", type(item2)))
				
				if type(item2) == "table" then
					print(string.format("  Arg2 is table with %d items:", #item2))
					for k, v in pairs(item2) do
						local vtype = type(v)
						if vtype == "userdata" then
							print(string.format("    [%s] = node: %s", tostring(k), v:type()))
						else
							print(string.format("    [%s] = %s: %s", tostring(k), vtype, tostring(v)))
						end
					end
				end

				if item3 then
					print(string.format("  Arg3: type=%s", type(item3)))
				end
			end
			print(string.format("\n\nTotal matches: %d", match_count))
		end
	end
end

vim.cmd("silent! q!")
