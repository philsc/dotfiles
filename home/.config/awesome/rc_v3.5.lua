local awful = require("awful")
awful.rules = require("awful.rules")
awful.autofocus = require("awful.autofocus")
local beautiful = require("beautiful")
local naughty = require("naughty")
local vicious = require("vicious")
local wibox = require("wibox")

screentags = {}
winbox = {}
promptbox = {}
layoutbox = {}
tasklist = {}
taglist = {}


-- Helper functions
cmd = function (program) return prefs.terminal .. " -e " .. program end

clientfocus = function (delta)
    awful.client.focus.byidx(delta)
    if client.focus then client.focus:raise() end
  end

createlabel = function (text)
    local label = wibox.widget.textbox()
    label:set_markup('<span font="Liberation Mono 7" color="' .. beautiful.fg_label .. '">' .. text .. '</span>')
    --label:margin({ top = 2, left = 6 })
    return wibox.layout.margin(label, 3, 3, 3, 3)
  end

createbar = function (buttons, settings)
  local bar = awful.widget.progressbar(settings or { height = 7, width = 25 })
  bar:set_color(beautiful.fg_widget)
  bar:set_border_color(beautiful.fg_widget)
  bar:set_background_color(beautiful.fg_off_widget)
  bar:buttons(buttons)
  local bar_layout = wibox.layout.margin(bar, 3, 3, 3, 3)
  return bar, bar_layout
end

readcmd = function (cmd)
  local fd = io.popen(cmd, "r")
  local text = fd:read("*a")
  io.close(fd)
  return text
end

notifications = {}
delayed_notifications = {}

create_notification = function (name, content)
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

create_delayed_notification = function (name, delay, content_generator)
  if delayed_notifications[name] then
    delayed_notifications[name]:emit_signal('timeout')
    delayed_notifications[name]:stop()
  end
  local delay_timer = timer { timeout = delay }
  delay_timer:connect_signal('timeout', function ()
    create_notification(name, content_generator())
    delayed_notifications[name]:stop()
    delayed_notifications[name] = nil
  end)
  delay_timer:start()
  delayed_notifications[name] = delay_timer
end

display_brightness = function ()
  create_delayed_notification('brightness', 0.2, function ()
      return {title = 'Brightness', text = readcmd('xbacklight -get')}
  end)
end

display_volume = function ()
end


--[[ CONFIGURATION ]]--

-- Define the theme
theme_file = awful.util.getdir("config") .. "/theme.lua"

-- Load user configuration
prefs = dofile(awful.util.getdir("config") .. "/prefs.lua")

if prefs.use_awesompd then
    require("awesompd/awesompd")
end

-- Tag table
tags = {
  names = { 1, 2, 3, 4, 5 },
  layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.floating,
    awful.layout.suit.floating,
    awful.layout.suit.floating,
    awful.layout.suit.floating,
  }
}

-- Layout table
layouts = {
  awful.layout.suit.floating,
  awful.layout.suit.tile,
}

--[[ KEY BINDINGS ]]--
modkey = "Mod4"

sound_helper = function (action)
    awful.util.spawn("amixer " .. prefs.sound.extra_options .. " set " ..
            prefs.sound.primary_control .. " " .. action, false)
  local get_volume = function ()
    local volume = readcmd('amixer ' .. prefs.sound.extra_options .. ' get ' ..
        prefs.sound.primary_control .. " | sed -n 's/" ..
        [==[.*\(Left\|Right\):.*\[\([[:digit:]]\+\).*\[\([[:alpha:]]\+\).*]==] ..
        '/' .. [==[\1: \2 (\3)]==] .. "/p'")
    return {title = 'Volume', text = volume}
  end
  create_delayed_notification('volume', 0.2, get_volume)
end

volumebuttons = awful.util.table.join(
    awful.button({ }, 1, function () sound_helper("toggle") end),
    awful.button({ }, 4, function () sound_helper("2%+ unmute") end),
    awful.button({ }, 5, function () sound_helper("2%- unmute") end)
)

layoutbox.buttons = awful.util.table.join(
    awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
    awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)
)

taglist.buttons = awful.util.table.join(
    awful.button({ }, 1, awful.tag.viewonly),
    awful.button({ modkey }, 1, awful.client.movetotag),
    awful.button({ }, 3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, awful.client.toggletag),
    awful.button({ }, 4, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end),
    awful.button({ }, 5, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end)
)

tasklist.buttons = awful.util.table.join(
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

globalkeys = awful.util.table.join(
    -- Screen selection
    awful.key({ modkey,           }, "p", awful.tag.viewprev ),
    awful.key({ modkey,           }, "n", awful.tag.viewnext ),

    -- Client selection
    awful.key({ modkey,           }, "j", function () clientfocus(1) end),
    awful.key({ modkey,           }, "k", function () clientfocus(-1) end),

    -- Standard programs
    awful.key({ modkey,           }, ";", function () awful.util.spawn(prefs.terminal) end),
    awful.key({ modkey,           }, "d", function () awful.util.spawn(prefs.browser) end),
    awful.key({ modkey, "Control" }, "m", function () awful.util.spawn("xscreensaver-command -l") end),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    -- Awesome WM config bindings
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    -- Prompt
    awful.key({ modkey,           }, "i", function () promptbox[mouse.screen]:run() end),
    -- TODO Add more here, such as an ssh prompt

    awful.key({                   }, "XF86MonBrightnessDown", function()
      awful.util.spawn("xbacklight -dec 5")
      display_brightness()
    end),
    awful.key({                   }, "XF86MonBrightnessUp", function()
      awful.util.spawn("xbacklight -inc 5")
      display_brightness()
    end),

    awful.key({ }, "XF86AudioMute", function () sound_helper("toggle") end),
    awful.key({ }, "XF86AudioLowerVolume", function () sound_helper("3%- unmute") end),
    awful.key({ }, "XF86AudioRaiseVolume", function () sound_helper("3%+ unmute") end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f", function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c", function (c) c:kill()                         end),
    awful.key({ modkey,           }, "t", awful.client.floating.toggle                     ),
    awful.key({ modkey, "Shift"   }, "r", function (c) c:redraw()                       end),
    awful.key({ modkey,           }, "g", function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize)
)

--[[ SETUP ]]--

-- Get Vicious to cache various values
vicious.cache(vicious.widgets.volume)

-- Load the appropriate theme
if awful.util.file_readable(theme_file) then
  beautiful.init(theme_file)
else
  beautiful.init("/usr/share/awesome/themes/zenburn/theme.lua")
end

-- Hold the screen tags
for s = 1, screen.count() do screentags[s] = awful.tag(tags.names, s, tags.layouts) end

-- Reusable separator
separator_raw = wibox.widget.imagebox(beautiful.widget_sep)
separator = wibox.layout.margin(separator_raw, 3, 3, 3, 3)

-- Create a textclock widget
textclocklbl = createlabel("Sys")
textclock = awful.widget.textclock()

-- Create a systray
systray = wibox.widget.systray()

-- Volume level
voltext = createlabel('Vol')
volbar, volbar_wrapper = createbar(volumebuttons)
vicious.register(volbar, vicious.widgets.volume, "$1", 2, prefs.sound.primary_control)

batwidgets = {}
-- Battery level
for bat, settings in pairs(prefs.battery) do
  batwidgets[bat] = {
    text = createlabel(bat),
    bar = nil,
    bar_wrapper = nil,
    remaining = wibox.widget.textbox(),
  }
  batwidgets[bat].bar, batwidgets[bat].bar_wrapper = createbar()
  wibox.layout.margin(batwidgets[bat].remaining, 3, 3, 3, 6)
  vicious.register(batwidgets[bat].bar, vicious.widgets.bat, "$2", settings.refresh_rate, bat)
  vicious.register(batwidgets[bat].remaining, vicious.widgets.bat, "$1 $3", settings.refresh_rate, bat)
end

musiclbl = nil
musidwidget = nil

if prefs.use_awesompd then
    -- Create an MPD client
    musiclbl = createlabel('Music')
    musicwidget = awesompd:create() -- Create awesompd widget
    musicwidget.font = "Liberation Mono" -- Set widget font 
    musicwidget.scrolling = false -- If true, the text in the widget will be scrolled
    musicwidget.output_size = 30 -- Set the size of widget in symbols
    musicwidget.update_interval = 10 -- Set the update interval in seconds
    musicwidget.path_to_icons = "/home/phil/.config/awesome/awesompd/icons" 
    musicwidget.jamendo_format = awesompd.FORMAT_MP3
    musicwidget.show_album_cover = true
    musicwidget.album_cover_size = 50
    musicwidget.mpd_config = "/etc/mpd.conf"
    musicwidget.browser = "firefox"
    musicwidget.ldecorator = " "
    musicwidget.rdecorator = " "
    musicwidget.servers = {
       { server = "localhost",
            port = 6600 },
    }
    musicwidget:register_buttons({ { "", awesompd.MOUSE_LEFT, musicwidget:command_toggle() },
                     { "Control", awesompd.MOUSE_SCROLL_UP, musicwidget:command_prev_track() },
               { "Control", awesompd.MOUSE_SCROLL_DOWN, musicwidget:command_next_track() },
               { "", awesompd.MOUSE_SCROLL_UP, musicwidget:command_volume_up() },
               { "", awesompd.MOUSE_SCROLL_DOWN, musicwidget:command_volume_down() },
               { "", awesompd.MOUSE_RIGHT, musicwidget:command_show_menu() } })
    musicwidget:run() -- After all configuration is done, run the widget
end

--[[ SCREEN SETUP ]]--

-- Create a wibox
for s = 1, screen.count() do
    -- Create a promptbox for each screen
    promptbox[s] = awful.widget.prompt()

    -- Create the layout box for each screen
    layoutbox[s] = awful.widget.layoutbox(s)
    layoutbox[s]:buttons(layoutbox.buttons)

    -- Create the tag list for each screen
    taglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist.buttons)

    -- Create the task list for each screen
    tasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, tasklist.buttons)

    -- Create the wibox
    winbox[s] = awful.wibox({ position = "top", screen = s })

    local left_layout = wibox.layout.fixed.horizontal()
    left_layout:add(layoutbox[s])
    left_layout:add(taglist[s])
    left_layout:add(promptbox[s])

    local right_layout = wibox.layout.fixed.horizontal()
    for bat,_ in pairs(prefs.battery) do
      right_layout:add(batwidgets[bat].text)
      right_layout:add(batwidgets[bat].bar_wrapper)
      right_layout:add(batwidgets[bat].remaining)
    end
    right_layout:add(voltext)
    right_layout:add(volbar_wrapper)
    right_layout:add(separator)
    right_layout:add(textclocklbl)
    right_layout:add(textclock)
    if s == prefs.main_screen then
        right_layout:add(separator)
        right_layout:add(systray)
    end

    local layout = wibox.layout.align.horizontal()
    layout:set_left(left_layout)
    layout:set_middle(tasklist[s])
    layout:set_right(right_layout)

    winbox[s]:set_widget(layout)
end

root.keys(globalkeys)

awful.rules.rules = {
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = true,
                     keys = clientkeys,
                     buttons = clientbuttons } },
    { rule = { class = "MPlayer" },
      properties = { floating = true } },
    { rule = { class = "gimp" },
      properties = { floating = true } },
}

--[[ SIGNALS ]]--

-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
    -- Enable sloppy focus
    c:connect_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Put the window at the end of others instead of setting it master.
        awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
