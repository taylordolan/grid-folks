pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

p = {}
-- screen position
p.sx = 24
p.sy = 24
-- dest position
p.dx = 24
p.dy = 24
-- other stuff
p.sprite = 1
p.step_dist = 16

e = {}
-- screen position
e.sx = 24
e.sy = 48
-- dest position
e.dx = 24
e.dy = 48
-- other stuff
e.sprite = 2
e.step_dist = 16

actors = {p, e}
player_turn = true
frames = 3
input_delay = 0

function move()
  for next in all(actors) do
    if next.sx ~= next.dx or next.sy ~= next.dy then
      local frame_dist = next.step_dist / frames
      if next.dx > next.sx then
        next.sx = next.sx + frame_dist
      end
      if next.dy > next.sy then
        next.sy = next.sy + frame_dist
      end
      if next.dx < next.sx then
        next.sx = next.sx - frame_dist
      end
      if next.dy < next.sy then
        next.sy = next.sy - frame_dist
      end
    end
  end
end

function _update()
  if input_delay > 0 then
    input_delay = input_delay - 1
  elseif player_turn == true then
    if btnp(0) then
      input_delay += frames
      p.dx -= p.step_dist
      player_turn = false
    end
    if btnp(1) then
      input_delay += frames
      p.dx += p.step_dist
      player_turn = false
    end
    if btnp(2) then
      input_delay += frames
      p.dy -= p.step_dist
      player_turn = false
    end
    if btnp(3) then
      input_delay += frames
      p.dy += p.step_dist
      player_turn = false
    end
  elseif player_turn == false then
    input_delay += frames
    e.dx += e.step_dist
    player_turn = true
  end
  move()
end

function _draw()
  cls()
  spr(p.sprite, p.sx, p.sy)
  spr(e.sprite, e.sx, e.sy)
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
