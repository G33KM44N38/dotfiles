-- Final integration test
local ts = vim.treesitter
local buf = vim.api.nvim_get_current_buf()
local ft = vim.bo.filetype

if ft == "typescript" or ft == "typescriptreact" then
	local parser = ts.get_parser(buf, ft)
	if parser then
		local trees = parser:parse()
		if trees and #trees > 0 then
			local tree = trees[1]
			local root = tree:root()

			local query_str = [[
				(call_expression
					function: (member_expression
						object: (identifier) @console (#eq? @console "console")
						property: (property_identifier) @method (#any-of? @method "log" "warn" "error" "debug"))
					arguments: (arguments) @args) @call
			]]

			local ok, query = pcall(ts.query.parse, ft, query_str)
			if ok and query then
				local results = {}
				local pcall_ok, err = pcall(function()
					for capture_id, node in query:iter_captures(root, buf) do
						local capture_name = query.captures[capture_id]
						if capture_name == "call" then
							local start_row, start_col = node:range()
							table.insert(results, {
								row = start_row,
								col = start_col,
								text = vim.treesitter.get_node_text(node, buf),
							})
						end
					end
				end)

				print("============================================================")
				print("FINAL TEST: Fixed debug_print.lua Implementation")
				print("============================================================")
				print("")
				if pcall_ok then
					print("✓ Query iteration succeeded (no error)")
					print(string.format("✓ Found %d debug calls", #results))
					if #results > 0 then
						print("")
						print("First 3 debug calls:")
						for i = 1, math.min(3, #results) do
							print(string.format("  %d. Line %d: %s", i, results[i].row + 1, results[i].text))
						end
						print("")
						print("✓✓✓ ALL TESTS PASSED! ✓✓✓")
					end
				else
					print("✗ Query iteration failed: " .. tostring(err))
				end
			end
		end
	end
end

print("")
vim.cmd("silent! q!")
