-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
local vicious = require("vicious")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup").widget

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(awful.util.get_themes_dir() .. "default/theme.lua")

-- Local preferences.
local prefs = dofile(awful.util.getdir("config") .. "prefs.lua")

-- Override the theme's wallpaper with the preferred one, if set.
if prefs.wallpaper then
  beautiful.wallpaper = prefs.wallpaper
end

-- This is used later as the default terminal and editor to run.
terminal = prefs.terminal

vim_popup = awful.util.getdir("config") .. "/bin/vim_popup.sh " .. terminal

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.floating,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier,
    awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Helper functions
local function client_menu_toggle_fn()
    local instance = nil

    return function ()
        if instance and instance.wibox.visible then
            instance:hide()
            instance = nil
        else
            instance = awful.menu.clients({ theme = { width = 250 } })
        end
    end
end

readcmd = function (cmd)
  local fd = io.popen(cmd, "r")
  local text = fd:read("*a")
  io.close(fd)
  return text:gsub("^%s*(.-)%s*$", "%1")
end

-- Notification helper functions.
notifications = {}

create_notification = function (name, content_generator)
  content = content_generator()
  if notifications[name] then
    content['replaces_id'] = notifications[name].id
  end
  local notification = naughty.notify(content)
  notification.die = function ()
    naughty.destroy(notifications[name])
    notifications[name] = nil
  end
  notifications[name] = notification
end

-- Sound-related helpers.
get_volume = function ()
  local volume = readcmd([[pactl list sinks | awk '/^Sink /{print $_} /Volume: .*:/{print $2 " " $5 "\n" $9 " " $12}']])
  return {title = 'Volume', text = volume}
end

sound_helper = function (action, param)
  awful.spawn("pactl " .. action .. " " .. prefs.sound.default_sink .. " " .. param, false)
  create_notification('volume', get_volume)
end

-- Brightness-related helpers. The hardware backlight is controlled through
-- /sys/class/backlight and expressed in percent. The brightness file needs to
-- be writable by the user (see system/files/90-backlight.rules).
brightness_min, brightness_max = 1, 100

-- Returns the sysfs directory of the backlight device, or nil if there is none.
backlight_dir = function ()
  local device = prefs.backlight or readcmd('ls /sys/class/backlight'):match('[^\n]+')
  return device and ('/sys/class/backlight/' .. device) or nil
end

read_sysfs = function (path)
  local fd = io.open(path, 'r')
  if not fd then return nil end
  local value = fd:read('*l')
  io.close(fd)
  return tonumber(value)
end

-- Returns the current brightness in percent.
get_brightness = function ()
  local dir = backlight_dir()
  if not dir then return 0 end
  local value, max = read_sysfs(dir .. '/brightness'), read_sysfs(dir .. '/max_brightness')
  if not value or not max or max == 0 then return 0 end
  return math.floor(value / max * 100 + 0.5)
end

display_brightness = function ()
  create_notification('brightness', function ()
      return {title = 'Brightness', text = get_brightness() .. "%"}
  end)
end

-- Changes the brightness by delta percent, clamped to a sane range.
adjust_brightness = function (delta)
  local dir = backlight_dir()
  local max = dir and read_sysfs(dir .. '/max_brightness')
  if not max then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = 'Brightness', text = 'No backlight device found' })
    return
  end
  local percent = math.max(brightness_min, math.min(brightness_max, get_brightness() + delta))
  local fd, err = io.open(dir .. '/brightness', 'w')
  if not fd then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = 'Brightness', text = 'Cannot write backlight: ' .. tostring(err) })
    return
  end
  fd:write(string.format('%d\n', math.max(1, math.floor(percent / 100 * max + 0.5))))
  io.close(fd)
  display_brightness()
end

-- Battery-related helpers.
-- Returns the names of all batteries in /sys/class/power_supply (e.g. "BAT0").
detect_batteries = function ()
  local batteries = {}
  for name in readcmd('ls /sys/class/power_supply'):gmatch('[^\n]+') do
    local fd = io.open('/sys/class/power_supply/' .. name .. '/type', 'r')
    if fd then
      local kind = fd:read('*l')
      io.close(fd)
      if kind == 'Battery' then
        table.insert(batteries, name)
      end
    end
  end
  table.sort(batteries)
  return batteries
end

-- Creates a widget that draws a battery outline filled according to the
-- charge level. Call :update(state, percent) to change what is shown; state
-- is one of vicious' battery states ("+" charging, "-" discharging, "↯" full).
create_battery_icon = function ()
  local icon = wibox.widget.base.make_widget()
  icon.state = "⌁"
  icon.percent = 0

  function icon:update(state, percent)
    self.state = state
    self.percent = percent
    self:emit_signal("widget::redraw_needed")
  end

  function icon:fit(context, width, height)
    return 24, height
  end

  function icon:draw(context, cr, width, height)
    local body_w, body_h = 17, 9
    local nub_w, nub_h = 2, 4
    -- The state indicator (+/-) sits below the body.
    local indicator_gap, indicator_size = 3, 5
    local total_h = body_h + indicator_gap + indicator_size
    local x = 2
    local y = math.floor((height - total_h) / 2)
    local fg = beautiful.fg_normal or "#aaaaaa"

    -- Outline and nub.
    cr:set_line_width(1)
    cr:set_source(gears.color(fg))
    cr:rectangle(x + 0.5, y + 0.5, body_w - 1, body_h - 1)
    cr:stroke()
    cr:rectangle(x + body_w, y + (body_h - nub_h) / 2, nub_w, nub_h)
    cr:fill()

    -- Fill level.
    local fill_color = fg
    if self.state == "+" then
      fill_color = "#81a2be"
    elseif self.percent <= 15 then
      fill_color = "#cc6666"
    elseif self.percent <= 30 then
      fill_color = "#f0c674"
    end
    local fill_w = math.floor((body_w - 4) * self.percent / 100 + 0.5)
    if fill_w > 0 then
      cr:set_source(gears.color(fill_color))
      cr:rectangle(x + 2, y + 2, fill_w, body_h - 4)
      cr:fill()
    end

    -- Charging bolt.
    if self.state == "+" then
      local bx, by = x + 6, y + 1
      cr:set_source(gears.color(beautiful.bg_normal or "#222222"))
      cr:move_to(bx + 3, by)
      cr:line_to(bx, by + 4)
      cr:line_to(bx + 2.5, by + 4)
      cr:line_to(bx + 2, by + 7)
      cr:line_to(bx + 5, by + 3)
      cr:line_to(bx + 2.5, by + 3)
      cr:close_path()
      cr:fill()
    end

    -- Charging/discharging indicator: "+" or "-" centred below the body.
    if self.state == "+" or self.state == "-" then
      local cx = x + body_w / 2
      local cy = y + body_h + indicator_gap + indicator_size / 2
      cr:set_source(gears.color(fill_color))
      cr:set_line_width(1)
      cr:move_to(cx - indicator_size / 2, cy)
      cr:line_to(cx + indicator_size / 2, cy)
      if self.state == "+" then
        cr:move_to(cx, cy - indicator_size / 2)
        cr:line_to(cx, cy + indicator_size / 2)
      end
      cr:stroke()
    end
  end

  return icon
end

-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- Battery indicators. Batteries are auto-detected; prefs.battery can
-- override per-battery settings. Each battery is drawn as an icon whose
-- tooltip shows the details.
batwidgets = {}
battery_updaters = {}
for _, bat in ipairs(detect_batteries()) do
  local settings = prefs.battery[bat] or {}
  local refresh_rate = settings.refresh_rate or 30
  local icon = create_battery_icon()
  local tooltip = awful.tooltip({ objects = { icon } })
  local state_names = { ["+"] = "charging", ["-"] = "discharging", ["↯"] = "full" }

  local update = function ()
    -- args: $1 state (+ - ↯ ⌁), $2 percent, $3 time remaining
    local args = vicious.widgets.bat(nil, bat)
    icon:update(args[1], args[2])
    local text = string.format('%s: %d%% (%s)', bat, args[2], state_names[args[1]] or "unknown")
    if args[3] ~= "N/A" then
      text = text .. ", " .. args[3] .. " remaining"
    end
    tooltip.text = text
  end

  -- Poll periodically to track the charge level.
  gears.timer({
    timeout = refresh_rate,
    call_now = true,
    autostart = true,
    callback = update,
  })

  table.insert(batwidgets, icon)
  table.insert(battery_updaters, update)
end

-- Refresh immediately when UPower reports a change (e.g. the charger being
-- plugged in or unplugged) instead of waiting for the next poll.
if dbus and #battery_updaters > 0 then
  dbus.add_match("system", "type='signal',interface='org.freedesktop.DBus.Properties'," ..
                 "member='PropertiesChanged',path_namespace='/org/freedesktop/UPower/devices'")
  dbus.connect_signal("org.freedesktop.DBus.Properties", function (data)
    if data.member == "PropertiesChanged" and data.path:find("/org/freedesktop/UPower/devices/", 1, true) == 1 then
      for _, update in ipairs(battery_updaters) do
        update()
      end
    end
  end)
end


-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock()

-- Create a wibox for each screen and add it
local taglist_buttons = awful.util.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local tasklist_buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  -- Without this, the following
                                                  -- :isvisible() makes no sense
                                                  c.minimized = false
                                                  if not c:isvisible() and c.first_tag then
                                                      c.first_tag:view_only()
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, client_menu_toggle_fn()),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

num_tags = 6

tags = {}
for i=1, num_tags do
   tags[i] = tostring(i)
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    for i=1,num_tags-1 do
      local tag = awful.tag.add(tags[i], {
        screen = s,
        layout = awful.layout.layouts[1],
      })
      if i == 1 then
        tag.selected = true
      end
    end
    awful.tag.add(tags[num_tags], {
      screen = s,
      layout = awful.layout.layouts[2],
    })

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons)

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, tasklist_buttons, {
       spacing = 2
   })

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            s.mylayoutbox,
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist, -- Middle widget
        awful.util.table.join({ -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            mykeyboardlayout,
        }, batwidgets, {
            wibox.widget.systray(),
            mytextclock,
        }),
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = awful.util.table.join(
    -- Hitting the question mark brings up the help menu.
    awful.key({ modkey, "Shift"   }, "/",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),

    awful.key({ modkey,           }, "p",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "n",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey, "Control" }, "c", function () awful.spawn("maim-post-select") end,
              {description = "take a screenshot", group = "launcher"}),
    -- Delayed variant: the hotkey's X grab dismisses open popups/tooltips, so
    -- wait a few seconds to give them a chance to be re-opened.
    awful.key({ modkey, "Control", "Shift" }, "c",
        function ()
            naughty.notify({ text = "Screenshot in 3s...", timeout = 2 })
            awful.spawn("maim-post-select --delay=3")
        end,
        {description = "take a delayed screenshot (keeps popups)", group = "launcher"}),
    awful.key({ modkey,           }, "c", function () awful.spawn("maim-clip") end,
              {description = "take a screenshot", group = "launcher"}),
    awful.key({ modkey,           }, ";", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey,           }, "d", function () awful.spawn(prefs.browser) end,
              {description = "open a browser", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                      client.focus = c
                      c:raise()
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "i",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),
    awful.key({ modkey,           }, "e", function () awful.util.spawn(vim_popup) end,
              {description = "run vim to send keys to client", group = "launcher"}),

    -- Multimedia keys
    awful.key({ "Shift"           }, "XF86MonBrightnessDown", function() adjust_brightness(-1) end,
              {description = "decrease brightness by 1%", group = "screen"}),
    awful.key({ "Shift"           }, "XF86MonBrightnessUp", function() adjust_brightness(1) end,
              {description = "increase brightness by 1%", group = "screen"}),
    awful.key({                   }, "XF86MonBrightnessDown", function() adjust_brightness(-prefs.brightness_step) end,
              {description = "decrease brightness", group = "screen"}),
    awful.key({                   }, "XF86MonBrightnessUp", function() adjust_brightness(prefs.brightness_step) end,
              {description = "increase brightness", group = "screen"}),

    awful.key({ }, "XF86AudioMute", function () sound_helper("set-sink-mute", "toggle") end),
    awful.key({ }, "XF86AudioLowerVolume", function () sound_helper("set-sink-volume", "-5%") end),
    awful.key({ }, "XF86AudioRaiseVolume", function () sound_helper("set-sink-volume", "+5%") end),

    -- Misc
    awful.key({ modkey, "Control" }, "m", function () awful.util.spawn("xscreensaver-command -l") end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "maximize", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, num_tags do
    globalkeys = awful.util.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
        },
        class = {
          "Arandr",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Wpa_gui",
          "pinentry",
          "veromix",
          "xtightvncviewer"},

        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = false }
    },

    -- Set steam to always map on tag "6".
    { rule = { class = "Steam" },
      properties = { tag = "6" } },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup and
      not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = awful.util.table.join(
        awful.button({ }, 1, function()
            client.focus = c
            c:raise()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            client.focus = c
            c:raise()
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
        and awful.client.focus.filter(c) then
        client.focus = c
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- Put windows back where they were when a monitor is plugged in or out. This
-- has to come after connect_for_each_screen above so the tags of a new screen
-- exist by the time the windows are moved back to it.
require("screen_memory").setup()
-- }}}
