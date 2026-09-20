-- A popup that draws the keymap the keyboard is currently running.
--
-- The keymap is read from the keyboard itself (bin/qmk_keymap_dump.py talks to
-- the firmware over raw HID) every time the popup is shown, so it can never be
-- out of date with respect to what is flashed. Only the static bits are local:
-- the board's key geometry (ergodox_geometry.lua) and QMK's keycode numbering
-- (keymap_labels.lua / qmk_keycodes.lua).
--
-- Usage from rc.lua:
--
--   local keymap_popup = require("keymap_popup")
--   awful.key({ modkey }, "/", keymap_popup.toggle, ...)

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")
local lgi = require("lgi")
local Pango = lgi.Pango
local PangoCairo = lgi.PangoCairo

local geometry = require("ergodox_geometry")
local labels = require("keymap_labels")

local M = {}

local dumper = awful.util.getdir("config") .. "/bin/qmk_keymap_dump.py"

-- Layers are laid out in this many columns.
local COLUMNS = 2
-- Space between layers and around the edge, in pixels.
local GAP = 16
-- Space between neighbouring keycaps, in pixels.
local KEY_PAD = 2
-- The popup takes up to this fraction of the screen's workarea.
local SCREEN_FRACTION = 0.85
-- A key unit never shrinks below this many pixels.
local MIN_UNIT = 24

local state = {
  popup = nil,
  grabber = nil,
  loading = false,
}

local function color(name, fallback)
  return beautiful[name] or fallback
end

local colors = {
  key_bg = function() return color("bg_focus", "#535d6c") end,
  key_fg = function() return color("fg_focus", "#ffffff") end,
  hold_fg = function() return color("fg_normal", "#aaaaaa") end,
  dim_bg = function() return color("bg_minimize", "#444444") end,
  dim_fg = function() return color("fg_normal", "#aaaaaa") end,
  title_fg = function() return color("fg_normal", "#aaaaaa") end,
  title_active_fg = function() return color("fg_focus", "#ffffff") end,
  title_active_bg = function() return color("bg_focus", "#535d6c") end,
}

-- {{{ Drawing

local function make_font(px)
  local desc = Pango.FontDescription.from_string(color("font", "sans 8"))
  desc:set_absolute_size(Pango.units_from_double(px))
  return desc
end

-- Fonts are never shrunk below this fraction of their size to make a label fit.
local MIN_FONT_SCALE = 0.55

-- Draws text centred in the box (x, y, w, h) with the given font. Labels that
-- are too wide wrap at spaces if they have any ("TG SYMB"), otherwise the font
-- shrinks until they fit ("Hyper" on a 1u key); hyphenation would be harder
-- to read than either.
local function draw_text(cr, font, text, fg, x, y, w, h)
  local layout = font.layout
  layout:set_font_description(font.desc)
  layout:set_width(-1)
  layout.text = text
  cr:update_layout(layout)
  local _, logical = layout:get_pixel_extents()
  if logical.width > w and text:find(" ") then
    layout:set_width(Pango.units_from_double(w))
    cr:update_layout(layout)
    _, logical = layout:get_pixel_extents()
  end
  if logical.width > w then
    local scale = math.max(MIN_FONT_SCALE, w / logical.width)
    local desc = font.desc:copy()
    desc:set_absolute_size(Pango.units_from_double(font.px * scale))
    layout:set_font_description(desc)
    cr:update_layout(layout)
    _, logical = layout:get_pixel_extents()
  end
  cr:move_to(x + (w - logical.width) / 2, y + (h - logical.height) / 2)
  cr:set_source(gears.color(fg))
  cr:show_layout(layout)
end

local function draw_keycap(cr, x, y, w, h, bg)
  cr:save()
  cr:translate(x, y)
  gears.shape.rounded_rect(cr, w, h, 4)
  cr:set_source(gears.color(bg))
  cr:fill()
  cr:restore()
end

-- Draws one layer with its top-left corner at (x0, y0).
local function draw_layer(cr, data, layer, x0, y0, unit, fonts, fallback_layer)
  local ctx = { layer_names = data.layer_names, user_names = data.user_names }
  local keycodes = data.keycodes[layer + 1]

  local on = ((data.layer_state | data.default_layer_state) >> layer) & 1 == 1
  local top = layer == data.highest_layer
  local title = string.format("%d · %s", layer, data.layer_names[layer + 1] or "")
  if top then
    title = title .. "  ▸ active"
  elseif on then
    title = title .. "  · on"
  end
  local title_h = fonts.title_px * 2
  if top then
    draw_keycap(cr, x0, y0, geometry.width * unit, title_h, colors.title_active_bg())
  end
  draw_text(cr, fonts.title, title, top and colors.title_active_fg() or colors.title_fg(),
    x0, y0, geometry.width * unit, title_h)
  y0 = y0 + title_h

  for _, key in ipairs(geometry.keys) do
    local kc = keycodes[key.row + 1][key.col + 1]
    local decoded = labels.decode(kc, ctx)
    local bg, fg, hold_fg = colors.key_bg(), colors.key_fg(), colors.hold_fg()
    if decoded.kind == "trns" then
      -- Show what the key falls through to, dimmed. This assumes only the
      -- default layer is below, which is the common case.
      bg, fg, hold_fg = colors.dim_bg(), colors.dim_fg(), colors.dim_fg()
      if layer ~= fallback_layer then
        local below = data.keycodes[fallback_layer + 1][key.row + 1][key.col + 1]
        decoded = labels.decode(below, ctx)
      end
    elseif decoded.kind == "none" then
      bg = colors.dim_bg()
    end

    local x = x0 + key.x * unit + KEY_PAD
    local y = y0 + key.y * unit + KEY_PAD
    local w = key.w * unit - 2 * KEY_PAD
    local h = key.h * unit - 2 * KEY_PAD
    draw_keycap(cr, x, y, w, h, bg)
    local inner = 4
    if decoded.hold then
      local hold_h = fonts.hold_px * 1.4
      draw_text(cr, fonts.tap, decoded.tap, fg, x + inner, y, w - 2 * inner, h - hold_h)
      draw_text(cr, fonts.hold, decoded.hold, hold_fg, x + inner, y + h - hold_h - inner, w - 2 * inner, hold_h)
    else
      draw_text(cr, fonts.tap, decoded.tap, fg, x + inner, y, w - 2 * inner, h)
    end
  end
end

-- Builds the widget that draws every layer of the keymap in data, sized to
-- fit on screen s.
local function make_widget(data, s)
  local layers = #data.keycodes
  local rows = math.ceil(layers / COLUMNS)
  local wa = s.workarea
  local title_px = math.floor(math.max(14, wa.height / 75))
  local title_h = title_px * 2

  -- Key unit: as large as fits on the screen.
  local unit = math.min(
    (wa.width * SCREEN_FRACTION - (COLUMNS + 1) * GAP) / (COLUMNS * geometry.width),
    (wa.height * SCREEN_FRACTION - (rows + 1) * GAP - rows * title_h) / (rows * geometry.height))
  unit = math.floor(math.max(MIN_UNIT, unit))

  local layer_w = geometry.width * unit
  local layer_h = geometry.height * unit + title_h
  local total_w = COLUMNS * layer_w + (COLUMNS + 1) * GAP
  local total_h = rows * layer_h + (rows + 1) * GAP

  local pango_ctx = PangoCairo.font_map_get_default():create_context()
  pango_ctx:set_resolution(s.dpi or 96)
  -- A font is a Pango layout plus the description to reset it to, since
  -- draw_text may shrink it for one label.
  local function make_layout(px)
    local layout = Pango.Layout.new(pango_ctx)
    layout:set_alignment("CENTER")
    layout:set_wrap("WORD")
    return { layout = layout, desc = make_font(px), px = px }
  end
  local fonts = {
    title_px = title_px,
    title = make_layout(title_px),
    tap_px = unit * 0.32,
    tap = make_layout(unit * 0.32),
    hold_px = unit * 0.22,
    hold = make_layout(unit * 0.22),
  }

  -- Transparent keys fall through to the default layer.
  local fallback_layer = 0
  for l = layers - 1, 0, -1 do
    if (data.default_layer_state >> l) & 1 == 1 then
      fallback_layer = l
      break
    end
  end

  local widget = wibox.widget.base.make_widget()
  function widget:fit(_, _, _)
    return total_w, total_h
  end
  function widget:draw(_, cr, _, _)
    for layer = 0, layers - 1 do
      local col = layer % COLUMNS
      local row = layer // COLUMNS
      local x0 = GAP + col * (layer_w + GAP)
      local y0 = GAP + row * (layer_h + GAP)
      draw_layer(cr, data, layer, x0, y0, unit, fonts, fallback_layer)
    end
  end
  return widget
end

-- }}}

-- {{{ Showing and hiding

function M.hide()
  -- Idempotent: the keygrabber's stop_callback calls back in here.
  if state.popup == nil then
    return
  end
  local popup, grabber = state.popup, state.grabber
  state.popup, state.grabber = nil, nil
  popup.visible = false
  if grabber ~= nil then
    grabber:stop()
  end
end

-- Shows a keymap dump (the table bin/qmk_keymap_dump.py prints) on the
-- focused screen. Exposed so a saved dump can be shown for debugging:
--
--   echo 'require("keymap_popup").show(dofile("/path/to/dump.lua"))' | awesome-client
function M.show(data)
  M.hide()
  local s = awful.screen.focused()
  local popup = awful.popup {
    widget = make_widget(data, s),
    screen = s,
    placement = awful.placement.centered,
    ontop = true,
    visible = true,
    border_width = (beautiful.border_width or 1) * 2,
    border_color = color("border_focus", "#535d6c"),
    bg = color("bg_normal", "#222222"),
    shape = gears.shape.rounded_rect,
  }
  popup:connect_signal("button::press", M.hide)
  state.popup = popup

  -- Root keys do not fire while grabbing, so the toggle chord is handled here.
  -- "/" arrives as the keysym "slash".
  state.grabber = awful.keygrabber {
    autostart = true,
    mask_modkeys = true,
    stop_key = "Escape",
    stop_event = "press",
    stop_callback = M.hide,
    keybindings = {
      { { "Mod4" }, "slash", M.hide },
      { { "Mod4" }, "/", M.hide },
    },
  }
end

local function fail(text)
  naughty.notify({
    preset = naughty.config.presets.critical,
    title = "Keymap",
    text = text,
  })
end

-- Shows the keymap read from the keyboard, or hides it if it is showing.
function M.toggle()
  if state.popup ~= nil then
    M.hide()
    return
  end
  if state.loading then
    return
  end
  state.loading = true
  -- Never io.popen here: that would stall awesome while the keyboard answers.
  awful.spawn.easy_async({ "python3", dumper }, function(stdout, stderr, _, code)
    state.loading = false
    if code ~= 0 then
      fail(stderr ~= "" and stderr or ("dumper exited with " .. tostring(code)))
      return
    end
    local chunk, err = load(stdout, "keymap", "t", {})
    if chunk == nil then
      fail("bad dumper output: " .. tostring(err))
      return
    end
    local ok, data = pcall(chunk)
    if not ok then
      fail("bad dumper output: " .. tostring(data))
      return
    end
    local drawn, draw_err = pcall(M.show, data)
    if not drawn then
      M.hide()
      fail("cannot draw keymap: " .. tostring(draw_err))
    end
  end)
end

-- }}}

return M
