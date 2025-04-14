local function measure_require(module)
	local start = vim.loop.hrtime()
	local result = require(module)
	local elapsed = (vim.loop.hrtime() - start) / 1e6 -- convert to milliseconds
	print(string.format("[DEBUG] require('%s') took %.2f ms", module, elapsed))
	return result
end

-- Time your main requires
-- measure_require("root.core")
-- measure_require("root.lazy")
require("root.core")
require("root.lazy")
