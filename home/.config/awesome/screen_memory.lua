-- Remembers where windows were when a screen comes or goes.
--
-- Right before a screen is added or removed, a snapshot of every client's
-- screen, tags, maximized state and (for floating clients) geometry is taken
-- and stored under the screen configuration that was active at the time. After
-- the change, if a snapshot exists for the new configuration, it is restored;
-- otherwise awesome's default applies (clients of a removed screen end up on
-- the first tag of the surviving screen, adding a screen moves nothing).
-- Plugging a monitor back in therefore puts every window back where it was the
-- last time that monitor was connected, and a window that is maximized on the
-- laptop's screen alone but not when the external monitor is connected keeps
-- flipping between the two.
--
-- Screens are identified by their RandR output names, so the same monitor on a
-- different port counts as a different configuration. Snapshots only live in
-- memory and do not survive a restart of awesome.
--
-- The module does not depend on awful. It takes the awesome C API objects as a
-- parameter so it can be unit tested (see screen_memory_test.lua).

local M = {}

-- Returns a stable name for a screen: its sorted output names joined by "+".
-- Fake screens (screen.fake_add) have no outputs and fall back to their index.
local function output_name(s)
  local names = {}
  for name in pairs(s.outputs or {}) do
    table.insert(names, name)
  end
  if #names == 0 then
    return "screen" .. tostring(s.index)
  end
  table.sort(names)
  return table.concat(names, "+")
end

-- Returns the tag named `name` on screen `s`, or nil.
local function find_tag(s, name)
  for _, t in ipairs(s.tags) do
    if t.name == name then
      return t
    end
  end
  return nil
end

-- Sets up the signal handlers. `capi` defaults to the globals awesome provides
-- and only needs to be passed by tests. Returns the snapshot table.
function M.setup(capi)
  capi = capi or { screen = screen, client = client, tag = tag }

  -- Configuration key -> weak-keyed table of client -> record. Weak keys let
  -- closed clients fall out of old snapshots on their own.
  local snapshots = {}

  -- Returns the key of the current screen configuration. `include` is a screen
  -- that is no longer in the screen list but should count (the one being
  -- removed); `exclude` is one that is already listed but should not (the one
  -- being added).
  local function config_key(include, exclude)
    local names = {}
    local seen = false
    for s in capi.screen do
      if s ~= exclude then
        table.insert(names, output_name(s))
        seen = seen or s == include
      end
    end
    if include and not seen then
      table.insert(names, output_name(include))
    end
    table.sort(names)
    return table.concat(names, "+")
  end

  local function take_snapshot(key)
    local snapshot = setmetatable({}, { __mode = "k" })
    for _, c in ipairs(capi.client.get()) do
      local tags = {}
      for _, t in ipairs(c:tags()) do
        table.insert(tags, t.name)
      end
      if #tags > 0 and c.screen then
        local record = {
          output = output_name(c.screen),
          tags = tags,
          floating = c.floating,
          maximized = c.maximized,
        }
        -- A maximized client counts as floating, but its geometry is just the
        -- screen's, so only remember the geometry the user chose.
        if c.floating and not c.maximized then
          -- Relative to the screen so a screen that moved around still gets the
          -- window at the same spot.
          local g, sg = c:geometry(), c.screen.geometry
          record.geometry = {
            x = g.x - sg.x,
            y = g.y - sg.y,
            width = g.width,
            height = g.height,
          }
        end
        snapshot[c] = record
      end
    end
    snapshots[key] = snapshot
  end

  local function restore(key)
    local snapshot = snapshots[key]
    if not snapshot then
      return
    end
    local screens = {}
    for s in capi.screen do
      screens[output_name(s)] = s
    end
    for c, record in pairs(snapshot) do
      local s = screens[record.output]
      if c.valid and s then
        local tags = {}
        for _, name in ipairs(record.tags) do
          local t = find_tag(s, name)
          if t then
            table.insert(tags, t)
          end
        end
        if #tags > 0 then
          c.screen = s
          c:tags(tags)
          -- Unmaximizing restores the geometry from before the client was
          -- maximized, so it has to happen before the remembered one is set.
          c.maximized = record.maximized
          if record.floating and record.geometry then
            local g, sg = record.geometry, s.geometry
            c:geometry({
              x = sg.x + g.x,
              y = sg.y + g.y,
              width = g.width,
              height = g.height,
            })
          end
        end
      end
    end
  end

  -- awful.tag's "removed" handler emits request::screen on each tag of the
  -- vanishing screen before it moves any client, which makes it the moment to
  -- snapshot. awesome has already taken the screen out of the screen list by
  -- then, so it has to be added back in to get the key of the old
  -- configuration. It fires once per tag, so only the first one takes the
  -- snapshot.
  local removal_snapshot_taken = false
  capi.tag.connect_signal("request::screen", function (t)
    if not removal_snapshot_taken then
      removal_snapshot_taken = true
      take_snapshot(config_key(t.screen, nil))
    end
  end)

  -- Runs after awful.tag's handler moved the clients away. The screen is
  -- already gone from the screen list, so the remaining screens are the new
  -- configuration.
  capi.screen.connect_signal("removed", function ()
    removal_snapshot_taken = false
    restore(config_key(nil, nil))
  end)

  -- The screen is listed by the time "added" fires, but nothing has moved yet,
  -- so snapshotting without it still captures the layout from before the screen
  -- appeared.
  capi.screen.connect_signal("added", function (s)
    take_snapshot(config_key(nil, s))
    restore(config_key(nil, nil))
  end)

  return snapshots
end

return M
