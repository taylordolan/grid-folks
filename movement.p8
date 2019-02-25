pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- todo
-- [ ] represent positions as arrays
-- [ ] support for a sequence of positions

p = {}
-- screen position
p.sx = 24
p.sy = 24
-- dest position
p.dx = 24
p.dy = 24
-- other stuff
p.sprite = 001
p.step_dist = 16
p.frames_taken = 0
p.vel_per_frame = 0

e = {}
-- screen position
e.sx = 24
e.sy = 48
-- dest position
e.dx = 24
e.dy = 48
-- other stuff
e.sprite = 002
e.step_dist = 16
e.frames_taken = 0
e.vel_per_frame = 0

actors = {p, e}
player_turn = true
transition_frames = 3
input_delay = 0

function move()
  for next in all(actors) do
    -- if screen position differs from dest position
    if next.sx ~= next.dx or next.sy ~= next.dy then
      -- if this will be the first frame of this transition
      if next.frames_taken == 0 then
        -- determine how many pixels to move the sprite each frame
        next.vel_per_frame = {(next.dx - next.sx) / transition_frames, (next.dy - next.sy) / transition_frames}
      end
      -- move the appropriate number of pixels on x and y
      next.sx = next.sx + next.vel_per_frame[1]
      next.sy = next.sy + next.vel_per_frame[2]
      -- increment the count of frames moved
      next.frames_taken = next.frames_taken + 1
      -- if the movement is complete
      if next.frames_taken == transition_frames then
        -- this is to resolve and minor descrepancies between actual and intended screen positions
        -- i don't know if this is actually necessary, just being safe
        next.sx = next.dx
        next.sy = next.dy
        -- reset these values
        next.frames_taken = 0
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
      input_delay += transition_frames
      p.dx -= p.step_dist
      player_turn = false
    end
    if btnp(1) then
      input_delay += transition_frames
      p.dx += p.step_dist
      player_turn = false
    end
    if btnp(2) then
      input_delay += transition_frames
      p.dy -= p.step_dist
      player_turn = false
    end
    if btnp(3) then
      input_delay += transition_frames
      p.dy += p.step_dist
      player_turn = false
    end
  -- simulate enemy turn
  elseif player_turn == false then
    input_delay += transition_frames
    e.dx += e.step_dist
    player_turn = true
  end
  move()
end

function _draw()
  cls()
  for next in all(actors) do
    spr(next.sprite, next.sx, next.sy)
  end
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
