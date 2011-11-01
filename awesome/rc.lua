require("awful")
require("awful.rules")
require("awful.autofocus")
require("beautiful")
require("calendar")

screentags = {}
wibox = {}
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

-- Tag table
tags = {
  names = { 1, 2, 3, 4, 5 },
  layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile,
    awful.layout.suit.tile,
    awful.layout.suit.tile,
    awful.layout.suit.tile,
  }
}

-- Layout table
layouts = {
  awful.layout.suit.floating,
  awful.layout.suit.tile,
}

--[[ KEY BINDINGS ]]--
modkey = "Mod4"

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
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

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
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end)

    -- Prompt
    -- TODO Add more here
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end),
    awful.key({ modkey,           }, "t",      awful.client.floating.toggle                     ),
    awful.key({ modkey, "Shift"   }, "r",      function (c) c:redraw()                       end),
    awful.key({ modkey,           }, "g",      function (c) c.ontop = not c.ontop            end),
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

-- Hold the screen tags
for s = 1, screen.count() do screentags[s] = awful.tag(tags.names, s, tags.layouts) end

-- Reusable separator
separator = widget({ type = "imagebox" })
separator.image = image(beautiful.widget_sep)

-- Create a textclock widget
textclock = awful.widget.textclock({ align = "right" })
calendar.addCalendarToWidget(textclock, "<span color='green'>%s</span>")

-- Create a systray
systray = widget({ type = "systray" })

--[[ SCREEN SETUP ]]--

-- Create a wibox
for s = 1, screen.count() do
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
      layout = awful.widget.layout.horizontal.leftright
    },
    separator, textclock,
    separator, systray,
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
    -- Add a titlebar
    -- awful.titlebar.add(c, { modkey = modkey })

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

