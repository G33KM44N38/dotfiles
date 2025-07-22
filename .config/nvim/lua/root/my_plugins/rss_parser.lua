-- Minimal RSS (XML) parser for Lua (no dependencies)
-- Usage: local rss = require('root.my_plugins.rss_parser').parse(xml_string)
local M = {}

local function extract_tag(xml, tag)
    local pattern = string.format('<%s>(.-)</%s>', tag, tag)
    return xml:match(pattern)
end

local function extract_items(xml)
    local items = {}
    for item in xml:gmatch('<item>(.-)</item>') do
        table.insert(items, {
            title = extract_tag(item, 'title') or '',
            link = extract_tag(item, 'link') or '',
            description = extract_tag(item, 'description') or '',
            pubDate = extract_tag(item, 'pubDate') or '',
        })
    end
    return items
end

function M.parse(xml)
    local channel = xml:match('<channel>(.-)</channel>') or ''
    return {
        title = extract_tag(channel, 'title') or '',
        link = extract_tag(channel, 'link') or '',
        description = extract_tag(channel, 'description') or '',
        items = extract_items(channel),
    }
end

return M 