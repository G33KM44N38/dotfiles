return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"mfussenegger/nvim-dap",
			"theHamsta/nvim-dap-virtual-text",
			"leoluz/nvim-dap-go",
			"nvim-neotest/nvim-nio",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")
			require("dap-go").setup()
			dapui.setup()
			vim.keymap.set("n", "<leader>dt", dapui.toggle, { noremap = true, desc = "Toggle DAP UI" })
			vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { noremap = true, desc = "Toggle Breakpoint" })
			vim.keymap.set("n", "<leader>dc", dap.continue, { noremap = true, desc = "DAP Continue" })
			vim.keymap.set("n", "<leader>dr", function()
				dapui.open({ reset = true })
			end, { noremap = true, desc = "DAP UI Open & Reset" })
			vim.keymap.set("n", "<leader>dso", dap.step_over, { noremap = true, desc = "DAP Step Over" })
			vim.keymap.set("n", "<leader>dsi", dap.step_into, { noremap = true, desc = "DAP Step Into" })
			vim.keymap.set("n", "<leader>dsO", dap.step_out, { noremap = true, desc = "DAP Step Out" })
			-- Fixed keymap for restarting the test
			vim.keymap.set("n", "<leader>dR", function()
				dap.restart()
			end, { noremap = true, desc = "DAP Restart Test" })
			-- New keymap for setting conditional breakpoint
			vim.keymap.set("n", "<leader>dC", function()
				dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
			end, { noremap = true, desc = "DAP Conditional Breakpoint" })

			vim.keymap.set("n", "<leader>d?", function()
				dapui.eval(nil, { enter = true })
			end, { noremap = true })
		end,
	},
}
