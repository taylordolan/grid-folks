pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

function _init()

  -- this determines what the spawn rate is at the start of the game
  initial_spawn_rate = 16
  -- this determines the overall shape of the "spawn rate" curve
  -- the higher this is, the flatter the curve
  spawn_base = 1
  -- this determines how quickly we move through the curve throughout the game
  spawn_increment = 0.5

  -- spawn stuff below here shouldn't be messed with
  -- this gets updated whenever an enemy spawns
  last_spawned_turn = 0
  -- this tracks whether we've spawned a turn early
  spawned_early = false
  -- this is just so i don't have to set the initial_spawn_rate in an abstract way
  spawn_modifier = initial_spawn_rate + flr(sqrt(spawn_base))

  turns = 0
  max_turns = 600
  previous_spawn_rate = initial_spawn_rate
  new_spawn_rate = null
  graph_mode = true
  rates = {}

  for i = 1, max_turns do
    new_spawn_rate = get_spawn_rate()
    if turns == 1 or new_spawn_rate < previous_spawn_rate then
      rates[turns] = new_spawn_rate
    end
    turns = turns + 1
    spawn_base += spawn_increment
    previous_spawn_rate = new_spawn_rate
  end
end

function get_spawn_rate()
  return spawn_modifier - flr(sqrt(spawn_base))
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
      if rates[t] then
        y = flr(t / 10)
        print(t, x, y)
        x = 20
        for i = 1, rates[t] do
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
      if rates[t] then
        print("spawn rate of "..rates[t] .." at " ..t .." turns", x, y)
        y = y + 8
      end
    end
  end
end
