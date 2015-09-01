local awful = require("awful")
awful.rules = require("awful.rules")
awful.autofocus = require("awful.autofocus")
local beautiful = require("beautiful")
local naughty = require("naughty")
local vicious = require("vicious")
local wibox = require("wibox")
local widget = require("widget")

screentags = {}
winbox = {}
promptbox = {}
layoutbox = {}
tasklist = {}
taglist = {}

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
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
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

    awful.key({ modkey, "Shift"   }, "p", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey, "Shift"   }, "n", function () awful.screen.focus_relative(1) end),

    -- Client selection
    awful.key({ modkey,           }, "j", function () clientfocus(1) end),
    awful.key({ modkey,           }, "k", function () clientfocus(-1) end),

    -- Standard programs
    awful.key({ modkey,           }, ";", function () awful.util.spawn(prefs.terminal) end),
    awful.key({ modkey,           }, "d", function () awful.util.spawn(prefs.browser) end),

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

    -- Brightness Adjustments
    awful.key({ }, "XF86MonBrightnessDown", function () awful.util.spawn("xbacklight -dec 10") end),
    awful.key({ }, "XF86MonBrightnessUp", function () awful.util.spawn("xbacklight -inc 10") end),

    -- Volume Keys
    awful.key({ }, "XF86AudioMute", function () sound_helper("toggle") end),
    awful.key({ }, "XF86AudioLowerVolume", function () sound_helper("3%- unmute") end),
    awful.key({ }, "XF86AudioRaiseVolume", function () sound_helper("3%+ unmute") end),

    -- Prompt
    awful.key({ modkey,           }, "i", function () promptbox[mouse.screen]:run() end)
    -- TODO Add more here, such as an ssh prompt
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f", function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c", function (c) c:kill()                         end),
    awful.key({ modkey,           }, "t", awful.client.floating.toggle                     ),
    awful.key({ modkey,           }, "g", function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey, "Control" }, "p", function (c) awful.client.movetoscreen(c, c.screen-1) end),
    awful.key({ modkey, "Control" }, "n", function (c) awful.client.movetoscreen(c, c.screen+1) end),
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

-- Helper functions
cmd = function (program) return prefs.terminal .. " -e " .. program end
clientfocus = function (delta)
    awful.client.focus.byidx(delta)
    if client.focus then client.focus:raise() end
  end
createlabel = function (text)
    local label = widget({ type = "textbox" })
    label.text = '<span font="Liberation Mono 7" color="' .. beautiful.fg_label .. '">' .. text .. '</span>'
    label:margin({ top = 2, left = 6 })
    return label
  end
createbar = function (buttons, settings)
  local bar = awful.widget.progressbar(settings or { height = 7, width = 25 })
  bar:set_color(beautiful.fg_widget)
  bar:set_border_color(beautiful.fg_widget)
  bar:set_background_color(beautiful.fg_off_widget)
  bar.widget:buttons(buttons)
  awful.widget.layout.margins[bar.widget] = { top = 4, left = 4 }
  return bar
end
readcmd = function (cmd)
  local fd = io.popen(cmd, "r")
  local text = fd:read("*a")
  io.close(fd)
  return text
end

-- Hold the screen tags
for s = 1, screen.count() do screentags[s] = awful.tag(tags.names, s, tags.layouts) end

-- Reusable separator
separator = widget({ type = "imagebox" })
separator.image = image(beautiful.widget_sep)

-- Create a textclock widget
textclocklbl = createlabel("Sys")
textclock = awful.widget.textclock()

-- Create a systray
systray = widget({ type = "systray" })

-- Volume level
voltext = createlabel('Vol')
volbar = createbar(volumebuttons)
vicious.register(volbar, vicious.widgets.volume, "$1", 2, prefs.sound.primary_control)

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
    promptbox[s] = awful.widget.prompt({ layout = awful.widget.layout.horizontal.leftright })

    -- Create the layout box for each screen
    layoutbox[s] = awful.widget.layoutbox(s)
    layoutbox[s]:buttons(layoutbox.buttons)

    -- Create the tag list for each screen
    taglist[s] = awful.widget.taglist(s, awful.widget.taglist.label.all, taglist.buttons)

    -- Create the task list for each screen
    tasklist[s] = awful.widget.tasklist(function (c)
        return awful.widget.tasklist.label.currenttags(c, s)
    end, tasklist.buttons)

    -- Create the wibox
    winbox[s] = awful.wibox({ position = "top", screen = s })
    winbox[s].widgets = awful.util.table.join(
        {
            {
                layoutbox[s],
                taglist[s],
                promptbox[s],
                layout = awful.widget.layout.horizontal.leftright
            },
            s == prefs.main_screen and systray or nil,
            separator, textclock, textclocklbl,
            separator, volbar.widget, voltext,
        },
        (function ()
            if prefs.use_awesompd then
                return { separator, musicwidget.widget, musiclbl, }
            else
                return {}
            end
        end)(),
        {
            tasklist[s],
            layout = awful.widget.layout.horizontal.rightleft
        })
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
client.add_signal("manage", function (c, startup)
    -- Enable sloppy focus
    c:add_signal("mouse::enter", function(c)
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

client.add_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.add_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
