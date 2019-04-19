pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

function _init()

  spawn_rates = {
    [1] = 16,
		[30] = 14,
		[60] = 12,
		[90] = 10,
    [120] = 8,
		[150] = 6,
		[180] = 5,
		[210] = 4,
		[240] = 3,
		[300] = 2,
		[360] = 1,
  }
  max_turns = 600
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
