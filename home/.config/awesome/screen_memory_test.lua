-- Unit tests for screen_memory.lua. Run with:
--
--   bazel test //home/.config/awesome:screen_memory_test
--
-- The awesome C API is replaced by small fakes below that reproduce the parts
-- screen_memory.lua relies on, including the order in which awesome and
-- awful.tag emit signals when a screen goes away.

local screen_memory = require("screen_memory")

-- {{{ Fakes

-- Gives a table connect_signal/emit_signal like awesome's screen and tag
-- classes, which are called with a dot rather than as methods.
local function with_signals(object)
  local handlers = {}
  function object.connect_signal(name, handler)
    handlers[name] = handlers[name] or {}
    table.insert(handlers[name], handler)
  end
  function object.emit_signal(name, ...)
    for _, handler in ipairs(handlers[name] or {}) do
      handler(...)
    end
  end
  return object
end

-- A screen with tags "1" to "6", like connect_for_each_screen creates them.
local function fake_screen(outputs, geometry)
  local s = {
    outputs = outputs,
    geometry = geometry or { x = 0, y = 0, width = 1920, height = 1200 },
    tags = {},
  }
  for i = 1, 6 do
    s.tags[i] = { name = tostring(i), screen = s }
  end
  return s
end

local function fake_client(s, tag_names, options)
  options = options or {}
  local c = {
    valid = true,
    screen = s,
    floating = options.floating or false,
    maximized = options.maximized or false,
    _tags = {},
    _geometry = options.geometry or { x = 0, y = 0, width = 100, height = 100 },
  }
  function c:tags(new_tags)
    if new_tags then
      self._tags = new_tags
    end
    return self._tags
  end
  function c:geometry(g)
    if g then
      self._geometry = g
    end
    return self._geometry
  end
  for _, name in ipairs(tag_names) do
    for _, t in ipairs(s.tags) do
      if t.name == name then
        table.insert(c._tags, t)
      end
    end
  end
  return c
end

-- The screen, client and tag globals of awesome, plus helpers to add and
-- remove screens the way awesome does.
local function fake_capi()
  local capi = { screens = {}, clients = {} }

  -- `for s in screen do` calls screen(nil, previous) until it returns nil.
  capi.screen = with_signals(setmetatable({}, {
    __call = function (_, _, previous)
      if previous == nil then
        return capi.screens[1]
      end
      for i, s in ipairs(capi.screens) do
        if s == previous then
          return capi.screens[i + 1]
        end
      end
      return nil
    end,
  }))

  capi.client = { get_calls = 0 }
  function capi.client.get()
    capi.client.get_calls = capi.client.get_calls + 1
    local list = {}
    for _, c in ipairs(capi.clients) do
      table.insert(list, c)
    end
    return list
  end

  capi.tag = with_signals({})

  local function renumber()
    for i, s in ipairs(capi.screens) do
      s.index = i
    end
  end

  function capi.add_screen(s)
    table.insert(capi.screens, s)
    renumber()
    capi.screen.emit_signal("added", s)
  end

  -- Mirrors awesome's screen_refresh() together with awful.tag's "removed"
  -- handler: the screen is taken out of the screen list first, then the tags
  -- are asked for a new screen, the clients get dumped on the first tag of the
  -- first remaining screen, and finally the "removed" signal is emitted.
  function capi.remove_screen(s)
    for i, other in ipairs(capi.screens) do
      if other == s then
        table.remove(capi.screens, i)
        break
      end
    end
    renumber()
    for _, t in ipairs(s.tags) do
      capi.tag.emit_signal("request::screen", t)
    end
    local fallback = capi.screens[1]
    for _, c in ipairs(capi.clients) do
      if c.screen == s then
        c.screen = fallback
        c:tags({ fallback.tags[1] })
      end
    end
    capi.screen.emit_signal("removed", s)
  end

  function capi.add_client(c)
    table.insert(capi.clients, c)
    return c
  end

  return capi
end

-- A laptop with an external monitor to the right of it.
local function two_screen_setup()
  local capi = fake_capi()
  local laptop = fake_screen({ eDP = {} })
  local external = fake_screen({ ["DP-1"] = {} }, { x = 1920, y = 0, width = 2560, height = 1440 })
  capi.screens = { laptop, external }
  laptop.index, external.index = 1, 2
  return capi, laptop, external
end

local function tag_names(c)
  local names = {}
  for _, t in ipairs(c:tags()) do
    table.insert(names, t.name)
  end
  return table.concat(names, ",")
end

local function assert_placed(c, s, names, what)
  assert(c.screen == s, what .. ": on the wrong screen")
  assert(tag_names(c) == names, what .. ": expected tags " .. names .. ", got " .. tag_names(c))
end

-- }}}

-- {{{ Tests

local tests = {}

function tests.unplug_without_snapshot_keeps_default()
  local capi, laptop, external = two_screen_setup()
  screen_memory.setup(capi)
  local on_laptop = capi.add_client(fake_client(laptop, { "3" }))
  local on_external = capi.add_client(fake_client(external, { "4" }))

  capi.remove_screen(external)

  assert_placed(on_laptop, laptop, "3", "laptop client")
  assert_placed(on_external, laptop, "1", "external client")
end

function tests.replug_restores_screen_and_tag()
  local capi, laptop, external = two_screen_setup()
  local snapshots = screen_memory.setup(capi)
  local on_laptop = capi.add_client(fake_client(laptop, { "3" }))
  local on_external = capi.add_client(fake_client(external, { "4" }))

  capi.remove_screen(external)
  assert(snapshots["DP-1+eDP"], "two-screen layout not stored under the two-screen key")
  local external2 = fake_screen({ ["DP-1"] = {} })
  capi.add_screen(external2)

  assert_placed(on_laptop, laptop, "3", "laptop client")
  assert_placed(on_external, external2, "4", "external client")
end

function tests.unplug_restores_previous_single_screen_layout()
  local capi, laptop, external = two_screen_setup()
  screen_memory.setup(capi)
  local a = capi.add_client(fake_client(external, { "4" }))
  local b = capi.add_client(fake_client(laptop, { "2" }))

  capi.remove_screen(external)
  -- Rearrange while on the laptop alone.
  a:tags({ laptop.tags[5] })
  b:tags({ laptop.tags[6] })
  local external2 = fake_screen({ ["DP-1"] = {} })
  capi.add_screen(external2)
  assert_placed(a, external2, "4", "a after replug")
  assert_placed(b, laptop, "2", "b after replug")

  capi.remove_screen(external2)
  assert_placed(a, laptop, "5", "a after second unplug")
  assert_placed(b, laptop, "6", "b after second unplug")
end

function tests.multiple_tags_are_kept()
  local capi, laptop, external = two_screen_setup()
  screen_memory.setup(capi)
  local c = capi.add_client(fake_client(external, { "2", "4" }))

  capi.remove_screen(external)
  local external2 = fake_screen({ ["DP-1"] = {} })
  capi.add_screen(external2)

  assert_placed(c, external2, "2,4", "multi-tag client")
end

function tests.floating_geometry_is_relative_to_the_screen()
  local capi, laptop, external = two_screen_setup()
  screen_memory.setup(capi)
  local c = capi.add_client(fake_client(external, { "1" }, {
    floating = true,
    geometry = { x = 1920 + 300, y = 200, width = 640, height = 480 },
  }))

  capi.remove_screen(external)
  -- The monitor comes back on the other side of the laptop.
  local external2 = fake_screen({ ["DP-1"] = {} }, { x = -2560, y = 0, width = 2560, height = 1440 })
  capi.add_screen(external2)

  assert(c.screen == external2, "floating client not moved back")
  local g = c:geometry()
  assert(g.x == -2560 + 300 and g.y == 200 and g.width == 640 and g.height == 480,
         string.format("unexpected geometry %d,%d %dx%d", g.x, g.y, g.width, g.height))
end

function tests.maximized_state_follows_the_screen_configuration()
  local capi, laptop, external = two_screen_setup()
  screen_memory.setup(capi)
  local c = capi.add_client(fake_client(external, { "2" }))

  -- Not maximized with the monitor, maximized on the laptop alone.
  capi.remove_screen(external)
  assert(not c.maximized, "client maximized without a snapshot")
  c.maximized = true
  local external2 = fake_screen({ ["DP-1"] = {} })
  capi.add_screen(external2)
  assert_placed(c, external2, "2", "client after replug")
  assert(not c.maximized, "client still maximized with the monitor")

  capi.remove_screen(external2)
  assert_placed(c, laptop, "1", "client after second unplug")
  assert(c.maximized, "client not maximized again on the laptop")
end

function tests.maximized_client_keeps_its_unmaximized_geometry()
  local capi, laptop, external = two_screen_setup()
  local snapshots = screen_memory.setup(capi)
  -- awesome reports maximized clients as floating with the screen's geometry.
  local c = capi.add_client(fake_client(external, { "1" }, {
    floating = true,
    maximized = true,
    geometry = { x = 1920, y = 0, width = 2560, height = 1440 },
  }))

  capi.remove_screen(external)
  assert(snapshots["DP-1+eDP"][c].geometry == nil, "maximized geometry was remembered")
  -- Unmaximizing restores the geometry the client had before, which the
  -- snapshot must not overwrite.
  c.maximized = false
  c:geometry({ x = 100, y = 100, width = 640, height = 480 })
  local external2 = fake_screen({ ["DP-1"] = {} }, { x = 1920, y = 0, width = 2560, height = 1440 })
  capi.add_screen(external2)

  assert(c.screen == external2, "client not moved back")
  assert(c.maximized, "client not maximized again")
  local g = c:geometry()
  assert(g.x == 100 and g.y == 100 and g.width == 640 and g.height == 480,
         string.format("unexpected geometry %d,%d %dx%d", g.x, g.y, g.width, g.height))
end

function tests.closed_client_is_skipped_and_forgotten()
  local capi, laptop, external = two_screen_setup()
  local snapshots = screen_memory.setup(capi)
  local c = capi.add_client(fake_client(external, { "2" }))

  capi.remove_screen(external)
  -- Close the window while unplugged.
  c.valid = false
  table.remove(capi.clients, 1)
  c = nil
  collectgarbage()
  collectgarbage()

  local count = 0
  for _ in pairs(snapshots["DP-1+eDP"]) do
    count = count + 1
  end
  assert(count == 0, "closed client is still in the snapshot")

  local external2 = fake_screen({ ["DP-1"] = {} })
  capi.add_screen(external2)
end

function tests.new_client_stays_put_on_replug()
  local capi, laptop, external = two_screen_setup()
  screen_memory.setup(capi)
  capi.remove_screen(external)
  local c = capi.add_client(fake_client(laptop, { "3" }))

  local external2 = fake_screen({ ["DP-1"] = {} })
  capi.add_screen(external2)

  assert_placed(c, laptop, "3", "new client")
end

function tests.screens_without_outputs_use_their_index()
  local capi = fake_capi()
  local laptop = fake_screen({ eDP = {} })
  capi.screens = { laptop }
  laptop.index = 1
  local snapshots = screen_memory.setup(capi)

  local fake = fake_screen({})
  capi.add_screen(fake)
  local c = capi.add_client(fake_client(fake, { "2" }))
  capi.remove_screen(fake)

  assert(snapshots["eDP+screen2"], "no snapshot under the fallback name")
  assert_placed(c, laptop, "1", "client of the fake screen")

  capi.add_screen(fake_screen({}))
  assert(c.screen == capi.screens[2], "client not restored to the new fake screen")
  assert(tag_names(c) == "2", "client not restored to its tag")
end

function tests.one_snapshot_per_removal()
  local capi, laptop, external = two_screen_setup()
  screen_memory.setup(capi)
  capi.add_client(fake_client(external, { "1" }))

  capi.remove_screen(external)
  assert(capi.client.get_calls == 1, "expected one snapshot, got " .. capi.client.get_calls)

  capi.add_screen(fake_screen({ ["DP-1"] = {} }))
  capi.remove_screen(capi.screens[2])
  assert(capi.client.get_calls == 3, "expected three snapshots, got " .. capi.client.get_calls)
end

function tests.plug_without_snapshot_moves_nothing()
  local capi = fake_capi()
  local laptop = fake_screen({ eDP = {} })
  capi.screens = { laptop }
  laptop.index = 1
  screen_memory.setup(capi)
  local c = capi.add_client(fake_client(laptop, { "5" }))

  capi.add_screen(fake_screen({ ["DP-1"] = {} }))

  assert_placed(c, laptop, "5", "client")
end

-- }}}

-- {{{ Runner

local names = {}
for name in pairs(tests) do
  table.insert(names, name)
end
table.sort(names)

local failed = 0
for _, name in ipairs(names) do
  local ok, err = pcall(tests[name])
  if ok then
    print("PASS " .. name)
  else
    failed = failed + 1
    print("FAIL " .. name .. ": " .. tostring(err))
  end
end

print(string.format("%d tests, %d failed", #names, failed))
if failed > 0 then
  os.exit(1)
end

-- }}}
