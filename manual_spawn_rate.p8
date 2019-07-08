pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

function _init()

  -- spawn_rates = {
  --   [001] = 12,
  --   [012] = 11,
	-- 	[024] = 10,
	-- 	[038] = 9,
	-- 	[055] = 8,
	-- 	[076] = 7,
	-- 	[102] = 6,
	-- 	[134] = 5,
	-- 	[173] = 4,
	-- 	[220] = 3,
	-- 	[276] = 2,
	-- 	[342] = 1,
  -- }
  function get_spawn_rates(base, starting_spawn_rate, offset)
    local spawn_rates = {
      [001] = starting_spawn_rate,
    }
    local previous = 1
    local increase = base
    for i=1, starting_spawn_rate - 1 do
      increase += i + offset
      local next = previous + increase
      spawn_rates[next] = starting_spawn_rate - i
      previous = next
    end
    return spawn_rates
  end
  spawn_rates = get_spawn_rates(11, 12, 3)
  max_turns = 800
  graph_mode = true
end

function _update()
  if btnp(5) then
    graph_mode = not graph_mode
  end
end

function _draw()
  cls()
  if graph_mode then
    x = 0
    y = 0
    for t = 1, max_turns do
      if spawn_rates[t] then
        y = flr(t / 5)
        print(t, x, y)
        x = 20
        for i = 1, spawn_rates[t] do
          pset(x, y, 7)
          x = x + 4
        end
        x = 0
      end
    end
  else
    x = 0
    y = 0
    for t = 1, max_turns do
      if spawn_rates[t] then
        print("spawn rate of "..spawn_rates[t] .." at " ..t .." turns", x, y)
        y = y + 8
      end
    end
  end
end
