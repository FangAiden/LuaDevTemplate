local lvgl = require("lvgl")

-- 简单 LuaVGL 示例
local root = lvgl.Object(nil, {
  w = lvgl.HOR_RES(),
  h = lvgl.VER_RES(),
  bg_color = 0x0B0E14,
  border_width = 0,
})
root:clear_flag(lvgl.FLAG.SCROLLABLE)

local title = lvgl.Label(root, {
  text = "Lua Develop Template",
  text_color = 0x9FB3C8,
  text_font = lvgl.Font("montserrat", 18, "normal"),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 20 },
})

local message = lvgl.Label(root, {
  text = "Tap the button",
  text_color = 0xE8EEF5,
  text_font = lvgl.Font("montserrat", 26, "normal"),
  align = lvgl.ALIGN.CENTER,
})

local button = lvgl.Object(root, {
  w = 160,
  h = 52,
  radius = 26,
  bg_color = 0x1B2330,
  border_width = 1,
  border_color = 0x2A2F38,
})
button:clear_flag(lvgl.FLAG.SCROLLABLE)
button:add_flag(lvgl.FLAG.CLICKABLE)
button:align_to({
  base = message,
  type = lvgl.ALIGN.OUT_BOTTOM_MID,
  x_ofs = 0,
  y_ofs = 26,
})

local button_label = lvgl.Label(button, {
  text = "PRESS",
  text_color = 0xE8EEF5,
  text_font = lvgl.Font("montserrat", 18, "normal"),
  align = lvgl.ALIGN.CENTER,
})

-- 点击切换状态
local clicks = 0
local active = false

button:onevent(lvgl.EVENT.CLICKED, function()
  clicks = clicks + 1
  active = not active
  button:set({
    bg_color = active and 0x1C3B5A or 0x1B2330,
    border_color = active and 0x3A8DD6 or 0x2A2F38,
  })
  message:set({
    text = "Clicked " .. tostring(clicks),
    text_color = active and 0xD2E8FF or 0xE8EEF5,
  })
end)

return { root = root }
