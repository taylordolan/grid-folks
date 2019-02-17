pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

-- game state that gets refreshed on restart
function _init()

  turns = 0
  -- this determines what the spawn rate is at the start of the game
  initial_spawn_rate = 12
  -- this determines the overall shape of the "spawn rate" curve
  -- the higher this is, the flatter the curve
  -- i think the lowest usable value for this is 4
  spawn_base = 4
  -- this determines how quickly we move through the curve throughout the game
  spawn_increment = 0.1
  -- this gets updated whenever an enemy spawns
  last_spawned_turn = 0
  -- this is just so i don't have to set the initial_spawn_rate in an abstract way
  spawn_modifier = initial_spawn_rate + flr(sqrt(spawn_base))

  x = 0
  y = 0
  previous_spawn_rate = initial_spawn_rate
  new_spawn_rate = null
  cls()
end

function get_spawn_rate()
  return spawn_modifier - flr(sqrt(spawn_base))
end

function _update()
  turns = turns + 1
  spawn_base += spawn_increment
  new_spawn_rate = get_spawn_rate()
  printh(new_spawn_rate)
end

function _draw()
  if turns == 1 or new_spawn_rate < previous_spawn_rate then
    print("spawn rate of "..new_spawn_rate .." at " ..turns .." turns", x, y)
    previous_spawn_rate = new_spawn_rate
    y = y + 12
  end
end
