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
				}, {
				file_pattern = '.zshrc',
				cloak_pattern = '=.+',
				replace = nil,
			},
				{
					file_pattern = '.vault-password',
					cloak_pattern = '.+',
				},
				{
					file_pattern = '.npmrc',
					cloak_pattern = '=.+', -- Cloak the registry line if needed
					replace = '*',
				},
			}
		})
	end
}
