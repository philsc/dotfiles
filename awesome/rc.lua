require("awful")
require("awful.rules")
require("awful.autofocus")
require("scratch")
require("beautiful")
require("cal")
require("naughty")
require("awesompd/awesompd")
require("vicious")

screentags = {}
wibox = {}
promptbox = {}
layoutbox = {}
tasklist = {}
taglist = {}

--[[ CONFIGURATION ]]--

-- Define the theme
theme_file = awful.util.getdir("config") .. "/theme.lua"

-- Define default programs
terminal = "urxvt"
browser = "firefox"
editor = "vim"

-- Other configurations
netinterface = "wlan0"

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

volumebuttons = awful.util.table.join(
    awful.button({ }, 1, function () awful.util.spawn("amixer -q set Master toggle", false) end),
    awful.button({ }, 4, function () awful.util.spawn("amixer -q set Master 2dB+", false) end),
    awful.button({ }, 5, function () awful.util.spawn("amixer -q set Master 2dB-", false) end)
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
    awful.button({ }, 4, awful.tag.viewprev),
    awful.button({ }, 5, awful.tag.viewnext)
)

tasklist.buttons = awful.util.table.join(
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
    awful.key({ modkey,           }, ";", function () awful.util.spawn(terminal) end),
    awful.key({ modkey,           }, "d", function () awful.util.spawn(browser) end),
    awful.key({ modkey,           }, "/", function () scratch.drop(terminal, "top", "center", 1, 0.2, true) end),

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
    awful.key({ modkey,           }, "i", function () promptbox[mouse.screen]:run() end)
    -- TODO Add more here, such as an ssh prompt
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

-- Helper functions
cmd = function (program) return terminal .. " -e " .. program end
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
separator:add_signal("mouse::enter", function () shutdownmenu:hide() end)

-- Create a textclock widget
textclocklbl = createlabel("Sys")
textclock = awful.widget.textclock({ align = "right" })
cal.register(textclock, "<span color='green'>%s</span>")
systip = awful.tooltip({ objects = { textclocklbl } })
systip.update = function () return readcmd("syssummary -p '/ /home /media/gallifrey /media/dvd /media/usb'") end
textclock:add_signal("mouse::enter", function () shutdownmenu:hide() end)

-- Create a systray
systray = widget({ type = "systray" })

-- Create a shutdown dialog
sysbtnimg = image.argb32(14, 14, nil)
sysbtnimg:draw_rectangle(0, 0, 14, 14, true, beautiful.bg_normal)
sysbtnimg:draw_rectangle(4, 4, 6, 6, true, "#cc9393")
shutdownmenu = awful.menu({ items = {
  { "log off", awesome.quit, beautiful.menu_logoff },
  { "reboot", "sudo /sbin/reboot", beautiful.menu_reboot },
  { "halt", "sudo /sbin/shutdown", beautiful.menu_halt },
  { "cancel", function () shutdownmenu:hide() end }
}})
sysbtn = awful.widget.launcher({ image = sysbtnimg, menu = shutdownmenu })
sysbtn:add_signal("mouse::enter", function () shutdownmenu:show() end)

-- Network usage
dnlbl = createlabel('Down')
uplbl = createlabel('Up')
netdnwidget = widget({ type = "textbox" })
netupwidget = widget({ type = "textbox" })
netdnwidget.width, netupwidget.width = 36, 36
netdnwidget.align, netupwidget.align = "right", "right"
vicious.register(netdnwidget, vicious.widgets.net, '<span color="'
  .. beautiful.fg_netdn_widget ..'">${' .. netinterface .. ' down_kb}</span>', 3)
vicious.register(netupwidget, vicious.widgets.net, '<span color="'
  .. beautiful.fg_netup_widget ..'">${' .. netinterface .. ' up_kb}</span>', 3)
nettip = awful.tooltip({ objects = { dnlbl, uplbl, netdnwidget, netupwidget } })
nettip.update = function () return readcmd("ifsummary") end

-- Volume level
voltext = createlabel('Vol')
volbar = createbar(volumebuttons)
vicious.register(volbar, vicious.widgets.volume, "$1", 2, "Master")

-- Weather
weatherlbl = createlabel('Weather')
weatherwidget = widget({ type = "textbox" })
vicious.register(weatherwidget, vicious.widgets.weather, " ${tempc}°C ${sky} &amp; ${weather}", 1800, "CYKF")

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
  wibox[s] = awful.wibox({ position = "top", screen = s })
  wibox[s].widgets = {
    {
      layoutbox[s],
      taglist[s],
      promptbox[s],
      layout = awful.widget.layout.horizontal.leftright
    },
    sysbtn, systray,
    separator, textclock, textclocklbl,
    separator, weatherwidget, weatherlbl,
    separator, volbar.widget, voltext,
    separator, netupwidget, uplbl, netdnwidget, dnlbl,
    separator, musicwidget.widget, musiclbl,
    tasklist[s],
    layout = awful.widget.layout.horizontal.rightleft
  }
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

