return {
	"laytan/cloak.nvim",
	config = function()
		local ok, cloak = pcall(require, "cloak")

		if not ok then
			return
		end

		cloak.setup({
			enabled = true,
			cloak_character = '*',
			highlight_group = 'Comment',
			cloak_length = nil,
			try_all_patterns = true,
			cloak_telescope = true,
			cloak_on_leave = false,
			patterns = {
				{
					file_pattern = '.env*',
					cloak_pattern = '=.+',
					replace = nil,
				},
				-- Add more patterns as needed
				-- {
				--     file_pattern = 'credentials.yml',
				--     cloak_pattern = ':.+',
				-- },
			},
		})
	end
}
