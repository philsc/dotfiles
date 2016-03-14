local awful = require("awful")

prefs = {}

-- Define default programs
prefs.terminal = "urxvt"
prefs.browser = "firefox"
prefs.editor = "vim"

-- Sound configuration
prefs.sound = {}
prefs.sound.extra_options = '-D pulse'
prefs.sound.primary_control = 'Master 1+'

-- Screen preferences
prefs.main_screen = 1
prefs.brightness_step = 5

-- Battery preferences
prefs.battery = {}
--prefs.battery['BAT0'] = { refresh_rate = 10 }

return prefs
