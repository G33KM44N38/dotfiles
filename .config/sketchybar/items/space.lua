local colors = require("colors")
local settings = require("settings")
local sbar = require("sketchybar")

local space_indicator = sbar.add("item", "space_indicator", {
  display = "active",
  icon = { drawing = false },
  label = {
    font = {
      style = settings.font.style_map["Black"],
      size = 12.0,
    },
  },
  updates = true,
  position = "right"
})

space_indicator:subscribe("aerospace_space_change", function(env)
  local space_name = env.SPACE_NAME or env.SPACE or "Unknown"
  local space_index = env.SPACE_INDEX or "?"
  
  space_indicator:set({ 
    label = { string = "Space " .. space_index .. ": " .. space_name } 
  })
end)

return space_indicator