--[[
--Generic rc.lua that can load for multiple versions of awesome.
--]]

local awful = require("awful")
if not awesome then
  local awesome = require("awesome")
end

-- Figure out where the awesome configs are stored.
local confdir = awful.util.getdir("config")

-- Figure out which version of awesome we're running and source the 
-- corresponding rc.lua.
local version = string.match(awesome.version, "v%d+.%d+")
dofile(confdir .. "/rc_" .. version .. ".lua")
