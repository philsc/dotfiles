-- Unit tests for keymap_labels.lua. Run with:
--
--   bazel test //home/.config/awesome:keymap_labels_test
--
-- The keycode values are the ones the phil ErgoDox keymap actually uses, as
-- QMK encodes them (quantum/keycodes.h).

local labels = require("keymap_labels")

local ctx = {
  layer_names = { "BASE", "GAME", "MDIA", "SYMB" },
  user_names = { "VRSN" },
}

local failures = 0

local function check(kc, expected)
  local got = labels.decode(kc, ctx)
  local ok = got.tap == expected.tap and got.hold == expected.hold and got.kind == expected.kind
  if not ok then
    failures = failures + 1
    print(string.format("FAIL 0x%04X: expected tap=%q hold=%s kind=%q, got tap=%q hold=%s kind=%q",
      kc, expected.tap, tostring(expected.hold), expected.kind,
      got.tap, tostring(got.hold), got.kind))
  end
end

check(0x0000, { tap = "", kind = "none" })                         -- KC_NO
check(0x0001, { tap = "▽", kind = "trns" })                        -- KC_TRNS
check(0x0004, { tap = "A", kind = "basic" })                       -- KC_A
check(0x001E, { tap = "1", kind = "basic" })                       -- KC_1
check(0x002A, { tap = "⌫", kind = "basic" })                       -- KC_BSPC
check(0x003A, { tap = "F1", kind = "basic" })                      -- KC_F1
check(0x004A, { tap = "Home", kind = "basic" })                    -- KC_HOME
check(0x004B, { tap = "PgUp", kind = "basic" })                    -- KC_PGUP
check(0x00E1, { tap = "⇧", kind = "basic" })                       -- KC_LSFT
check(0x00E3, { tap = "◆", kind = "basic" })                       -- KC_LGUI
check(0x00E6, { tap = "AltGr", kind = "basic" })                   -- KC_RALT
check(0x00CD, { tap = "Ms↑", kind = "basic" })                     -- KC_MS_U
check(0x00D0, { tap = "Ms→", kind = "basic" })                     -- KC_MS_R
check(0x00D9, { tap = "Whl↑", kind = "basic" })                    -- KC_WH_U
check(0x00A8, { tap = "Mute", kind = "basic" })                    -- KC_MUTE
check(0x00AE, { tap = "⏯", kind = "basic" })                       -- KC_MPLY
check(0x00AB, { tap = "⏭", kind = "basic" })                       -- KC_MNXT
check(0x00B6, { tap = "Back", kind = "basic" })                    -- KC_WBAK
check(0x00BD, { tap = "Brt+", kind = "basic" })                    -- KC_BRIU

check(0x021E, { tap = "!", kind = "mods" })                        -- KC_EXLM = S(KC_1)
check(0x022F, { tap = "{", kind = "mods" })                        -- KC_LCBR = S(KC_LBRC)
check(0x0235, { tap = "~", kind = "mods" })                        -- KC_TILD = S(KC_GRV)
check(0x0104, { tap = "C-A", kind = "mods" })                      -- C(KC_A)
check(0x1B04, { tap = "C-⇧-◆-A", kind = "mods" })                  -- RCS(KC_A) | GUI

check(0x212A, { tap = "⌫", hold = "C", kind = "mod_tap" })         -- CTL_T(KC_BSPC)
check(0x222C, { tap = "␣", hold = "⇧", kind = "mod_tap" })         -- LSFT_T(KC_SPC)
check(0x244F, { tap = "→", hold = "A", kind = "mod_tap" })         -- LALT_T(KC_RGHT)
check(0x2129, { tap = "Esc", hold = "C", kind = "mod_tap" })       -- CTL_T(KC_ESC)
check(0x2F00, { tap = "Hyper", kind = "mod_tap" })                 -- ALL_T(KC_NO)
check(0x2700, { tap = "Meh", kind = "mod_tap" })                   -- MEH_T(KC_NO)

check(0x4335, { tap = "`", hold = "SYMB", kind = "layer_tap" })    -- LT(SYMB, KC_GRV)
check(0x4233, { tap = ";", hold = "MDIA", kind = "layer_tap" })    -- LT(MDIA, KC_SCLN)
check(0x4935, { tap = "`", hold = "L9", kind = "layer_tap" })      -- unnamed layer

check(0x5261, { tap = "TG GAME", kind = "layer" })                 -- TG(GAME)
check(0x5223, { tap = "MO SYMB", kind = "layer" })                 -- MO(SYMB)
check(0x52C3, { tap = "TT SYMB", kind = "layer" })                 -- TT(SYMB)
check(0x5200, { tap = "TO BASE", kind = "layer" })                 -- TO(BASE)
check(0x5240, { tap = "DF BASE", kind = "layer" })                 -- DF(BASE)
check(0x5282, { tap = "OSL MDIA", kind = "layer" })                -- OSL(MDIA)
check(0x52A2, { tap = "OSM ⇧", kind = "mods" })                    -- OSM(MOD_LSFT)
check(0x5041, { tap = "LM MDIA", hold = "C", kind = "layer" })     -- LM(MDIA, MOD_LCTL)

check(0x7E40, { tap = "VRSN", kind = "user" })                     -- SAFE_RANGE + 0
check(0x7E41, { tap = "USER 1", kind = "user" })                   -- unnamed custom keycode
check(0x7E00, { tap = "KB 0", kind = "kb" })                       -- QK_KB_0
check(0x7C03, { tap = "EE CLR", kind = "other" })                  -- EE_CLR
check(0x7C00, { tap = "Boot", kind = "other" })                    -- QK_BOOT
check(0x7C02, { tap = "DEBUG TOGGLE", kind = "other" })            -- DB_TOGG, via spec name
check(0x5FFF, { tap = "5FFF", kind = "other" })                    -- unknown

assert(labels.mods_label(0x1F) == "Hyper")
assert(labels.mods_label(0x05) == "C-A")

if failures > 0 then
  print(failures .. " failure(s)")
  os.exit(1)
end
print("OK")
