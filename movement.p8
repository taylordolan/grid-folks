pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- todo
-- [x] represent positions as arrays
-- [x] support for a sequence of positions
-- [x] allow different transition speeds for different movements
-- [x] fix input delay
-- [x] allow one input during transitions

p = {}
-- screen position
p.s = {24, 24}
-- dest position
p.t = {}
-- other stuff
p.sprite = 001
p.frames_so_far = 0
p.vel_per_frame = 0
p.transition_speed = 1 -- in frames

e = {}
-- screen position
e.s = {24, 48}
-- target screen position
e.t = {}
-- other stuff
e.sprite = 002
e.frames_so_far = 0
e.vel_per_frame = 0
e.transition_speed = 1 -- in frames

actors = {p, e}
player_turn = true
tile_size = 16
input_log = {}

function move()
  for next in all(actors) do
    -- if there are one or more target destinations
    if #next.t > 0 then
      -- if this will be the first frame of this transition
      if next.frames_so_far == 0 then
        -- determine how many pixels to move the sprite each frame
        local x_px_per_frame = (next.t[1][1] - next.s[1]) / next.transition_speed
        local y_px_per_frame = (next.t[1][2] - next.s[2]) / next.transition_speed
        next.vel_per_frame = {x_px_per_frame, y_px_per_frame}
      end
      -- move the appropriate number of pixels on x and y
      next.s[1] = next.s[1] + next.vel_per_frame[1]
      next.s[2] = next.s[2] + next.vel_per_frame[2]
      -- increment the count of frames moved
      next.frames_so_far = next.frames_so_far + 1
      -- if the movement is complete
      if next.frames_so_far == next.transition_speed then
        -- this is to resolve any minor descrepancies between actual and intended screen positions
        -- i don't know if this is actually necessary, just being safe
        next.s[1] = next.t[1][1]
        next.s[2] = next.t[1][2]
        -- reset these values
        next.frames_so_far = 0
        next.vel_per_frame = null
        del(next.t, next.t[1])
      end
    end
  end
end

function _update()
  -- only accept two inputs
  -- accepting more might result in the players committing moves too early
  if #input_log < 2 then
    local input
    -- left
    if btnp(0) then
      input = {-1, 0}
    end
    -- right
    if btnp(1) then
      input = {1, 0}
    end
    -- up
    if btnp(2) then
      input = {0, -1}
    end
    -- down
    if btnp(3) then
      input = {0, 1}
    end
    add(input_log, input)
  end
  if #input_log > 0 and is_transitioning() == false then
    -- player turn
    local dir = input_log[1]
    input_log = {}
    local screen_x = p.s[1]
    local screen_y = p.s[2]
    local vel_x = tile_size * dir[1]
    local vel_y = tile_size * dir[2]
    local dest = {screen_x + vel_x , screen_y + vel_y}
    transition(p, {dest}, 4)
    -- enemy turn
    local dest2 = {e.s[1], e.s[2]}
    local dest1 = {e.s[1] + tile_size, e.s[2]}
    transition(e, {dest1, dest2}, 16)
  end
  move()
end

function _draw()
  cls()
  for next in all(actors) do
    spr(next.sprite, next.s[1], next.s[2])
  end
end

function transition(thing, targets, speed)
  thing.transition_speed = speed
  for next in all(targets) do
    add(thing.t, next)
  end
end

function is_transitioning()
  local transitioning = false
  for next in all(actors) do
    if #next.t > 0 then
      transitioning = true
    end
  end
  return transitioning
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
