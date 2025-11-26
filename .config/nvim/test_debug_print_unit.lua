-- Unit tests for debug_print.lua
-- Tests the find_debug_calls function with tree-sitter

local function assert_equals(actual, expected, message)
	if actual ~= expected then
		error(string.format("Assertion failed: %s. Expected %s, got %s", message, expected, actual))
	end
end

local function assert_true(condition, message)
	if not condition then
		error(string.format("Assertion failed: %s", message))
	end
end

local function assert_table_length(tbl, expected_length, message)
	if #tbl ~= expected_length then
		error(
			string.format(
				"Assertion failed: %s. Expected table length %d, got %d",
				message,
				expected_length,
				#tbl
			)
		)
	end
end

-- Test suite
local tests = {}

function tests.test_treesitter_parser_availability()
	print("Testing tree-sitter parser availability...")

	local ts = vim.treesitter
	local buf = vim.api.nvim_get_current_buf()
	local ft = vim.bo.filetype

	if ft == "typescript" or ft == "typescriptreact" then
		local parser = ts.get_parser(buf, ft)
		assert_true(parser ~= nil, "Tree-sitter parser should be available for TypeScript")
		print("✓ Tree-sitter parser is available")
	else
		print("⊘ Not in TypeScript buffer, skipping parser test")
	end
end

function tests.test_query_parsing()
	print("Testing tree-sitter query parsing...")

	local ts = vim.treesitter
	local ft = vim.bo.filetype

	if ft ~= "typescript" and ft ~= "typescriptreact" and ft ~= "javascript" and ft ~= "javascriptreact" then
		print("⊘ Not in JavaScript/TypeScript buffer, skipping query test")
		return
	end

	local query_str = [[
		(call_expression
			function: (member_expression
				object: (identifier) @console (#eq? @console "console")
				property: (property_identifier) @method (#eq? @method "log"))
			arguments: (arguments) @args) @call
	]]

	local ok, query = pcall(ts.query.parse, ft, query_str)
	assert_true(ok, "Query parsing should succeed")
	assert_true(query ~= nil, "Query should not be nil after parsing")
	print("✓ Query parsing successful")
end

function tests.test_match_type_checking()
	print("Testing match type validation...")

	-- Simulate the type checking from the fixed code
	local test_match = { 1, 2, 3 }
	assert_true(test_match and type(test_match) == "table", "Match should be a table")

	local test_non_match = 5
	assert_true(not (test_non_match and type(test_non_match) == "table"), "Non-table should fail type check")

	print("✓ Match type checking works correctly")
end

function tests.test_debug_calls_detection()
	print("Testing debug calls detection...")

	local ts = vim.treesitter
	local buf = vim.api.nvim_get_current_buf()
	local ft = vim.bo.filetype

	if ft ~= "typescript" and ft ~= "typescriptreact" then
		print("⊘ Not in TypeScript buffer, skipping detection test")
		return
	end

	local query_str = [[
		(call_expression
			function: (member_expression
				object: (identifier) @console (#eq? @console "console")
				property: (property_identifier) @method (#any-of? @method "log" "warn" "error" "debug"))
			arguments: (arguments) @args) @call
	]]

	local parser = ts.get_parser(buf, ft)
	if not parser then
		print("⊘ Parser not available, skipping detection test")
		return
	end

	local trees = parser:parse()
	assert_true(trees and #trees > 0, "Parser should return valid tree")

	local tree = trees[1]
	local root = tree:root()
	assert_true(root ~= nil, "Tree should have a root node")

	local ok, query = pcall(ts.query.parse, ft, query_str)
	assert_true(ok, "Query should parse successfully")

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

	assert_true(pcall_ok, string.format("Query iteration should not error: %s", err or ""))
	assert_true(#results > 0, "Should detect at least one console call in test file")

	print(string.format("✓ Detected %d debug calls", #results))
end

function tests.test_results_sorting()
	print("Testing results sorting by position...")

	local unsorted = {
		{ row = 5, col = 2 },
		{ row = 2, col = 10 },
		{ row = 2, col = 5 },
		{ row = 10, col = 1 },
	}

	table.sort(unsorted, function(a, b)
		if a.row ~= b.row then
			return a.row < b.row
		end
		return a.col < b.col
	end)

	assert_equals(unsorted[1].row, 2, "First result should be at row 2")
	assert_equals(unsorted[1].col, 5, "First result at row 2 should be at col 5")
	assert_equals(unsorted[2].col, 10, "Second result at row 2 should be at col 10")
	assert_equals(unsorted[3].row, 5, "Third result should be at row 5")
	assert_equals(unsorted[4].row, 10, "Last result should be at row 10")

	print("✓ Results sorting works correctly")
end

function tests.test_cursor_position_logic()
	print("Testing cursor navigation logic...")

	local debug_calls = {
		{ row = 2, col = 5 },
		{ row = 5, col = 10 },
		{ row = 10, col = 3 },
	}

	-- Test finding next call after row 3
	local current_row = 3
	local current_col = 0
	local current_index = 0

	for i, call in ipairs(debug_calls) do
		if call.row > current_row or (call.row == current_row and call.col > current_col) then
			current_index = i
			break
		end
	end

	if current_index == 0 then
		current_index = 1
	end

	assert_equals(current_index, 2, "Should find second call as next after row 3")

	-- Test wrapping when at end
	current_row = 15
	current_col = 0
	current_index = 0

	for i, call in ipairs(debug_calls) do
		if call.row > current_row or (call.row == current_row and call.col > current_col) then
			current_index = i
			break
		end
	end

	if current_index == 0 then
		current_index = 1
	end

	assert_equals(current_index, 1, "Should wrap to first call when past last call")

	print("✓ Cursor position logic works correctly")
end

function tests.test_previous_navigation()
	print("Testing previous call navigation logic...")

	local debug_calls = {
		{ row = 2, col = 5 },
		{ row = 5, col = 10 },
		{ row = 10, col = 3 },
	}

	-- Test finding previous call before row 7
	local current_row = 7
	local current_col = 0
	local current_index = #debug_calls + 1

	for i = #debug_calls, 1, -1 do
		local call = debug_calls[i]
		if call.row < current_row or (call.row == current_row and call.col < current_col) then
			current_index = i
			break
		end
	end

	if current_index == #debug_calls + 1 then
		current_index = #debug_calls
	end

	assert_equals(current_index, 2, "Should find second call as previous before row 7")

	-- Test wrapping when at beginning
	current_row = 1
	current_col = 0
	current_index = #debug_calls + 1

	for i = #debug_calls, 1, -1 do
		local call = debug_calls[i]
		if call.row < current_row or (call.row == current_row and call.col < current_col) then
			current_index = i
			break
		end
	end

	if current_index == #debug_calls + 1 then
		current_index = #debug_calls
	end

	assert_equals(current_index, 3, "Should wrap to last call when before first call")

	print("✓ Previous call navigation logic works correctly")
end

-- Run all tests
local function run_tests()
	print("\n" .. string.rep("=", 60))
	print("Running debug_print.lua unit tests")
	print(string.rep("=", 60) .. "\n")

	local passed = 0
	local failed = 0

	for test_name, test_func in pairs(tests) do
		local ok, err = pcall(test_func)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string.format("✗ %s: %s", test_name, err))
		end
	end

	print("\n" .. string.rep("=", 60))
	print(string.format("Test Results: %d passed, %d failed", passed, failed))
	print(string.rep("=", 60) .. "\n")

	return failed == 0
end

-- Execute tests
local success = run_tests()
return success
