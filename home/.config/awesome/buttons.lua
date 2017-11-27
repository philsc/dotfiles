local awful = require("awful")

-- Load user configuration
local prefs = dofile(awful.util.getdir("config") .. "/prefs.lua")

local buttons = {}

sound_helper = function (action)
  awful.util.spawn("amixer -q set " ..
                   prefs.sound.primary_control .. " " ..  action, false)
end

buttons.volume = awful.util.table.join(
  awful.button({ }, 1, function () sound_helper("toggle") end),
  awful.button({ }, 4, function () sound_helper("2dB+") end),
  awful.button({ }, 5, function () sound_helper("2dB-") end)
)

buttons.layout = awful.util.table.join(
  awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
  awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)
)

buttons.taglist = awful.util.table.join(
  awful.button({ }, 1, awful.tag.viewonly),
  awful.button({ modkey }, 1, awful.client.movetotag),
  awful.button({ }, 3, awful.tag.viewtoggle),
  awful.button({ modkey }, 3, awful.client.toggletag),
)

buttons.tasklist = awful.util.table.join(
  awful.button({ }, 1, function (c)
                         if c == client.focus then
                           c.minimized = true
                         else
                           if not c:isvisible() then
                             awful.tag.viewonly(c:tags()[1])
                           end
                           -- This will also un-minimize
                           -- the client, if needed
                           client.focus = c
                           c:raise()
                         end
                       end),
  awful.button({ }, 4, function () clientfocus(-1) end),
  awful.button({ }, 5, function () clientfocus(1) end)
)

-- The key to use for triggering awesome actions.
local modkey = "Mod4"

-- Modifier options.
local none = { }
local mod = { modkey, }
local shift = { modkey, "Shift" }
local control = { modkey, "Control" }

buttons.global = awful.util.table.join(
  -- Screen selection
  awful.key(mod, "p", awful.tag.viewprev ),
  awful.key(mod, "n", awful.tag.viewnext ),

  -- Client selection
  awful.key(mod, "j", function () clientfocus(1) end),
  awful.key(mod, "k", function () clientfocus(-1) end),

  -- Standard programs
  awful.key(mod, ";", function () awful.util.spawn(prefs.terminal) end),
  awful.key(mod, "d", function () awful.util.spawn(prefs.browser) end),
  awful.key(mod, "m", function () awful.util.spawn("xscreensaver-command -l") end),

  -- Layout manipulation
  awful.key(shift,   "j", function () awful.client.swap.byidx(  1)    end),
  awful.key(shift,   "k", function () awful.client.swap.byidx( -1)    end),
  awful.key(control, "j", function () awful.screen.focus_relative( 1) end),
  awful.key(control, "k", function () awful.screen.focus_relative(-1) end),
  awful.key(mod,     "u", awful.client.urgent.jumpto),
  awful.key(mod,     "l",     function () awful.tag.incmwfact( 0.05)    end),
  awful.key(mod,     "h",     function () awful.tag.incmwfact(-0.05)    end),
  awful.key(shift,   "h",     function () awful.tag.incnmaster( 1)      end),
  awful.key(shift,   "l",     function () awful.tag.incnmaster(-1)      end),
  awful.key(control, "h",     function () awful.tag.incncol( 1)         end),
  awful.key(control, "l",     function () awful.tag.incncol(-1)         end),
  awful.key(mod,     "space", function () awful.layout.inc(layouts,  1) end),
  awful.key(shift,   "space", function () awful.layout.inc(layouts, -1) end),

  -- Awesome WM config bindings
  awful.key(control, "r", awesome.restart),
  awful.key(shift,   "q", awesome.quit),

  -- Screen brightness keys
  awful.key(none, "XF86MonBrightnessDown", function() awful.util.spawn("xbacklight -dec 5") end),
  awful.key(none, "XF86MonBrightnessUp", function() awful.util.spawn("xbacklight -inc 5") end)
)

return buttons
