pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- todo
-- [x] represent positions as arrays
-- [ ] support for a sequence of positions

p = {}
-- screen position
p.s = {24, 24}
-- dest position
p.t = {24, 24}
-- other stuff
p.sprite = 001
p.frames_so_far = 0
p.vel_per_frame = 0

e = {}
-- screen position
e.s = {24, 48}
-- target screen position
e.t = {24, 48}
-- other stuff
e.sprite = 002
e.frames_so_far = 0
e.vel_per_frame = 0

actors = {p, e}
player_turn = true
transition_speed = 4 -- in frames
input_delay = 0
tile_size = 16

function move()
  for next in all(actors) do
    -- if screen position differs from dest position
    if next.s[1] ~= next.t[1] or next.s[2] ~= next.t[2] then
      -- if this will be the first frame of this transition
      if next.frames_so_far == 0 then
        -- determine how many pixels to move the sprite each frame
        next.vel_per_frame = {(next.t[1] - next.s[1]) / transition_speed, (next.t[2] - next.s[2]) / transition_speed}
      end
      -- move the appropriate number of pixels on x and y
      next.s[1] = next.s[1] + next.vel_per_frame[1]
      next.s[2] = next.s[2] + next.vel_per_frame[2]
      -- increment the count of frames moved
      next.frames_so_far = next.frames_so_far + 1
      -- if the movement is complete
      if next.frames_so_far == transition_speed then
        -- this is to resolve any minor descrepancies between actual and intended screen positions
        -- i don't know if this is actually necessary, just being safe
        next.s[1] = next.t[1]
        next.s[2] = next.t[2]
        -- reset these values
        next.frames_so_far = 0
        next.vel_per_frame = 0
      end
    end
  end
end

function _update()
  if input_delay > 0 then
    input_delay = input_delay - 1
  -- player turn
  elseif player_turn == true then
    if btnp(0) then
      input_delay += transition_speed
      p.t[1] -= tile_size
      player_turn = false
    end
    if btnp(1) then
      input_delay += transition_speed
      p.t[1] += tile_size
      player_turn = false
    end
    if btnp(2) then
      input_delay += transition_speed
      p.t[2] -= tile_size
      player_turn = false
    end
    if btnp(3) then
      input_delay += transition_speed
      p.t[2] += tile_size
      player_turn = false
    end
  -- simulate enemy turn
  elseif player_turn == false then
    input_delay += transition_speed
    e.t[1] += tile_size
    player_turn = true
  end
  move()
end

function _draw()
  cls()
  for next in all(actors) do
    spr(next.sprite, next.s[1], next.s[2])
  end
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
