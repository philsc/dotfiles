-- Turns QMK keycodes into keycap labels for the keymap popup.
--
-- The keyboard reports raw 16-bit keycodes; qmk_keycodes.lua (generated from
-- the QMK checkout) supplies the numbering and the QK_* ranges, and this module
-- decodes the composite ones (mod-tap, layer-tap, layer switches, ...) and
-- picks something short enough for a 1u keycap. Pure Lua so it can be unit
-- tested outside awesome (keymap_labels_test.lua).

local qmk = require("qmk_keycodes")

local M = {}

-- Basic keycodes whose spec label is too long for a keycap, or wrong.
local glyphs = {
  KC_NO = "",
  KC_TRANSPARENT = "▽",
  KC_BACKSPACE = "⌫",
  KC_ENTER = "⏎",
  KC_TAB = "⇥",
  KC_SPACE = "␣",
  KC_ESCAPE = "Esc",
  KC_DELETE = "Del",
  KC_INSERT = "Ins",
  KC_CAPS_LOCK = "Caps",
  KC_LEFT_SHIFT = "⇧",
  KC_RIGHT_SHIFT = "⇧",
  KC_LEFT_CTRL = "Ctrl",
  KC_RIGHT_CTRL = "Ctrl",
  KC_LEFT_ALT = "Alt",
  KC_RIGHT_ALT = "AltGr",
  KC_LEFT_GUI = "◆",
  KC_RIGHT_GUI = "◆",
  KC_LEFT = "←",
  KC_RIGHT = "→",
  KC_UP = "↑",
  KC_DOWN = "↓",
  KC_PAGE_UP = "PgUp",
  KC_PAGE_DOWN = "PgDn",
  KC_PRINT_SCREEN = "PrtSc",
  KC_SCROLL_LOCK = "ScrLk",
  KC_MS_UP = "Ms↑",
  KC_MS_DOWN = "Ms↓",
  KC_MS_LEFT = "Ms←",
  KC_MS_RIGHT = "Ms→",
  KC_MS_BTN1 = "LClk",
  KC_MS_BTN2 = "RClk",
  KC_MS_BTN3 = "MClk",
  KC_MS_BTN4 = "Btn4",
  KC_MS_BTN5 = "Btn5",
  KC_MS_WH_UP = "Whl↑",
  KC_MS_WH_DOWN = "Whl↓",
  KC_MS_WH_LEFT = "Whl←",
  KC_MS_WH_RIGHT = "Whl→",
  KC_MS_ACCEL0 = "Acc0",
  KC_MS_ACCEL1 = "Acc1",
  KC_MS_ACCEL2 = "Acc2",
  KC_AUDIO_VOL_UP = "Vol+",
  KC_AUDIO_VOL_DOWN = "Vol−",
  KC_AUDIO_MUTE = "Mute",
  KC_MEDIA_PLAY_PAUSE = "⏯",
  KC_MEDIA_NEXT_TRACK = "⏭",
  KC_MEDIA_PREV_TRACK = "⏮",
  KC_MEDIA_STOP = "⏹",
  KC_BRIGHTNESS_UP = "Brt+",
  KC_BRIGHTNESS_DOWN = "Brt−",
  KC_WWW_BACK = "Back",
  KC_WWW_FORWARD = "Fwd",
  QK_CLEAR_EEPROM = "EE CLR",
  QK_BOOTLOADER = "Boot",
  QK_REBOOT = "Reset",
}

-- What Shift turns a basic key into on a US layout, so S(KC_1) reads as "!"
-- rather than "S-1".
local shifted = {
  KC_1 = "!", KC_2 = "@", KC_3 = "#", KC_4 = "$", KC_5 = "%",
  KC_6 = "^", KC_7 = "&", KC_8 = "*", KC_9 = "(", KC_0 = ")",
  KC_GRAVE = "~", KC_MINUS = "_", KC_EQUAL = "+",
  KC_LEFT_BRACKET = "{", KC_RIGHT_BRACKET = "}", KC_BACKSLASH = "|",
  KC_SEMICOLON = ":", KC_QUOTE = '"',
  KC_COMMA = "<", KC_DOT = ">", KC_SLASH = "?",
}

-- Modifier bits as used by QK_MODS, QK_MOD_TAP and QK_ONE_SHOT_MOD.
local MOD_CTRL, MOD_SHIFT, MOD_ALT, MOD_GUI, MOD_RIGHT = 0x01, 0x02, 0x04, 0x08, 0x10
local MOD_MEH, MOD_HYPER = 0x07, 0x0F

local function in_range(kc, name)
  local range = qmk.ranges[name]
  return range ~= nil and kc >= range[1] and kc <= range[1] + range[2]
end

-- Renders a modifier bitmask ("C-⇧", "Hyper", ...).
function M.mods_label(mods)
  local bits = mods & 0x0F
  if bits == MOD_HYPER then
    return "Hyper"
  elseif bits == MOD_MEH then
    return "Meh"
  end
  local parts = {}
  if bits & MOD_CTRL ~= 0 then table.insert(parts, "C") end
  if bits & MOD_SHIFT ~= 0 then table.insert(parts, "⇧") end
  if bits & MOD_ALT ~= 0 then table.insert(parts, "A") end
  if bits & MOD_GUI ~= 0 then table.insert(parts, "◆") end
  return table.concat(parts, "-")
end

-- Label for a basic (< 0x100) keycode.
local function basic_label(kc)
  local entry = qmk.keycodes[kc]
  if entry == nil then
    return string.format("%02X", kc)
  end
  local glyph = glyphs[entry.key]
  if glyph ~= nil then
    return glyph
  end
  local label = entry.label
  label = label:gsub("^Left ", ""):gsub("^Right ", ""):gsub("^Keypad ", "KP ")
  return label
end

local function layer_label(ctx, layer)
  return (ctx.layer_names or {})[layer + 1] or ("L" .. layer)
end

-- Decodes kc into { tap = string, hold = string or nil, kind = string }.
--
-- ctx carries what the keyboard reported: layer_names and user_names, both
-- 1-based lists. kind is one of "none", "trns", "basic", "mods", "mod_tap",
-- "layer_tap", "layer", "user", "kb", "other".
function M.decode(kc, ctx)
  ctx = ctx or {}
  if kc == 0x0000 then
    return { tap = "", kind = "none" }
  elseif kc == 0x0001 then
    return { tap = glyphs.KC_TRANSPARENT, kind = "trns" }
  elseif in_range(kc, "QK_BASIC") then
    return { tap = basic_label(kc), kind = "basic" }
  elseif in_range(kc, "QK_MODS") then
    local mods, base = (kc >> 8) & 0x1F, kc & 0xFF
    local entry = qmk.keycodes[base]
    if mods & 0x0F == MOD_SHIFT and entry ~= nil and shifted[entry.key] ~= nil then
      return { tap = shifted[entry.key], kind = "mods" }
    end
    return { tap = M.mods_label(mods) .. "-" .. basic_label(base), kind = "mods" }
  elseif in_range(kc, "QK_MOD_TAP") then
    local mods, base = (kc >> 8) & 0x1F, kc & 0xFF
    local hold = M.mods_label(mods)
    if base == 0x0000 then
      -- ALL_T(KC_NO) and friends: a plain modifier key.
      return { tap = hold, kind = "mod_tap" }
    end
    return { tap = basic_label(base), hold = hold, kind = "mod_tap" }
  elseif in_range(kc, "QK_LAYER_TAP") then
    local layer, base = (kc >> 8) & 0x0F, kc & 0xFF
    return { tap = basic_label(base), hold = layer_label(ctx, layer), kind = "layer_tap" }
  elseif in_range(kc, "QK_LAYER_MOD") then
    local layer, mods = (kc >> 5) & 0x0F, kc & 0x1F
    return { tap = "LM " .. layer_label(ctx, layer), hold = M.mods_label(mods), kind = "layer" }
  elseif in_range(kc, "QK_ONE_SHOT_MOD") then
    return { tap = "OSM " .. M.mods_label(kc & 0x1F), kind = "mods" }
  end
  for _, layer_kind in ipairs({
    { "QK_TO", "TO" },
    { "QK_MOMENTARY", "MO" },
    { "QK_DEF_LAYER", "DF" },
    { "QK_TOGGLE_LAYER", "TG" },
    { "QK_ONE_SHOT_LAYER", "OSL" },
    { "QK_LAYER_TAP_TOGGLE", "TT" },
  }) do
    if in_range(kc, layer_kind[1]) then
      local layer = kc - qmk.ranges[layer_kind[1]][1]
      return { tap = layer_kind[2] .. " " .. layer_label(ctx, layer), kind = "layer" }
    end
  end
  if in_range(kc, "QK_USER") then
    local n = kc - qmk.ranges.QK_USER[1]
    return { tap = (ctx.user_names or {})[n + 1] or ("USER " .. n), kind = "user" }
  elseif in_range(kc, "QK_KB") then
    return { tap = "KB " .. (kc - qmk.ranges.QK_KB[1]), kind = "kb" }
  end
  local entry = qmk.keycodes[kc]
  if entry ~= nil then
    local label = glyphs[entry.key] or entry.key:gsub("^QK_", ""):gsub("_", " ")
    return { tap = label, kind = "other" }
  end
  return { tap = string.format("%04X", kc), kind = "other" }
end

return M
