local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local sorters = require "telescope.sorters"
local action_state = require "telescope.actions.state"
local action = require "telescope.actions"
local dropdown = require "telescope.themes".get_dropdown()

function trimPath(str)
    local j = 0;
    for i = 1, #str do
        local c = str:sub(i,i)
        if (c == '/')
            then
                j = i;
            end
        i = i+ 1;
    end
    return string.sub(str, j+1, string.len(str));
end

function getBuffer()
    local i = 1
    local buff = {}
    local index = {}
    while i < 100 do
        if (vim.api.nvim_buf_is_valid(i) and vim.api.nvim_buf_is_loaded(i) and vim.api.nvim_buf_get_name(i) ~= "") then
            table.insert(buff, trimPath(vim.api.nvim_buf_get_name(i)));
            table.insert(index, i);
        end
        i = i + 1;
    end
    return buff, index;
end

local M = {}
M.close_buffer = function()
    local buffer, index = getBuffer()

    local function deletedEnter(prompt_bufnr)
        local select = action_state.get_selected_entry()
        action.close(prompt_bufnr)
        local val = vim.inspect(select)
        local t = {}
        for substring in val:gmatch("%S+") do
            table.insert(t, substring)
        end
        local subs = string.sub(t[5], 0, 1)
        local Buffernb = subs + 0
        vim.api.nvim_buf_delete(index[Buffernb], {})
	end

	local opts = {
	    layout_strategy = "vertical",
	    layout_config ={
	        height= 10,
	        width= 0.3,
	        prompt_position = "top",
	    },
    default_selection_index = 0,
    prompt_title = "Close buffer",
	finder = finders.new_table(buffer),
	sorter = sorters.get_generic_fuzzy_sorter(opts),
	attach_mappings = function(prompt_bufnr, map)
	    map("i", "<CR>", deletedEnter)
	    return true
	end
	}
	local bufferView = pickers.new(dropdown,opts)
	bufferView:find()
end
return M
