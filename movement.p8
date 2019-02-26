pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- todo
-- [x] represent positions as arrays
-- [x] support for a sequence of positions
-- [x] allow different transition speeds for different movements

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
-- transition_speed = 4 -- in frames
input_delay = 0
tile_size = 16

function move()
  for next in all(actors) do
    -- if screen position differs from dest position
    -- todo: eventually this should just check if #t > 0
    -- or maybe not. think about what happens when a button is pressed
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
  if input_delay > 0 then
    input_delay = input_delay - 1
  -- player turn
  elseif player_turn == true then
    -- left
    if btnp(0) then
      -- todo: this could work by checking if #d > 0
      -- assuming d is reset to {} after a successful transition
      -- then we wouldn't need input_delay
      -- actually it would have to check all actors. not sure if that's worth it or not
      input_delay += p.transition_speed
      local dest = {p.s[1] - tile_size, p.s[2]}
      transition(p, {dest}, 4)
      player_turn = false
    end
    -- right
    if btnp(1) then
      input_delay += p.transition_speed
      local dest = {p.s[1] + tile_size, p.s[2]}
      transition(p, {dest}, 4)
      player_turn = false
    end
    -- up
    if btnp(2) then
      input_delay += p.transition_speed
      local dest = {p.s[1], p.s[2] - tile_size}
      transition(p, {dest}, 4)
      player_turn = false
    end
    -- down
    if btnp(3) then
      input_delay += p.transition_speed
      local dest = {p.s[1], p.s[2] + tile_size}
      transition(p, {dest}, 4)
      player_turn = false
    end
  -- simulate enemy turn
  elseif player_turn == false then
    local dest2 = {e.s[1], e.s[2]}
    local dest1 = {e.s[1] + tile_size, e.s[2]}
    transition(e, {dest1, dest2}, 16)
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

function transition(thing, targets, speed)
  thing.transition_speed = speed
  for next in all(targets) do
    add(thing.t, next)
  end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
