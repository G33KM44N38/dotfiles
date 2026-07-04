-- Run with: :PlenaryBustedFile %
local commiter = require("root.my_plugins.Commiter")

describe("Commiter", function()
	-- ─────────────────────────────────────────────────────────
	-- strip_ansi
	-- ─────────────────────────────────────────────────────────
	describe("strip_ansi()", function()
		it("passes through plain text unchanged", function()
			assert.equal("hello world", commiter.strip_ansi("hello world"))
		end)

		it("strips color codes", function()
			assert.equal("hello", commiter.strip_ansi("\27[32mhello\27[0m"))
		end)

		it("strips bold / reset sequences", function()
			assert.equal("text", commiter.strip_ansi("\27[1mtext\27[0m"))
		end)

		it("strips cursor show/hide sequences", function()
			assert.equal("abc", commiter.strip_ansi("\27[?25labc\27[?25h"))
		end)

		it("strips carriage returns", function()
			assert.equal("line1\nline2", commiter.strip_ansi("line1\r\nline2"))
		end)

		it("strips mixed ANSI from realistic assistant output", function()
			local raw = "\27[90m>\27[0m \27[1mfeat(commiter): add assistant integration\27[0m\r\n"
			local cleaned = commiter.strip_ansi(raw)
			assert.is_nil(cleaned:find("\27"))
			assert.is_nil(cleaned:find("\r"))
		end)

		it("returns empty string unchanged", function()
			assert.equal("", commiter.strip_ansi(""))
		end)
	end)

	-- ─────────────────────────────────────────────────────────
	-- is_commit_editmsg
	-- ─────────────────────────────────────────────────────────
	describe("is_commit_editmsg()", function()
		it("returns true when current file is COMMIT_EDITMSG", function()
			-- open a scratch buffer named COMMIT_EDITMSG
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf, "COMMIT_EDITMSG")
			vim.api.nvim_set_current_buf(buf)
			assert.is_true(commiter.is_commit_editmsg())
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("returns false for regular files", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf, "some_file.lua")
			vim.api.nvim_set_current_buf(buf)
			assert.is_false(commiter.is_commit_editmsg())
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("returns false for unnamed buffers", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			assert.is_false(commiter.is_commit_editmsg())
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	-- ─────────────────────────────────────────────────────────
	-- fill_commit_editmsg
	-- ─────────────────────────────────────────────────────────
	describe("fill_commit_editmsg()", function()
		local buf

		before_each(function()
			buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
		end)

		after_each(function()
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("prepends the message to the buffer", function()
			local msg = "feat(scope): add something useful"
			commiter.fill_commit_editmsg(buf, msg)
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.equal(msg, lines[1])
		end)

		it("handles multi-line commit messages", function()
			local msg = "feat: title\n\nDetailed body here."
			commiter.fill_commit_editmsg(buf, msg)
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.equal("feat: title", lines[1])
			assert.equal("", lines[2])
			assert.equal("Detailed body here.", lines[3])
		end)

		it("moves the cursor to line 1", function()
			commiter.fill_commit_editmsg(buf, "fix: something")
			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equal(1, cursor[1])
		end)
	end)

	-- ─────────────────────────────────────────────────────────
	-- open_commit_float
	-- ─────────────────────────────────────────────────────────
	describe("open_commit_float()", function()
		local wins_before

		before_each(function()
			wins_before = vim.api.nvim_list_wins()
		end)

		after_each(function()
			-- close any windows opened during the test
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local is_new = true
				for _, w in ipairs(wins_before) do
					if w == win then
						is_new = false
						break
					end
				end
				if is_new and vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end
		end)

		it("opens a new floating window", function()
			commiter.open_commit_float("feat: test message")
			local wins_after = vim.api.nvim_list_wins()
			assert.is_true(#wins_after > #wins_before)
		end)

		it("fills the buffer with the commit message", function()
			local msg = "refactor(commiter): use assistant"
			commiter.open_commit_float(msg)
			local buf = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.equal(msg, lines[1])
		end)

		it("sets filetype to gitcommit", function()
			commiter.open_commit_float("chore: bump deps")
			local buf = vim.api.nvim_get_current_buf()
			assert.equal("gitcommit", vim.bo[buf].filetype)
		end)

		it("registers <C-s> and q keymaps on the buffer", function()
			commiter.open_commit_float("docs: update readme")
			local buf = vim.api.nvim_get_current_buf()
			local maps = vim.api.nvim_buf_get_keymap(buf, "n")
			local keys = {}
			for _, m in ipairs(maps) do
				keys[m.lhs] = true
			end
			assert.is_true(keys["<C-S>"] or keys["<C-s>"])
			assert.is_true(keys["q"])
		end)
	end)
end)
