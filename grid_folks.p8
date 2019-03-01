pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

-- todo
-- [x] players still aren't gaining health when enemies spawn to health tiles
-- [x] you shouldn't be able to shoot through players
-- [x] implement a delay before enemy movement
-- [x] allow restarting after game over by calling _init() again
-- [x] clean up _init()
-- [x] rename companion to ally throughout
-- [x] create a running list of buttons
-- [x] separate out wall generation and do it when it's not the player' turn
-- [x] come up with better names for pads and buttons
-- [x] build the game end state
-- [x] write a function that prints an overview of the spawn rate throughout the game
-- [x] add a debug mode where spawn rate and turn count show while playing
-- [x] add some variation in when exactly enemies appear
-- [x] implement transitions for movement
-- [x] maybe enemies should just enter stunned with full health. that would solve how to show they're stunned after being shot too
-- [x] fix sound stuff
-- [x] add bump transitions
-- [x] fix bug: stepping into walls still advances the turn
-- [x] add shoot animation
-- [ ] try a 5 x 7 board instead
-- [ ] when multiple enemies are present, they should act in random order
-- [ ] randomly distribute starting abilities
-- [ ] convert s{} to sx and sy
-- [ ] tweak spawn rates

-- game state that gets refreshed on restart
function _init()

  -- board size
  rows = 5
  cols = 9

  -- 2d array for the board
  board = {}
  for x = 1, cols do
    board[x] = {}
    for y = 1, rows do
      board[x][y] = {}
    end
  end

  -- graphics stuff that needs to be global
  screen_size = 128
  sprite_size = 8
  margin = 5
  tile_size = sprite_size + margin
  total_sprites_width = sprite_size * cols
  total_margins_width = margin * (cols - 1)
  total_map_width = total_sprites_width + total_margins_width
  padding_left = flr((screen_size - total_map_width) / 2)
  -- padding_top = flr((screen_size - total_map_height) / 2)
  padding_top = 20
  transition_frames = 4
  shot_points = {}
  shot_direction = {}
  shot_duration = 0

  -- sounds dictionary
  sounds = {
    music = 002,
    health = 026,
    score = 022,
    shoot = 029,
    dash = 025,
    step = 021,
    advance = 027,
    pad_step = 028,
    switch_heroes = 000,
    enemy_bump = 000,
    hero_bump = 000,
  }

  -- sprites dictionary
  sprites = {
    floor = 003,
    hero = 017,
    hero_dash = 019,
    hero_shoot = 021,
    enemy = 002,
    egg = 004,
    wall_right = 005,
    wall_down = 006,
    button_dash = 023,
    button_shoot = 024,
    button_health = 025,
    button_score = 026,
    pad_dash = 007,
    pad_shoot = 008,
    pad_health = 009,
    pad_score = 010,
    exit = 028,
  }

  -- colors dictionary
  colors = {
    black = 0,
    navy = 1,
    maroon = 2,
    forest = 3,
    brown = 4,
    dark_gray = 5,
    light_gray = 6,
    white = 7,
    red = 8,
    orange = 9,
    yellow = 10,
    green = 11,
    blue = 12,
    purple = 13,
    pink = 14,
    tan = 15,
  }

  -- some game state
  score = 0
  turns = 0
  player_turn = true
	game_lost = false
  game_won = false
  hero_a_active = true
  has_switched = false
  has_killed = false
  debug_mode = false
  delay = 0

  -- lists of things
  heroes = {}
  enemies = {}
  -- eggs = {}
  pads = {}
  buttons = {}
  exits = {}

  -- log of recent user input
  input_queue = {}

  -- initial buttons
  set_tile(new_button("dash"), {5,2})
  set_tile(new_button("shoot"), {5,4})
  set_tile(new_button("health"), {6,3})
  set_tile(new_button("score"), {4,3})

  -- initial walls
  refresh_walls()

  -- initial pads
  refresh_pads()

  -- heroes
  hero_a = create_hero()
  hero_b = create_hero()
  heroes = {hero_a, hero_b}
  set_tile(hero_a, {4,2})
  set_tile(hero_b, {6,4})

	-- initial enemy
  -- local new_egg = new_egg()
  -- deploy(new_egg, {"hero", "enemy", "egg"})
  -- local new_enemy = new_enemy()
  -- deploy(new_enemy, {"hero", "enemy"})
  spawn_enemy()

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

  -- start the music!
  music(sounds.music)
end

function get_spawn_rate()
  return spawn_modifier - flr(sqrt(spawn_base))
end

function should_spawn()
  local spawn_rate = get_spawn_rate()
  local should_spawn = false

  -- if it's one turn before reaching the spawn rate
  if turns - last_spawned_turn == spawn_rate - 1 then
    -- 50% chance of spawning early
    if flr(rnd(2)) == 1 then
      -- if spawning early, then mark it in a global variable so we don't also spawn the next turn
      spawned_early = true
      should_spawn = true
    end
  -- if this turn has actually reached the spawn rate
  elseif turns - last_spawned_turn >= spawn_rate then
    if not spawned_early then
      should_spawn = true
    end
    -- reset this variable for next round
    spawned_early = false
  end
  return should_spawn
end

-- function spawn_egg()
--   local new_egg = new_egg()
--   deploy(new_egg, {"hero", "enemy", "egg"})
--   last_spawned_turn = turns
-- end

function spawn_enemy()
  local new_enemy = new_enemy()
  deploy(new_enemy, {"hero", "enemy"})
  last_spawned_turn = turns
end

function _update()

  update_hero_sprites()

  if game_won or game_lost then
    if btnp(5) then
      _init()
    end
    return
  end

  if btnp(4) then
    debug_mode = not debug_mode
    -- for testing game end state
    -- if #exits ~= 2 then
    --   add_button()
    --   refresh_pads()
    -- end
  end

  -- for complicated reasons, this value should be set to
  -- one *less* than the maximum allowed number of rapid player inputs
  if #input_queue < 2 then
    local input
    -- left
    if btnp(0) then
      input = {-1, 0}
    -- right
    elseif btnp(1) then
      input = {1, 0}
    -- up
    elseif btnp(2) then
      input = {0, -1}
    -- down
    elseif btnp(3) then
      input = {0, 1}
    elseif btnp(5) then
      input = 5
    end
    add(input_queue, input)
  end

  if delay > 0 then
    delay -= 1
  -- player turn
  elseif player_turn == true and #input_queue > 0 then
    if input_queue[1] == 5 then
      hero_a_active = not hero_a_active
      has_switched = true
      sfx(sounds.switch_heroes, 3)
    else
      local active_hero
      if hero_a_active then
        active_hero = hero_a
      else
        active_hero = hero_b
      end
      -- act() controls whether `player_turn` is set to false because
      -- it's possible to not act (e.g. moving toward a wall)
      active_hero.act(active_hero, input_queue[1])
    end
    del(input_queue, input_queue[1])
  -- enemy turn
  elseif player_turn == false then
    update_hero_abilities()
    if should_advance() then
      add_button()
      refresh_pads()
      refresh_walls()
    end
    -- hatch_eggs()
    for next in all(enemies) do
      next.update(next)
    end
    if should_spawn() then
      -- spawn_egg()
      spawn_enemy()
    end
    -- update game state
    turns = turns + 1
    player_turn = true
    spawn_base += spawn_increment
  end

  -- update screen positions
  for next in all(heroes) do
    update_screen_position(next)
  end
  for next in all(enemies) do
    update_screen_position(next)
  end

  if delay <= 0 then
    -- game won test
    local a_xy = {hero_a.x, hero_a.y}
    local b_xy = {hero_b.x, hero_b.y}
    local reached_exit_a = find_type_in_tile("exit", a_xy)
    local reached_exit_b = find_type_in_tile("exit", b_xy)
    if reached_exit_a and reached_exit_b then
      game_won = true
    end
    -- game lost test
    if hero_a.health <= 0 or hero_b.health <= 0 then
      game_lost = true
    end
  end
end

function smallcaps(s)
  local d=""
  local l,c,t=false,false
  for i=1,#s do
    local a=sub(s,i,i)
    if a=="^" then
      if(c) d=d..a
      c=not c
    elseif a=="~" then
      if(t) d=d..a
      t,l=not t,not l
    else
      if c==l and a>="a" and a<="z" then
        for j=1,26 do
          if a==sub("abcdefghijklmnopqrstuvwxyz",j,j) then
            a=sub("\65\66\67\68\69\70\71\72\73\74\75\76\77\78\79\80\81\82\83\84\85\86\87\88\89\90\91\92",j,j)
            break
          end
        end
      end
      d=d..a
      c,t=false,false
    end
  end
  return d
end

function update_screen_position(thing)
  if thing.td and thing.td > 0 then
    thing.td -= 1
  -- if there are one or more target destinations
  elseif #thing.t > 0 then
    -- if this will be the first frame of this transition
    if thing.frames_so_far == 0 then
      -- determine how many pixels to move the sprite each frame
      local x_px_per_frame = (thing.t[1][1] - thing.s[1]) / thing.transition_speed
      local y_px_per_frame = (thing.t[1][2] - thing.s[2]) / thing.transition_speed
      thing.vel_per_frame = {x_px_per_frame, y_px_per_frame}
    end
    -- move the appropriate number of pixels on x and y
    thing.s[1] = thing.s[1] + thing.vel_per_frame[1]
    thing.s[2] = thing.s[2] + thing.vel_per_frame[2]
    -- increment the count of frames moved
    thing.frames_so_far = thing.frames_so_far + 1
    -- if the movement is complete
    if thing.frames_so_far == thing.transition_speed then
      -- this is to resolve any minor descrepancies between actual and intended screen positions
      -- i don't know if this is actually necessary, just being safe
      thing.s[1] = thing.t[1][1]
      thing.s[2] = thing.t[1][2]
      -- reset these values
      thing.frames_so_far = 0
      thing.vel_per_frame = null
      del(thing.t, thing.t[1])
    end
  end
end

function set_target_positions(thing, positions, speed)
  thing.transition_speed = speed
  for next in all(positions) do
    add(thing.t, next)
  end
end

function set_bump_transition(thing, direction, total_transition_time, transition_delay)
  local origin_position = {thing.s[1], thing.s[2]}
  local adjust_position = {thing.s[1] + direction[1], thing.s[2] + direction[2]}
  set_target_positions(thing, {adjust_position, origin_position}, total_transition_time / 2)
  thing.td = transition_delay
end

-- function is_transitioning()
--   local transitioning = false
--   for next in all(actors) do
--     if #next.t > 0 then
--       transitioning = true
--     end
--   end
--   return transitioning
-- end

-- function is_transitioning_heroes()
--   local transitioning = false
--   for next in all(heroes) do
--     if #next.t > 0 then
--       transitioning = true
--     end
--   end
--   return transitioning
-- end

-- function is_transitioning_enemies()
--   local transitioning = false
--   for next in all(enemies) do
--     if #next.t > 0 then
--       transitioning = true
--     end
--   end
--   return transitioning
-- end

function _draw()

	cls()
  local text_color = 07
  local background_color = 00
  local floor_color = 07
  local wall_color = 07

  local total_sprites_height = sprite_size * rows
  local total_margins_height = margin * (rows - 1)
  local total_map_height = total_sprites_height + total_margins_height

  local rect_origin = {padding_left - ceil(margin / 2), padding_top - ceil(margin / 2)}
  local rect_opposite = {padding_left + total_map_width - 1 + ceil(margin / 2), padding_top + total_map_height - 1 + ceil(margin / 2)}

  function draw_floor()
    rectfill(rect_origin[1] + 2, rect_origin[2] + 2, rect_opposite[1] - 2, rect_opposite[2] - 2, floor_color)
  end

  function draw_background()
    rectfill(0, 0, 127, 127, background_color)
  end

  function draw_outlines()
    rect(rect_origin[1], rect_origin[2], rect_opposite[1], rect_opposite[2], wall_color)
    rect(rect_origin[1] - 1, rect_origin[2] - 1, rect_opposite[1] + 1, rect_opposite[2] + 1, background_color)
  end

  function draw_shot(a, b, dir)
    local ax = a[1]
    local ay = a[2]
    local bx = b[1]
    local by = b[2]
    -- up
    if pair_equal(dir, {0, -1}) then
      ax += 3
      bx += 3
      ay -= 2
      by += 8
    -- down
    elseif pair_equal(dir, {0, 1}) then
      ax += 3
      bx += 3
      ay += 9
      by -= 1
    -- left
    elseif pair_equal(dir, {-1, 0}) then
      ax -= 2
      bx += 7
      ay += 3
      by += 3
    -- right
    elseif pair_equal(dir, {1, 0}) then
      ax += 8
      bx -= 2
      ay += 3
      by += 3
    end
    rectfill(ax, ay, bx, by, colors.green)
  end

  function draw_score()
    local text = score.. " gold"
    print(smallcaps(text), 128 - padding_left + ceil(margin / 2) - (#text * 4) + 1, 06, 09)
    if not debug_mode then
      print(smallcaps("grid folks"), padding_left - ceil(margin / 2), 06, 07)
    else
      local spawn_rate = get_spawn_rate()
      print(smallcaps(turns .." , " ..spawn_rate), padding_left - ceil(margin / 2), 06, 07)
    end
  end

  function draw_instructions()
    draw_button_instructions()
  end

  function draw_intro_instructions()
    palt(0, false)
    palt(15, true)
    local x_pos = padding_left - ceil(margin / 2) + 26
    local y_pos = 90
    local line_height = 11
    print(smallcaps("\151"), x_pos, y_pos)
    print(smallcaps("to switch"), x_pos + 12, y_pos)
    spr(sprites.hero, x_pos + 51, y_pos - 2)
    spr(sprites.hero + 1, x_pos + 59, y_pos - 2)
    y_pos += line_height

    print(smallcaps("bump"), x_pos, y_pos)
    spr(sprites.enemy, x_pos + 19, y_pos - 1)
    print(smallcaps("to attack"), x_pos + 29, y_pos)
    palt()
  end

  function draw_button_instructions()
    palt(0, false)
    palt(15, true)
    local x_pos = padding_left - ceil(margin / 2) - 1
    local y_pos = 90
    local line_height = 11

    -- shoot
    spr(sprites.hero, x_pos, y_pos - 2)
    spr(sprites.button_shoot, x_pos + 7, y_pos - 2)
    print("=", x_pos + 18, y_pos, 06)
    spr(sprites.hero + 1, x_pos + 24, y_pos - 2)
    print(smallcaps("shoot"), x_pos + 32, y_pos, text_color)
    y_pos += line_height

    -- dash
    spr(sprites.hero, x_pos, y_pos - 2)
    spr(sprites.button_dash, x_pos + 7, y_pos - 2)
    print("=", x_pos + 18, y_pos, 06)
    spr(sprites.hero + 1, x_pos + 24, y_pos - 2)
    print(smallcaps("dash"), x_pos + 32, y_pos, text_color)
    y_pos += line_height

    -- advance
    spr(sprites.hero, x_pos, y_pos - 2)
    spr(011, x_pos + 7, y_pos - 2)
    print("+", x_pos + 18, y_pos, 06)
    spr(sprites.hero + 1, x_pos + 24, y_pos - 2)
    spr(011, x_pos + 31, y_pos - 2)
    print("=", x_pos + 42, y_pos, 06)
    spr(012, x_pos + 48, y_pos - 2)

    x_pos += 79
    y_pos -= line_height
    y_pos -= line_height

    -- health
    spr(sprites.enemy, x_pos, y_pos - 2)
    spr(sprites.button_health, x_pos + 7, y_pos - 2)
    print("=", x_pos + 18, y_pos, 06)
    print(smallcaps("heal"), x_pos + 25, y_pos, text_color)
    y_pos += line_height

    -- gold
    spr(sprites.enemy, x_pos, y_pos - 2)
    spr(sprites.button_score, x_pos + 7, y_pos - 2)
    print("=", x_pos + 18, y_pos, 06)
    print(smallcaps("gold"), x_pos + 25, y_pos, text_color)

    palt()
  end

  function draw_wall_right(x_pos, y_pos)
    palt(0, false)

    local x3 = x_pos + sprite_size + flr(margin / 2)
    local y3 = y_pos - ceil(margin / 2)
    local x4 = x_pos + sprite_size + flr(margin / 2)
    local y4 = y_pos + sprite_size + flr(margin / 2)

    local x1 = x3 - 1
    local y1 = y3 - 1
    local x2 = x4 + 1
    local y2 = y4 + 1

    rectfill(x1, y1, x2, y2, 0)
    rectfill(x3, y3, x4, y4, wall_color)
    palt()
  end

  function draw_wall_down(x_pos, y_pos)
    palt(0, false)

    local x3 = x_pos - ceil(margin / 2)
    local y3 = y_pos + sprite_size + flr(margin / 2)
    local x4 = x_pos + sprite_size + flr(margin / 2)
    local y4 = y_pos + sprite_size + flr(margin / 2)

    local x1 = x3 - 1
    local y1 = y3 - 1
    local x2 = x4 + 1
    local y2 = y4 + 1

    rectfill(x1, y1, x2, y2, 0)
    rectfill(x3, y3, x4, y4, wall_color)
    palt()
  end

  function draw_path_right(x_pos, y_pos)
    local x1 = x_pos + sprite_size + flr(margin / 2) - 1
    local y1 = y_pos
    local x2 = x_pos + sprite_size + flr(margin / 2) + 1
    local y2 = y_pos + sprite_size - 1
    rectfill(x1, y1, x2, y2, floor_color)
  end

  function draw_path_down(x_pos, y_pos)
    local x1 = x_pos
    local y1 = y_pos + sprite_size + flr(margin / 2) - 1
    local x2 = x_pos + sprite_size - 1
    local y2 = y_pos + sprite_size + flr(margin / 2) + 1
    rectfill(x1, y1, x2, y2, floor_color)
  end

  function draw_health(x_pos, y_pos, amount)
    for i = 1, amount do
      pset(x_pos + 7, y_pos + 8 - i, 8)
    end
  end

  draw_background()
  draw_floor()
  draw_score()
  draw_instructions()

	for x = 1, cols do
		for y = 1, rows do

			local x_pos = (x - 1) * sprite_size + (x - 1) * margin + padding_left
			local y_pos = (y - 1) * sprite_size + (y - 1) * margin + padding_top

			-- draw the sprite for everything at the current position
			if #board[x][y] > 0 then
				for next in all(board[x][y]) do
          -- draw walls
          if next.type == "wall_right" then
            draw_wall_right(x_pos, y_pos)
          elseif next.type == "wall_down" then
            draw_wall_down(x_pos, y_pos)
          -- draw the thing's sprite
          else
            palt(0, false)
            palt(15, true)
            local sprite = next.sprite
            spr(sprite, next.s[1], next.s[2])
              -- draw a health bar for things with health
            if (next.health) then
              draw_health(next.s[1], next.s[2], next.health)
            end
            palt()
          end
				end
			end
		end
	end

  if #shot_points > 0 then
    draw_shot(shot_points[1], shot_points[2], shot_direction)
    shot_duration -= 1
    if shot_duration <= 0 then
      shot_points = {}
      shot_direction = {}
    end
  end
  draw_outlines()

  if game_won then
    local msg = "escaped!"
    local msg_x = 64 - (#msg * 4) / 2
    print(smallcaps(msg), msg_x, 47, 11)
  end

  if game_lost then
		local msg = "dead"
		local msg_x = 64 - (#msg * 4) / 2
		print(smallcaps(msg), msg_x, 47, 8)
	end
end

--[[
  helper functions
--]]

-- check if a location is on the board
function location_exists(tile)
  local tile_x = tile[1]
  local tile_y = tile[2]
  if
    tile_x < 1 or
    tile_x > cols or
    tile_y < 1 or
    tile_y > rows
  then
	  return false
	end
  return true
end

-- move a thing to a tile
function set_tile(thing, dest)

  -- do nothing if dest is off the board
	if location_exists(dest) == false then
	  return
	end

	-- remove it from its current tile
  if thing.x and thing.y then
    del(board[thing.x][thing.y], thing)
  end

	-- add it to the dest tile
	add(board[dest[1]][dest[2]], thing)

  -- set its x and y values
  thing.x = dest[1]
  thing.y = dest[2]

  if thing.s and #thing.s > 0 then
    local screen_x = thing.s[1]
    local screen_y = thing.s[2]
    local screen_dest = board_position_to_screen_position({dest[1], dest[2]})
    set_target_positions(thing, {screen_dest}, transition_frames)
  else
    local screen_dest = board_position_to_screen_position({dest[1], dest[2]})
    thing.s = {screen_dest[1], screen_dest[2]}
  end

  -- this is here for now because enemy buttons need to be triggered when enemies step or are deployed
  -- todo: this should probably be done differently somehow
  if thing.type == "enemy" then
    trigger_enemy_buttons(dest)
  end

  if thing.type == "hero" and find_type_in_tile("pad", dest) then
    if find_type_in_tile("pad", dest) then
      sfx(sounds.pad_step, 3)
    else
      sfx(sounds.step, 3)
    end
  end
end

function board_position_to_screen_position(board_position)
  local board_x = board_position[1]
  local board_y = board_position[2]
  local x_pos = (board_x - 1) * sprite_size + (board_x - 1) * margin + padding_left
  local y_pos = (board_y - 1) * sprite_size + (board_y - 1) * margin + padding_top
  return {x_pos, y_pos}
end

-- deploys a thing to a random tile
-- avoid_list is a list of types. tiles with things of that type will be avoided.
function deploy(thing, avoid_list)

  local valid_tiles = {}

  for x = 1, cols do
		for y = 1, rows do
      local tile_is_valid = true
      local tile = board[x][y]
      for tile_item in all(tile) do
        for avoid_item in all(avoid_list) do
          -- check everything in the tile to see if it matches anything in the avoid list
          if tile_item.type == avoid_item then
            tile_is_valid = false
          end
        end
      end
      if tile_is_valid then
        add(valid_tiles, {x,y})
      end
    end
  end

  local index = flr(rnd(#valid_tiles)) + 1
  local dest = valid_tiles[index]

  set_tile(thing, dest)
end

function trigger_enemy_buttons(enemy_tile)

  function gain_health()
    for next in all(heroes) do
      if (next.health < next.max_health) then
        next.health = next.health + 1
      end
    end
    sfx(sounds.health, 3)
  end

  function gain_score()
    score += 1
    sfx(sounds.score, 3)
  end

  local button = find_type_in_tile("button", enemy_tile)
  if button then
    if button.name == "health" then
      gain_health()
    end
    if button.name == "score" then
      gain_score()
    end
  end
end

-- check if a tile is in a list of tiles
function is_in_tile_array(array, tile)
	for next in all(array) do
		if tile[1] == next[1] and tile[2] == next[2] then
			return true
		end
	end
	return false
end

function find_type_in_tile(type, tile)
  local x = tile[1]
  local y = tile[2]
  for i = 1, #board[x][y] do
    local next = board[x][y][i]
    if next.type == type then
      return next
    end
  end
  return false
end

-- returns an array of all existing adjacent tiles that don't have walls in the way
function get_adjacent_tiles(tile)

  local self_x = tile[1]
  local self_y = tile[2]
  local adjacent_tiles = {}

  local up = {self_x, self_y - 1}
  local down = {self_x, self_y + 1}
  local left = {self_x - 1, self_y}
  local right = {self_x + 1, self_y}

  local maybe_adjacent_tiles = {up, down, left, right}

  for next in all(maybe_adjacent_tiles) do
    if
      location_exists(next) and
      is_wall_between(tile, next) == false
    then
      add(adjacent_tiles, next)
    end
  end

  return adjacent_tiles
end

--[[
  hero stuff
--]]

function create_hero()
  local hero = {

    -- board position
    x = null,
    y = null,
    -- screen position
    s = {},
    -- target screen position(s)
    t = {},
    -- for delaying movement transitions
    td = 0,
    -- transition stuff
    frames_so_far = 0,
    vel_per_frame = 0,
    transition_speed = 1, -- in frames
    -- other stuff
		type = "hero",
    base_sprite = sprites.hero,
    sprite = null,
    max_health = 2,
    health = 2,
    -- buttons
    dash = false,
    shoot = false,

      -- this is called when the player hits a direction on their turn.
      -- it determines which action should be taken and triggers it.
    act = function(self, direction)
      local next_tile = {self.x + direction[1], self.y + direction[2]}
      function step_or_bump(direction)
        local target_tile = {self.x + direction[1], self.y + direction[2]}
        local enemy = find_type_in_tile("enemy", target_tile) or find_type_in_tile("egg", target_tile)
        if enemy then
          hit_enemy(enemy, 1)
          set_bump_transition(self, direction, 2, 0)
          set_bump_transition(enemy, direction, 2, 2)
          sfx(sounds.hero_bump, 3)
        else
          set_tile(self, target_tile)
        end
      end

      -- given a direction, this returns the nearest enemy in line of sight
      -- or `false` if there's not one
      function get_shoot_target(direction)

        local now_tile = {self.x, self.y}
        local x_vel = direction[1]
        local y_vel = direction[2]

        while true do
          -- define the current target
          local next_tile = {now_tile[1] + x_vel, now_tile[2] + y_vel}
          -- if `next_tile` is off the map, or there's a wall in the way, return false
          if
            location_exists(next_tile) == false or
            is_wall_between(now_tile, next_tile) or
            find_type_in_tile("hero", next_tile)
          then
            return false
          end
          -- if there's an enemy in the target, return it
          local enemy = find_type_in_tile("enemy", next_tile) or find_type_in_tile("egg", next_tile)
          if enemy then
            return enemy
          end
          -- set `current` to `next_tile` and keep going
          now_tile = next_tile
        end
      end

      function get_dash_dest(direction)

        local now_tile = {self.x, self.y}
        local x_vel = direction[1]
        local y_vel = direction[2]

        while true do
          -- define the current target
          local next_tile = {now_tile[1] + x_vel, now_tile[2] + y_vel}
          -- if `next_tile` is off the map, or there's a wall in the way, return false
          if
            location_exists(next_tile) == false or
            is_wall_between(now_tile, next_tile) or
            find_type_in_tile("hero", next_tile)
          then
            return now_tile
          end
          -- if there's an enemy in the target, return it
          -- local enemy = find_type_in_tile("enemy", next_tile)
          -- if enemy then
          --   return enemy
          -- end
          -- set `current` to `next_tile` and keep going
          now_tile = next_tile
        end
      end

      function get_dash_targets(direction)

        local now_tile = {self.x, self.y}
        local x_vel = direction[1]
        local y_vel = direction[2]
        local targets = {}

        while true do
          -- define the current target
          local next_tile = {now_tile[1] + x_vel, now_tile[2] + y_vel}
          -- if `next_tile` is off the map, or there's a wall in the way, return false
          if
            location_exists(next_tile) == false or
            is_wall_between(now_tile, next_tile) or
            find_type_in_tile("hero", next_tile)
          then
            return targets
          end
          -- if there's an enemy in the target, return it
          local enemy = find_type_in_tile("enemy", next_tile) or find_type_in_tile("egg", next_tile)
          if enemy then
            add(targets, enemy)
          end
          -- set `current` to `next_tile` and keep going
          now_tile = next_tile
        end
      end
      if
        location_exists(next_tile) and
        not is_wall_between({self.x, self.y}, next_tile) and
        not find_type_in_tile("hero", next_tile)
      then
        shoot_target = get_shoot_target(direction)
        if self.shoot and shoot_target then
          shoot_target.stunned = true
          shoot_target.sprite = sprites.egg
          hit_enemy(shoot_target, 1)
          delay += transition_frames
          sfx(sounds.shoot, 3)
          shot_points = {self.s, shoot_target.s}
          shot_direction = direction
          shot_duration = 4
          -- player_turn = false
        elseif self.dash then
          local dest = get_dash_dest(direction)
          local targets = get_dash_targets(direction)
          for next in all(targets) do
            hit_enemy(next, 5)
          end
          set_tile(self, dest)
          delay += transition_frames
          sfx(sounds.dash, 3)
          -- player_turn = false
        else
          step_or_bump(direction)
          delay += transition_frames
          -- player_turn = false
        end
        player_turn = false
        -- del(input_queue, input_queue[1])
      end
    end
	}
  return hero
end

-- updates both heroes' abilities and sprites
-- based on the button that their ally is standing on
function update_hero_abilities()

  for next in all(heroes) do

    -- find the ally
    local ally
    if heroes[1] == next then
      ally = heroes[2]
    else
      ally = heroes[1]
    end

    local next_xy = {next.x, next.y}
    local ally_xy = {ally.x, ally.y}

    -- set hero deets to their defaults
    next.dash = false
    next.shoot = false
    next.base_sprite = sprites.hero

    -- if the ally's tile is a button, update the hero's deets
    local button = find_type_in_tile("button", ally_xy)
    if button then
      if button.name == "dash" or button.name == "shoot" then
        next[button.name] = true
        next.base_sprite = button.hero_sprite
      end
    end
  end
end

function should_advance()
  -- get tiles for both heroes
  local a_xy = {hero_a.x, hero_a.y}
  local b_xy = {hero_b.x, hero_b.y}

  -- find any pads that heroes are occupying
  local a_p = find_type_in_tile("pad", b_xy)
  local b_p = find_type_in_tile("pad", a_xy)

  -- if there are heroes occupying two pads
  if a_p and b_p then
    return true
  end
  return false
end

-- todo: clean up redundancy with should_advance()
function add_button()

  -- get tiles for both heroes
  local a_xy = {hero_a.x, hero_a.y}
  local b_xy = {hero_b.x, hero_b.y}

  -- find which pads that heroes are occupying
  local a_p = find_type_in_tile("pad", b_xy)
  local b_p = find_type_in_tile("pad", a_xy)

  -- find the other one
  local other_p
  for next in all(pads) do
    if next ~= a_p and next ~= b_p then
      other_p = next
    end
  end

  -- put an button button in its position
  local button_name = other_p.name
  local button_x = other_p.x
  local button_y = other_p.y
  local new_button = new_button(button_name)
  set_tile(new_button, {button_x, button_y})

  -- make the advance sound
  sfx(sounds.advance, 3)
end

function update_hero_sprites()
  if hero_a_active then
    hero_a.sprite = hero_a.base_sprite + 1
    hero_b.sprite = hero_b.base_sprite
  else
    hero_a.sprite = hero_a.base_sprite
    hero_b.sprite = hero_b.base_sprite + 1
  end
end

-- function hatch_eggs()
--   for next in all(eggs) do
--     del(eggs, next)
--     del(board[next.x][next.y], next)

--     local found_hero = find_type_in_tile("hero", {next.x, next.y})
--     local found_enemy = find_type_in_tile("enemy", {next.x, next.y})

--     if found_hero then
--       found_hero.health -= 1
--     elseif found_enemy then
--       hit_enemy(found_enemy, 1)
--     else
--       local new_enemy = new_enemy({next.x, next.y})
--     end
--   end
-- end

-- given an enemy and an amount of damage,
-- hit it and then kill if it has no health
function hit_enemy(enemy, damage)

  enemy.health -= damage
  if (enemy.health <= 0) then
    has_killed = true
    del(board[enemy.x][enemy.y], enemy)
    if enemy.type == "enemy" then
      del(enemies, enemy)
    -- elseif enemy.type == "egg" then
    --   del(eggs, enemy)
    end
  end
end

--[[
  enemy stuff
--]]

-- function new_egg()
--   egg = {
--     x = null,
--     y = null,
--     s = {},
--     health = 1,
--     type = "egg",
--     sprite = sprites.egg
--   }
--   add(eggs, egg)
--   return egg
-- end

-- create an enemy and add it to the array of enemies
function new_enemy()
	enemy = {
    -- board position
    x = null,
    y = null,
    -- screen position
    s = {},
    -- target screen position(s)
    t = {},
    -- for delaying movement transitions
    td = 0,
    -- transition stuff
    frames_so_far = 0,
    vel_per_frame = 0,
    transition_speed = 1, -- in frames
    -- other stuff
		type = "hero",
    type = "enemy",
    stunned = true,
    sprite = sprites.egg, -- stunned by default
    health = 2,
    update = function(self)

      if self.stunned == true then
        self.stunned = false
        self.sprite = sprites.enemy
        player_turn = true
        return
      end

      local self_tile = {self.x, self.y}

			local a_tile = {hero_a.x, hero_a.y}
			local a_dist = distance(self_tile, a_tile)

			local b_tile = {hero_b.x, hero_b.y}
			local b_dist = distance(self_tile, b_tile)

      -- target the closer hero
      -- or a random one if they're equidistant
      local current_dist
      local goal_tile
      if a_dist < b_dist then
        current_dist = a_dist
        goal_tile = a_tile
      elseif b_dist < a_dist then
        current_dist = b_dist
        goal_tile = b_tile
      else
        local hero_tiles = {a_tile, b_tile}
        local index = flr(rnd(#hero_tiles)) + 1
        current_dist = b_dist
        goal_tile = hero_tiles[index]
      end

      local adjacent_tiles = get_adjacent_tiles(self_tile)
      local valid_moves = {}

      -- populate valid_moves with tiles that are closer and don't contain enemies
      for next in all(adjacent_tiles) do
        local enemy_exists = find_type_in_tile("enemy", next)
        if
          distance(next, goal_tile) < current_dist and
          not enemy_exists
        then
					add(valid_moves, next)
				end
      end

      -- if there are no valid moves based on the above criteria,
      -- then any adjacent tile that's not an enemy and doesn't have a wall in the way is valid
      if #valid_moves == 0 then
        local available_adjacent_tiles = {}
        for next in all(adjacent_tiles) do
          local enemy_exists = find_type_in_tile("enemy", next)
          if not enemy_exists then
            add(available_adjacent_tiles, next)
          end
        end
        valid_moves = available_adjacent_tiles
      end

      -- if there are any valid moves…
      if #valid_moves > 0 then
        -- pick a tile in valid_moves and attempt to move to it
        -- this will either move to it or hit a hero
        index = flr(rnd(#valid_moves)) + 1
        dest = valid_moves[index]
        local target = find_type_in_tile("hero", dest)
        if target then
          if target.health > 0 then
            -- get direction
            local direction = get_direction(self_tile, dest)
            set_bump_transition(self, direction, 2, 0)
            set_bump_transition(target, direction, 2, 2)
            target.health -= 1
            delay += 4
            sfx(sounds.enemy_bump, 3)
          end
        else
          set_tile(self, dest)
          delay += 4
        end
      end
		end
	}
	add(enemies, enemy)
  return enemy
end

function get_direction(a, b)
  local ax = a[1]
  local ay = a[2]
  local bx = b[1]
  local by = b[2]
  -- up
  if bx == ax and by == ay - 1 then
  -- if dest ==
    return {0, -1}
  -- down
  elseif bx == ax and by == ay + 1 then
    return {0, 1}
  -- left
  elseif bx == ax - 1 and by == ay then
    return {-1, 0}
  -- right
  elseif bx == ax + 1 and by == ay then
    return {1, 0}
  -- fail
  else
    return false
  end
end

function pair_equal(a, b)
  if a[1] == b[1] and a[2] == b[2] then
    return true
  end
  return false
end

function distance(start, goal)
  local frontier = {goal}
	local next_frontier = {}
	local distance_map = {}
	for x = 1, cols do
		distance_map[x] = {}
		for y = 1, rows do
			-- this is a hack but it's easier than using a different type
			distance_map[x][y] = 1000
		end
	end
	local steps = 0

  -- todo: stop building the map once `start` is reached
	while #frontier > 0 do
		for i = 1, #frontier do
      local here = frontier[i]
      local adjacent_tiles = get_adjacent_tiles(here)
			local here_x = here[1]
			local here_y = here[2]
			distance_map[here_x][here_y] = steps

      for next in all(adjacent_tiles) do
        -- if the distance hasn't been set, then the tile hasn't been reached yet
        if distance_map[next[1]][next[2]] == 1000 then
					if (
            -- make sure it wasn't already added by a different check in the same step
            is_in_tile_array(next_frontier, next) == false
          ) then
						add(next_frontier, next)
					end
				end
      end
		end
		steps += 1
		frontier = next_frontier
		next_frontier = {}
	end
	return distance_map[start[1]][start[2]]
end

--[[
  board stuff
--]]

-- check if there's a wall between two tiles
function is_wall_between(tile_a, tile_b)

  local a_x = tile_a[1]
  local a_y = tile_a[2]
  local b_x = tile_b[1]
  local b_y = tile_b[2]

  -- if b is above a
  if b_x == a_x and b_y == a_y - 1 then
    -- this is a bit weird but it works
    return find_type_in_tile("wall_down", tile_b) and true or false
  -- if b is below a
  elseif b_x == a_x and b_y == a_y + 1 then
    return find_type_in_tile("wall_down", tile_a) and true or false
  -- if b is left of a
  elseif b_x == a_x - 1 and b_y == a_y then
    return find_type_in_tile("wall_right", tile_b) and true or false
  -- if b is right of a
  elseif b_x == a_x + 1 and b_y == a_y then
    return find_type_in_tile("wall_right", tile_a) and true or false
  else
    -- todo: can i throw an error here?
  end
end

function clear_all_walls()

  for x = 1, cols do
		for y = 1, rows do
      local here = board[x][y]

      local wall_right = find_type_in_tile("wall_right", {x,y})
      local wall_down = find_type_in_tile("wall_down", {x,y})

      if wall_right then
        del(here, wall_right)
      end
      if wall_down then
        del(here, wall_down)
      end
    end
  end
end

function refresh_walls()
  clear_all_walls()
  generate_walls()
  while not is_map_contiguous() do
    clear_all_walls()
    generate_walls()
  end
end

function generate_walls()

  for i = 1, 10 do
    local wall_right = {
      x = null,
      y = null,
      type = "wall_right",
      sprite = sprites.wall_right
    }
    local wall_down = {
      x = null,
      y = null,
      type = "wall_down",
      sprite = sprites.wall_down
    }
    deploy(wall_right, {"wall_right"})
    deploy(wall_down, {"wall_down"})
  end
end

-- checks if the map is contiguous by starting in one tile and seeing if all other tiles can be reached from there
function is_map_contiguous()

  -- we can start in any tile
  local frontier = {{1,1}}
	local next_frontier = {}

  -- this will be a map where the value of x,y is a bool that says whether we've reached that position yet
	local reached_map = {}
	for x = 1, cols do
		reached_map[x] = {}
		for y = 1, rows do
			reached_map[x][y] = false
		end
	end

	while #frontier > 0 do
		for here in all(frontier) do
      local adjacent_tiles = get_adjacent_tiles(here)
			local here_x = here[1]
			local here_y = here[2]
			reached_map[here_x][here_y] = true

      for next in all(adjacent_tiles) do
        if reached_map[next[1]][next[2]] == false then
          -- make sure it wasn't already added by a different check in the same step
					if is_in_tile_array(next_frontier, next) == false then
						add(next_frontier, next)
					end
				end
      end
		end
		frontier = next_frontier
		next_frontier = {}
	end

  -- if any position in reached_map is false, then the map isn't contiguous
  for x = 1, cols do
		for y = 1, rows do
      if reached_map[x][y] == false then
        return false
      end
    end
  end

  return true
end

function refresh_pads()

  -- delete all existing pads
  for next in all(pads) do
    del(board[next.x][next.y], next)
    del(pads, next)
  end

  -- if there are only 5 spaces left, deploy exits
  -- right now i'm thinking it has to be 5 because otherwise pads get spawned below heroes
  -- but i should probably do something to make this more elegant.
  if #buttons == rows * cols - 4 then
    for i = 1, 2 do
      local exit = {
        x = null,
        y = null,
        type = "exit",
        sprite = sprites.exit
      }
      add(exits, exit)
      deploy(exit, {"button", "hero", "exit"})
    end
    return
  end

  local current_types = {
    "dash",
    "shoot",
    "health",
    "score"
  }
  local index = flr(rnd(#current_types)) + 1
  local to_remove = current_types[index]
  del(current_types, to_remove)

  -- place new pads
  for next in all(current_types) do
    local new_pad = {
      s = {},
      type = "pad",
      name = next,
      sprite = sprites["pad_" ..next]
    }
    add(pads, new_pad)
    deploy(new_pad, {"pad", "button", "hero"})
  end
end

function new_button(name)

  local new_button = {
    x = null,
    y = null,
    s = {},
    type = "button",
    name = name,
    sprite = sprites["button_" ..name],
    hero_sprite = sprites["hero_" ..name]
  }
  add(buttons, new_button)
  return new_button
end

__gfx__
0000000000000000ffffffff00000000ffffffff0000000d00000000ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000
0000000000000000000000ff00000000666666ff0000000d00000000ffcffcffffbffbffff8ff8ffff9ff9ffff7ff7ffff7777ff000000000000000000000000
0000000000000000077770ff00000000677776ff0000000d00000000fccffccffbbffbbff88ff88ff99ff99ff77ff77ff777777f000000000000000000000000
0000000000000000007070ff00000000667676ff0000000d00000000fffffffffffffffffffffffffffffffffffffffff777777f000000000000000000000000
0000000000000000077770ff00000000677776ff0000000d00000000fffffffffffffffffffffffffffffffffffffffff577775f000000000000000000000000
0000000000000000007700ff00000000667766ff0000000d00000000fccffccffbbffbbff88ff88ff99ff99ff77ff77ff555555f000000000000000000000000
0000000000000000f0000fff00000000f6666fff0000000d00000000ffcffcffffbffbffff8ff8ffff9ff9ffff7ff7ffff5555ff000000000000000000000000
0000000000000000ffffffff00000000ffffffff0000000dddddddddffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000
00000000ffffffffff000fffffffffffff000fffffffffffff000fffffffffffffffffffffffffffffffffff77777777eeeeeeee000000000000000000000000
00000000ffffffffff070fffffffffffff0c0fffffffffffff0b0fffffccccffffbbbbffff8888ffff9999ff77677677effffffe000000000000000000000000
00000000ff000fff0007000fff000fff000c000fff000fff000b000ffccccccffbbbbbbff888888ff999999f77655677efeeeefe000000000000000000000000
000000000007000f0777770f000c000f0ccccc0f000b000f0bbbbb0ffccccccffbbbbbbff888888ff999999f75666657efeffefe000000000000000000000000
000000000777770f0007000f0ccccc0f000c000f0bbbbb0f000b000ff1cccc1ff3bbbb3ff288882ff499994f70600607efeffefe000000000000000000000000
000000000007000ff07070ff000c000ff0c0c0ff000b000ff0b0b0fff111111ff333333ff222222ff444444f70666607efeeeefe000000000000000000000000
00000000f07070fff07070fff0c0c0fff0c0c0fff0b0b0fff0b0b0ffff1111ffff3333ffff2222ffff4444ff77600677effffffe000000000000000000000000
00000000f00000fff00000fff00000fff00000fff00000fff00000ffffffffffffffffffffffffffffffffff77777777eeeeeeee000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009990000000000000000000000000
00000777077707770770000007770077070007070077000000000000000000000000000000000000000000000000000000009090000099900990900099000000
00000700070700700707000007700707070007700700000000000000000000000000000000000000000000000000000000009090000090009090900090900000
00000707077000700707000007000707070007070007000000000000000000000000000000000000000000000000000000009090000090909090900090900000
00000777070707770770000007000770077707070770000000000000000000000000000000000000000000000000000000009990000099909900999099000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777700000
00000700000000000000000000000000000000000000700000000000000000000000000000000000000700000000000000000000000000000000000000700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000700000000000000777777777777777777777770007777777777777777777777777777777777770007777777777777777777777777777777777770700000
00000777777777777770777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000700000000000000777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777700077770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777bbbb7777777770707777070777c77c777777777cccc77777777777777770707777777777777777888877777777777777770700000
0000070777777777777777bbbbbb77777700070007707077cc77cc7777777cccccc7777777777777770707777777777777778888887777777777777770700000
0000070777777777777777bbbbbb777777077777077070777777777777777cccccc7777777777777770707777777777777778888887777777777777770700000
00000707777777777777773bbbb37777770007000870707777777777777771cccc17777777777777770707777777777777772888827777777777777770700000
000007077777777777777733333377777770707078707077cc77cc77777771111117777777777777770707777777777777772222227777777777777770700000
0000070777777777777777733337777777707070787070777c77c777777777111177777777777777770707777777777777777222277777777777777770700000
00000707777777777777777777777777777000007870707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777777777777777777777777777770707777777777777777777777777777777777770707777777777777777777777777777777777770700000
00000707777777777000777777777777777777777770000000000000000777777777777777777777770707777777777000777777777700077777777770700000
00000707777777777070777777777777777777777770777777777777070777777777777777777777770707777777777070777777777707077777777770700000
00000707777777777070777777777777777777777770000000000000070777777777777777777777770007777777777070777777777707077777777770700000
00000707777777777070777777777777777777777777777777777777070777777777777777777777777777777777777070777777777707077777777770700000
00000707777777777070777777777777777777777777777777777777070777777777777777777777777777777777777070777777777707077777777770700000
000007077777777770707777777777777777777777777777799997770707777777777777777888877777777777777770707779999777070777bbbb7770700000
00000707777777777070777777777777777777777777777799999977070777777777777777888888777777777777777070779999997707077bbbbbb770700000
00000707777777777070777777777777777777777777777799999977070777777777777777888888777777777777777070779999997707077bbbbbb770700000
000007077777777770707777777777777777777777777777499994770707777777777777772888827777777777777770707749999477070773bbbb3770700000
00000707777777777070777777777777777777777777777744444477070777777777777777222222777777777777777070774444447707077333333770700000
00000707777777777070777777777777777777777777777774444777070777777777777777722227777777777777777070777444477707077733337770700000
00000707777777777070777777777777777777777777777777777777070777777777777777777777777777777777777070777777777707077777777770700000
00000707777777777070777777777777777777777777777777777777070777777777777777777777777777777777777070777777777707077777777770700000
00000707777777777070777777777700000000000000007777777777070777777777777777777777777777777777777000777777777700000000000000700000
00000707777777777070777777777707777777777777707777777777070777777777777777777777777777777777777070777777777707777777777777700000
00000707777777777000777777777700000000000000007777777777000777777777777777777777777777777777777070777777777700000000000000700000
00000707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777070777777777777777777777770700000
00000707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777070777777777777777777777770700000
00000707779999777777777777777777777777777777777779999777777777bbbb77777777777777777777777777777070777777777777777777777770700000
0000070779999997777777700077777777777777777777779999997777777bbbbbb7777777777777777777777777777070777777777777777777777770700000
0000070779999997777770007000777777777777777777779999997777777bbbbbb7777777777777777777777777777070777777777777777777777770700000
00000707749999477777707777708777777777777777777749999477777773bbbb37777777777777777777777777777070777777777777777777777770700000
00000707744444477777700070008777777777777777777744444477777773333337777777777777777777777777777070777777777777777777777770700000
00000707774444777777770707078777777777777777777774444777777777333377777777777777777777777777777070777777777777777777777770700000
00000707777777777777770000078777777777777777777777777777777777777777777777777777777777777777777070777777777777777777777770700000
00000707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777070777777777777777777777770700000
00000707777777777777777777777777777777777770000000000000000000000000000077777777777777777777777070777777777700000000000000700000
00000707777777777777777777777777777777777770777777777777077777777777777077777777777777777777777070777777777707777777777777700000
00000707777777777777777777777777777777777770000000000000000000000000000077777777777777777777777000777777777700000000000000700000
00000707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770700000
00000707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770700000
0000070777777777777777777777777777779779777777777777777777777777777777777000000777777777b77b777777777777777777777777777770700000
000007077777777777777777777777777779977997777777777777777777777777777777707777077777777bb77bb77777777777777777777777777770700000
00000707777777777777777777777777777777777777777777777777777777777777777770070707777777777777777777777777777777777777777770700000
00000707777777777777777777777777777777777777777777777777777777777777777770777707777777777777777777777777777777777777777770700000
000007077777777777777777777777777779977997777777777777777777777777777777700770078777777bb77bb77777777777777777777777777770700000
0000070777777777777777777777777777779779777777777777777777777777777777777700007787777777b77b777777777777777777777777777770700000
00000707777777777777777777777777777777777777777777777777777777777777777777777777877777777777777777777777777777777777777770700000
00000707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770700000
00000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000700000
00000777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777700000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000007000007007000000000000070000070070000000000000777700000000000000000000000000000000000000000000000000000000000000000000000
00000007000077007700000000000070000770077000000000007777770000000000000000000000000000000000000000000000000000000000000000000000
00000777770000000000000600007777700000000000066600007777770000000000000000000000000000000000000000000000000000000000000000000000
00000007000000000000006660000070000000000000000000005777750000000000000000000000000000000000000000000000000000000000000000000000
00000070700077007700000600000707000770077000066600005555550000000000000000000000000000000000000000000000000000000000000000000000
00000070700007007000000000000707000070070000000000000555500000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000700000bbbb000000000000000000000000000000000000000000000000000000000000000000008888000000000000000000000000000000000000000
000000070000bbbbbb00000000000000000000000000000000000000000000000000000000000777700088888800000000000000000000000000000000000000
000007777700bbbbbb00006660000077070700770077077700000000000000000000000000000070700088888800006660000707077707770700000000000000
0000000700003bbbb300000000000700070707070707007000000000000000000000000000000777700028888200000000000707077007070700000000000000
00000070700033333300006660000007077707070707007000000000000000000000000000000077000022222200006660000777070007770700000000000000
00000070700003333000000000000770070707700770007000000000000000000000000000000000000002222000000000000707077707070777000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000700000cccc000000000000000000000000000000000000000000000000000000000000000000009999000000000000000000000000000000000000000
7000000088880ccccc00000000000000000000000000000000000000000000000000000000000777700099999900000000000000000000000000000000000000
0700000088880ccccc00006660000770077700770707000000000000000000000000000000000070700099999900006660000777007707000770000000000000
0070000088880cccc100000000000707070707000707000000000000000000000000000000000777700049999400000000000700070707000707000000000000
07000000888801111100006660000707077700070777000000000000000000000000000000000077000044444400006660000707070707000707000000000000
70000000888801111000000000000770070707700707000000000000000000000000000000000000000004444000000000000777077007770770000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__map__
0000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01020000217521b7521775214752117520f7520d7520b75209752087520675205752047520475204752037520c7020b7020b7020a7020a7020970209702097020970200702007020070200702007020070200702
012000200e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e75511755117551175511755117551175511755117551075510755107551075510755107550c7550c755
012000201d755000000000000000217550000000000000001d7550000000000000001d7550000000000000001d7550000000000000001a7550000000000000001d7550000000000000001d755000000000000000
0140002010037000071003700007100370000710037000071303718007130370000713037180071303700007150370c0071503700007150370c00715037000071d037000071c037000071a037000071803700007
014100001f0301f035000050000500005000052303023035210302103500005000050000500005260302603528030280350000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0180001007725007000c7250070007725007000a7250070007725007000f7250070007725007000e7250070000700007000070000700007000070000700007000070000700007000070000700007000070000700
01200000217250070518725007051f725007051b725007051d725007051b725007051f725007051a725007051d725007051a725007051f7250070518725007051a725007051b725007051f725007051a72500705
0120000021525225252652522525215252252526525225251f5252152522525215251f5252152522525215251a5251d525215251d5251a5251d525215251d525185251a5251b5251a525185251a5251b5251a525
0120000021525225252652522505215252250526525225051f5252152522525215051f5252150522525215051a5251d525215251d5051a5251d505215251d505185251a5251b5251a505185251a5051b5251a505
0120000021525225052652522505215252250526525225051f5252150522525215051f5252150522525215051a5251d505215251d5051a5251d505215251d505185251a5051b5251a505185251a5051b5251a505
01200000025330050000500005002f615005000050000500025330050000500005002f615005000050000500025330050000500005002f615005000050000500025330050000500005002f615005000050000500
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000f73502735247050c73502735127052f70505705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
000400001c72503725247051872503725127052f70505705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
00080000277152b51537715335053b505395050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505
000c00001a7530f7330c7230f7030d7030b7030970307703067030570304703037030370302703017030170301703017030170301703017030170301703017030170301703017030170301703017030170301703
000400000f715027150c715027150f715027150c71502715007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
000400001c7150371518715037151c715037151871503715007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
000c00000c7540f7341a7240f7040d7040b7040970407704067040570404704037040370402704017040170401704017040170401704017040170401704017040170401704017040170401704017040170401704
00080000037140f7211b7312774133722337350000000001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000000000000000
010700000e6130c523126131f60300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300000
00120000261431b123181130f1030d1030b1030910307103061030510304103031030310302103011030110301103011030110301103011030110301103011030110301103011030110301103011030110301103
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
04 02034040
02 04050000
01 0748494c
01 0708400c
00 07080b0c
00 07080a0c
00 0748094c
00 0708094c
00 0708090c
02 07080b0c
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000

