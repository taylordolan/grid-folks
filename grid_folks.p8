pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

-- todo
-- [x] refactor sprite coloring
-- [x] affordance for stepping on pads
-- [x] affordance for shooting
-- [x] affordance for walking through walls
-- [x] transitions for taking damage (hero and enemy)
-- [x] animation for enemy death
-- [ ] balance enemy spawn rate
-- [ ] when multiple enemies are present, they should act in random order
-- [ ] nice looking end game states
-- [ ] title screen?
-- [ ] better instructions presentation?

-- game state that gets refreshed on restart
function _init()

  -- board size
  rows = 5
  cols = 7

  -- 2d array for the board
  board = {}
  for x = 1, cols do
    board[x] = {}
    for y = 1, rows do
      board[x][y] = {}
    end
  end

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

  -- graphics stuff that needs to be global
  text_color = colors.white
  bg_color = colors.black
  floor_color = colors.white
  screen_size = 128
  sprite_size = 8
  tile_margin = 7
  tile_size = sprite_size + tile_margin
  total_sprites_width = sprite_size * cols
  total_margins_width = tile_margin * (cols - 1)
  total_map_width = total_sprites_width + total_margins_width
  padding_left = flr((screen_size - total_map_width) / 2)
  padding_top = padding_left -- so the board is drawn as far from the top as it is from each side
  transition_frames = 4 -- how long it takes for movement transitions to happen
  shot_points = {} -- expects two {x,y} points for the beginning and end of a shot
  shot_direction = {} -- which direction the shot was fired in, e.g. {0, -1} for up
  remaining_shot_frames = 0 -- for how many frames should the current shot be drawn?
  border_color = 0
  set_border_color()

  -- sounds dictionary
  sounds = {
    music = 002,
    health = 026,
    score = 022,
    shoot = 029,
    ghost = 025,
    step = 021,
    advance = 027,
    pad_step = 028,
    switch_heroes = 000,
    enemy_bump = 000,
    hero_bump = 000,
  }

  -- sprites dictionary
  sprites = {
    hero_inactive = 001,
    hero_active = 002,
    enemy = 003,
    crosshair = 004,
    pad = 017,
    button = 018,
    exit = 019,
    border_left = 033,
    border_top = 034,
    border_top_left = 035,
    border_top_right = 036,
    die_1 = 005,
    die_2 = 006,
  }

  -- some game state
  score = 0
  turns = 0
  player_turn = true
	game_lost = false
  game_won = false
  debug_mode = false
  delay = 0

  -- lists of things
  heroes = {}
  enemies = {}
  pads = {}
  buttons = {}
  exits = {}
  -- when multiple things are in a tile, they'll be rendering in this order
  -- that means the things at the end will appear on top
  layers = {
    "wall_right",
    "wall_down",
    "pad",
    "button",
    "exit",
    "enemy",
    "hero",
  }

  -- log of recent user input
  input_queue = {}

  -- initial buttons (for testing)
  set_tile(new_button("blue"), {4,2})
  set_tile(new_button("green"), {4,4})
  set_tile(new_button("red"), {5,3})
  set_tile(new_button("orange"), {3,3})

  -- heroes
  hero_a = create_hero()
  hero_b = create_hero()
  hero_a.active = true
  heroes = {hero_a, hero_b}
  set_tile(hero_a, {3,3})
  set_tile(hero_b, {5,3})

  -- initial walls
  refresh_walls()

  -- initial pads
  refresh_pads()

	-- initial enemy
  spawn_enemy()

  -- spawn rate stuff
  spawn_rates = {
    [1] = 15,
    [30] = 13,
    [60] = 10,
    [100] = 8,
    [140] = 6,
    [180] = 5,
    [210] = 4,
    [240] = 3,
    [300] = 2,
    [360] = 1,
  }
  spawn_rate = spawn_rates[1]
  -- this gets updated whenever an enemy spawns
  last_spawned_turn = 0
  -- this tracks whether we've spawned a turn early
  spawned_early = false

  -- start the music!
  music(sounds.music)
end

function set_border_color()
  local options = {
    colors.tan,
    colors.light_gray,
  }
  del(options, border_color)
  local index = flr(rnd(#options)) + 1
  border_color = options[index]
  wall_color = border_color
end

function should_spawn()
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

function spawn_enemy()
  local new_enemy = new_enemy()
  new_enemy.deploy(new_enemy)
  last_spawned_turn = turns
end

function _update60()

  if btnp(4) then
    debug_mode = not debug_mode
  end

  if game_won or game_lost then
    if btnp(5) then
      _init()
    end
    return
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
    -- x
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
      for next in all(heroes) do
        next.active = not next.active
      end
      update_targets()
      sfx(sounds.switch_heroes, 3)
    else
      active_hero().act(active_hero(), input_queue[1])
    end
    del(input_queue, input_queue[1])
  -- enemy turn
  elseif player_turn == false then
    update_hero_abilities()
    if should_advance() then
      add_button()
      refresh_pads()
      refresh_walls()
      set_border_color()
    end
    for next in all(enemies) do
      next.update(next)
    end
    if should_spawn() then
      spawn_enemy()
    end
    update_targets()
    -- update game state
    turns = turns + 1
    player_turn = true
    if spawn_rates[turns] ~= nil then
      spawn_rate = spawn_rates[turns]
    end
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

function active_hero()
  if hero_a.active then
    return hero_a
  else
    return hero_b
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

function draw_health(x_pos, y_pos, amount)
  for i = 1, amount do
    pset(x_pos + 7, y_pos + 8 - i, 8)
  end
end

function _draw()

	cls()
  local total_sprites_height = sprite_size * rows
  local total_margins_height = tile_margin * (rows - 1)
  local total_map_height = total_sprites_height + total_margins_height

  local board_origin = {padding_left - ceil(tile_margin / 2), padding_top - ceil(tile_margin / 2)}
  local board_opposite = {padding_left + total_map_width - 1 + ceil(tile_margin / 2), padding_top + total_map_height - 1 + ceil(tile_margin / 2)}

  function draw_background()
    -- this isn't really necessary if bg_color is black, but i'll keep it so i can modify the bg_color
    rectfill(0, 0, 127, 127, bg_color)
  end

  function draw_floor()
    -- `adjust` isn't technically necessary because if the value was 0, draw_outlines() would still cover the difference
    local adjust = 2
    rectfill(board_origin[1] + adjust, board_origin[2] + adjust, board_opposite[1] - adjust, board_opposite[2] - adjust, floor_color)
  end

  function draw_outlines()
    -- this draws 1px inside and 1px outside the "rim" that gets drawn by the border tiles.
    -- this creates the appearance of walls around the floor of the board.
    rect(board_origin[1] - 1, board_origin[2] - 1, board_opposite[1] + 1, board_opposite[2] + 1, bg_color)
    rect(board_origin[1] + 1, board_origin[2] + 1, board_opposite[1] - 1, board_opposite[2] - 1, bg_color)
  end

  function draw_border()
    pal(colors.white, wall_color)
    pal(colors.light_gray, border_color)
    -- top and bottom
    local start = 12
    local count = 13
    for x = start, start + sprite_size * count - 1, sprite_size do
      spr(sprites.border_top, x, 4, 1, 1, false, false)
      spr(sprites.border_top, x, 86, 1, 1, true, true)
    end
    -- left and right
    local start = 13
    local count = 9
    for y = start, start + sprite_size * count - 1, sprite_size do
      spr(sprites.border_left, 4, y)
      spr(sprites.border_left, 116, y, 1, 1, true, true)
    end
    -- top left
    spr(sprites.border_top_left, 4, 5)
    -- top right
    spr(sprites.border_top_right, 116, 5, 1, 1, true, false)
    -- bottom left
    spr(sprites.border_top_right, 4, 85, 1, 1, false, true)
    -- bottom right
    spr(sprites.border_top_left, 116, 85, 1, 1, true, true)
    pal()
  end

  function draw_sprites()

    for x = 1, cols do
      for y = 1, rows do
        -- draw everything at the current position
        for type in all(layers) do
          -- render sprites in the order defined by layers
          -- todo: this isn't actually working
          for next in all(board[x][y]) do
            if next.type == type then
              next.draw(next)
            end
          end
        end
      end
    end
  end

  function update_shot_drawing()

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
        by -= 1
      -- down
      elseif pair_equal(dir, {0, 1}) then
        ax += 3
        bx += 3
        ay += 9
        by += 7
      -- left
      elseif pair_equal(dir, {-1, 0}) then
        ax -= 2
        bx -= 1
        ay += 3
        by += 3
      -- right
      elseif pair_equal(dir, {1, 0}) then
        ax += 8
        bx += 8
        ay += 3
        by += 3
      end
      rectfill(ax, ay, bx, by, colors.green)
    end

    if #shot_points > 0 then
      draw_shot(shot_points[1], shot_points[2], shot_direction)
      remaining_shot_frames -= 1
      if remaining_shot_frames <= 0 then
        shot_points = {}
        shot_direction = {}
      end
    end
  end

  function draw_instructions()
    local x_pos = padding_left - 5
    local y_pos = 100
    local line_height = 9

    -- advance
    palt(colors.black, false)
    palt(colors.tan, true)
    pal(colors.light_gray, colors.white)
    pal(colors.dark_gray, colors.light_gray)
    spr(sprites.hero_inactive, x_pos, y_pos - 2)
    spr(sprites.pad, x_pos + 7, y_pos - 2)
    spr(sprites.hero_active, x_pos + 24, y_pos - 2)
    spr(sprites.pad, x_pos + 31, y_pos - 2)
    spr(sprites.button, x_pos + 48, y_pos - 2)
    pal()
    print("+", x_pos + 18, y_pos, 06)
    print("=", x_pos + 42, y_pos, 06)

    y_pos += line_height

    -- ghost
    palt(colors.black, false)
    palt(colors.tan, true)
    pal(colors.light_gray, colors.blue)
    pal(colors.dark_gray, colors.navy)
    spr(sprites.button, x_pos + 7, y_pos - 2)
    spr(sprites.hero_inactive, x_pos, y_pos - 2)
    spr(sprites.hero_active, x_pos + 24, y_pos - 2)
    print(smallcaps("ghost"), x_pos + 32, y_pos, text_color)
    pal()
    print("=", x_pos + 18, y_pos, 06)

    y_pos += line_height

    -- shoot
    palt(colors.black, false)
    palt(colors.tan, true)
    pal(colors.light_gray, colors.green)
    pal(colors.dark_gray, colors.forest)
    spr(sprites.hero_inactive, x_pos, y_pos - 2)
    spr(sprites.button, x_pos + 7, y_pos - 2)
    spr(sprites.hero_active, x_pos + 24, y_pos - 2)
    print(smallcaps("shoot"), x_pos + 32, y_pos, text_color)
    pal()
    print("=", x_pos + 18, y_pos, 06)

    x_pos += 67
    y_pos -= line_height

    -- gold
    palt(colors.black, false)
    palt(colors.tan, true)
    pal(colors.light_gray, colors.orange)
    pal(colors.dark_gray, colors.brown)
    spr(sprites.enemy, x_pos, y_pos - 2)
    spr(sprites.button, x_pos + 7, y_pos - 2)
    print(smallcaps("gold"), x_pos + 25, y_pos, text_color)
    pal()
    print("=", x_pos + 18, y_pos, 06)

    y_pos += line_height

    -- health
    palt(colors.black, false)
    palt(colors.tan, true)
    pal(colors.light_gray, colors.red)
    pal(colors.dark_gray, colors.maroon)
    spr(sprites.enemy, x_pos, y_pos - 2)
    spr(sprites.button, x_pos + 7, y_pos - 2)
    print(smallcaps("heal"), x_pos + 25, y_pos, text_color)
    pal()
    print("=", x_pos + 18, y_pos, 06)

  end

  function draw_score()
    if not debug_mode then
      local text = smallcaps("gold")
      local num = score .. ""
      print(text, 118 - #text * 4, 100, colors.orange)
      print(num, 99 - #num * 4, 100, colors.orange)
    else
      local text = turns .."/"..spawn_rate.."/"..score
      print(text, 118 - #text * 4, 100, colors.white)
    end
  end

  function draw_game_end_state()
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

  draw_background()
  draw_floor()
  draw_outlines()
  draw_instructions()
  draw_score()
  draw_sprites()
  draw_border()
  update_shot_drawing()
  draw_game_end_state()

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

function transition_to(thing, destinations, frames, delay)

  local s = {}
  local current = thing.screen_seq[1]

  for i = 1, delay do
    add(s, thing.screen_seq[1])
  end

  for next in all(destinations) do

    local x_px_per_frame = (next[1] - current[1]) / frames
    local y_px_per_frame = (next[2] - current[2]) / frames
    local vel_per_frame = {x_px_per_frame, y_px_per_frame}

    for j = 1, frames do
      local next_x = current[1] + vel_per_frame[1]
      local next_y = current[2] + vel_per_frame[2]
      local next = {next_x, next_y}
      add(s, next)
      current = next
    end
  end

  thing.screen_seq = s
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

  if thing.screen_seq and #thing.screen_seq == 0 then
    add(thing.screen_seq, tile_to_screen(dest))
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

-- converts a board position to a screen position
function tile_to_screen(board_position)
  local board_x = board_position[1]
  local board_y = board_position[2]
  local x_pos = (board_x - 1) * sprite_size + (board_x - 1) * tile_margin + padding_left
  local y_pos = (board_y - 1) * sprite_size + (board_y - 1) * tile_margin + padding_top
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
      next.health = next.health + 1
      if next.health > next.max_health then
        next.health = next.max_health
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
  if location_exists(tile) then
    local x = tile[1]
    local y = tile[2]
    for i = 1, #board[x][y] do
      local next = board[x][y][i]
      if next.type == type then
        return next
      end
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
    -- a sequence of screen positions
    screen_seq = {},
    -- a sequence of sprites
    sprite_seq = {sprites.hero_inactive},
    -- a sequence of palette modifications
    pal_seq = {{10,10}},
    -- other stuff
		type = "hero",
    max_health = 3,
    health = 3,
    active = false,
    -- buttons
    ghost = false,
    shoot = false,

    -- base_sprite = function(self)
    --   return self.active and sprites.hero_active or sprites.hero_inactive
    -- end,
      -- this is called when the player hits a direction on their turn.
      -- it determines which action should be taken and triggers it.
    act = function(self, direction)

      local ally
      if heroes[1] == self then
        ally = heroes[2]
      else
        ally = heroes[1]
      end

      -- todo: maybe i can use this to remove update_hero_abilities()
      local ally_button = find_type_in_tile("button", {ally.x, ally.y})
      local next_tile = {self.x + direction[1], self.y + direction[2]}

      function get_shoot_dest(direction)

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
          now_tile = next_tile
        end
      end

      -- this is where the actual acting starts

      -- if the destination exists and the tile isn't occupied by your ally
      if location_exists(next_tile) and not find_type_in_tile("hero", next_tile) then

        local enemy = find_type_in_tile("enemy", next_tile)
        local wall = is_wall_between({self.x, self.y}, next_tile)

        -- if ghost is enabled and there's a wall in the way
        if self.ghost then
          if enemy then
            hit_enemy(enemy, 2)
            delay += transition_frames
            player_turn = false
          end
          set_tile(self, next_tile)
          transition_to(self, {tile_to_screen(next_tile)}, 4, 0)
          delay += 4
          player_turn = false

        -- if there's no wall
        elseif not wall then

          -- if shoot is enabled and shoot targets exist
          local shoot_targets = get_shoot_targets(self, direction)
          if self.shoot and #shoot_targets > 0 then
            for next in all(shoot_targets) do
              hit_enemy(next, 2)
            end
            local shot_dest = get_shoot_dest(direction)
            local screen_shot_dest = tile_to_screen(shot_dest)

            shot_points = {self.screen_seq[1], screen_shot_dest}
            shot_direction = direction
            remaining_shot_frames = transition_frames
            sfx(sounds.shoot, 3)

            delay += transition_frames
            player_turn = false

          -- otherwise, if there's an enemy in the destination, hit it
          elseif enemy then
            hit_enemy(enemy, 1)
            sfx(sounds.hero_bump, 3)
            local here = tile_to_screen({self.x, self.y})
            local bump = {here[1] + direction[1] * 2, here[2] + direction[2] * 2}
            transition_to(self, {bump, here}, 2, 0)
            delay += 4
            player_turn = false

          -- otherwise, move to the destination
          else
            set_tile(self, next_tile)
            transition_to(self, {tile_to_screen(next_tile)}, 4, 0)
            delay += transition_frames
            player_turn = false
          end
        end
      end
    end,
    draw = function(self)

      -- set sprite based on the first value in sprite_seq
      local sprite = self.sprite_seq[1]
      -- if the sprite is hero_inactive and this hero is active, update the sprite
      if sprite == sprites.hero_inactive and self.active then
        sprite = sprites.hero_active
      end

      -- set the current screen destination using the first value in screen_seq
      local sx = self.screen_seq[1][1]
      local sy = self.screen_seq[1][2]

      -- default palette updates
      palt(colors.tan, true)
      palt(colors.black, false)
      if self.shoot then
        pal(colors.white, colors.green)
      elseif self.ghost then
        pal(colors.white, colors.blue)
      end

      -- update the palette based using first value in pal_seq
      pal(self.pal_seq[1][1], self.pal_seq[1][2])

      -- draw the sprite and the hero's health
      spr(sprite, sx, sy)
      draw_health(sx, sy, self.health)

      -- for all these lists, if there's more than one value, remove the first one
      if #self.screen_seq > 1 then
        del(self.screen_seq, self.screen_seq[1])
      end
      if #self.sprite_seq > 1 then
        del(self.sprite_seq, self.sprite_seq[1])
      end
      if #self.pal_seq > 1 then
        del(self.pal_seq, self.pal_seq[1])
      end

      -- reset the palette
      pal()
    end,
	}
  return hero
end

function get_shoot_targets(hero, direction)

  local now_tile = {hero.x, hero.y}
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
    local enemy = find_type_in_tile("enemy", next_tile)
    if enemy then
      add(targets, enemy)
    end
    -- set `current` to `next_tile` and keep going
    now_tile = next_tile
  end
end

function update_targets()
  for next in all(enemies) do
    next.is_shoot_target = false
    next.is_ghost_target = false
  end
  for h in all(heroes) do
    if h.shoot and h.active then
      for d in all({{0, -1}, {0, 1}, {-1, 0}, {1, 0}}) do
        local targets = get_shoot_targets(h, d)
        for t in all(targets) do
          t.is_shoot_target = true
        end
      end
    end
    if h.ghost and h.active then
      local h_tile = {h.x, h.y}
      for d in all({{0, -1}, {0, 1}, {-1, 0}, {1, 0}}) do
        local enemy = find_type_in_tile("enemy", {h_tile[1] + d[1], h_tile[2] + d[2]})
        if enemy then
          enemy.is_ghost_target = true
        end
      end
    end
  end
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
    next.ghost = false
    next.shoot = false

    -- if the ally's tile is a button, update the hero's deets
    local button = find_type_in_tile("button", ally_xy)
    if button then
      if button.color == "blue" then
        next.ghost = true
      elseif button.color == "green" then
        next.shoot = true
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
  local button_color = other_p.color
  local button_x = other_p.x
  local button_y = other_p.y
  local new_button = new_button(button_color)
  set_tile(new_button, {button_x, button_y})

  -- make the advance sound
  sfx(sounds.advance, 3)
end

-- given an enemy and an amount of damage,
-- hit it and then kill if it has no health
function hit_enemy(enemy, damage)
  enemy.health -= damage
  if enemy.health <= 0 then
    local _x = enemy.screen_seq[1][1]
    local _y = enemy.screen_seq[1][2]
    enemy.screen_seq = {{_x-1,_y+1}}
    local _a = sprites.die_1
    local _b = sprites.die_2
    enemy.sprite_seq = {_a,_a,_a,_a,_b,_b,_b,_b}
  else
    local b_r = {colors.black, colors.red}
    enemy.pal_seq = {b_r, b_r, b_r, b_r, {10,10}}
  end
end

--[[
  enemy stuff
--]]

-- create an enemy and add it to the array of enemies
function new_enemy()
	local new_enemy = {
    -- board position
    x = null,
    y = null,
    -- a sequence of screen positions
    screen_seq = {},
    -- a sequence of sprites
    sprite_seq = {sprites.enemy},
    -- a sequence of palette modifications
    pal_seq = {{10,10}},
    -- other stuff
		type = "hero",
    type = "enemy",
    stunned = true,
    health = 2,
    update = function(self)

      if self.health <= 0 then
        return
      end

      if self.stunned == true then
        self.stunned = false
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
            target.health -= 1
            local here = tile_to_screen({self.x, self.y})
            local bump = {here[1] + direction[1] * 2, here[2] + direction[2] * 2}
            transition_to(self, {bump, here}, 2, 2)
            local b_r = {colors.black, colors.red}
            target.pal_seq = {b_r, b_r, b_r, b_r, {10,10}}
            delay += 4
            sfx(sounds.enemy_bump, 3)
          end
        else
          set_tile(self, dest)
          transition_to(self, {tile_to_screen(dest)}, 4, 0)
          delay += 4
        end
      end
		end,
    draw = function(self)

      -- set sprite based on the first value in sprite_seq
      local sprite = self.sprite_seq[1]

      -- set the current screen destination using the first value in screen_seq
      local sx = self.screen_seq[1][1]
      local sy = self.screen_seq[1][2]

      -- default palette updates
      palt(colors.tan, true)
      palt(colors.black, false)
      if self.stunned then
        pal(colors.black, colors.light_gray)
      end

      -- update the palette based using first value in pal_seq
      pal(self.pal_seq[1][1], self.pal_seq[1][2])

      -- draw the enemy and its health
      spr(sprite, sx, sy)
      draw_health(sx, sy, self.health)

      -- draw crosshairs
      if self.health >= 1 then
        if self.is_shoot_target then
          pal(colors.light_gray, colors.green)
          spr(sprites.crosshair, sx, sy)
        end
        if self.is_ghost_target then
          pal(colors.light_gray, colors.blue)
          spr(sprites.crosshair, sx, sy)
        end
      end

      -- after drawing, if the enemy is dead and done rendering all its sprites, delete it
      if self.health <= 0 and #self.sprite_seq <= 1 then
        del(board[self.x][self.y], self)
        del(enemies, self)
      end

      -- for all these lists, if there's more than one value, remove the first one
      if #self.screen_seq > 1 then
        del(self.screen_seq, self.screen_seq[1])
      end
      if #self.sprite_seq > 1 then
        del(self.sprite_seq, self.sprite_seq[1])
      end
      if #self.pal_seq > 1 then
        del(self.pal_seq, self.pal_seq[1])
      end

      -- reset the palette
      pal()
    end,
    deploy = function(self)

      local valid_tiles = {}
      local avoid_list = {"hero", "enemy"}

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

      for next in all(valid_tiles) do
        for dir in all({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
          local spot = {next[1] + dir[1], next[2] + dir[2]}
          if location_exists(spot) and find_type_in_tile("hero", spot) then
            del(valid_tiles, next)
          end
        end
      end

      local index = flr(rnd(#valid_tiles)) + 1
      local dest = valid_tiles[index]

      set_tile(self, dest)
    end
	}
	add(enemies, new_enemy)
  return new_enemy
end

function get_direction(a, b)
  local ax = a[1]
  local ay = a[2]
  local bx = b[1]
  local by = b[2]
  -- up
  if bx == ax and by == ay - 1 then
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

  for i = 1, 12 do
    local wall_right = {
      x = null,
      y = null,
      type = "wall_right",
      draw = function(self)
        palt(0, false)
        local x_pos = (self.x - 1) * sprite_size + (self.x - 1) * tile_margin + padding_left
        local y_pos = (self.y - 1) * sprite_size + (self.y - 1) * tile_margin + padding_top

        local outer_color = bg_color
        local inner_color = wall_color

        local hero_l = find_type_in_tile("hero", {self.x, self.y})
        local hero_r = find_type_in_tile("hero", {self.x + 1, self.y})
        if hero_l and hero_l.ghost or hero_r and hero_r.ghost then
          inner_color = colors.white
        end

        local x3 = x_pos + sprite_size + flr(tile_margin / 2)
        local y3 = y_pos - ceil(tile_margin / 2)
        local x4 = x_pos + sprite_size + flr(tile_margin / 2)
        local y4 = y_pos + sprite_size + flr(tile_margin / 2)

        local x1 = x3 - 1
        local y1 = y3 - 1
        local x2 = x4 + 1
        local y2 = y4 + 1

        rectfill(x1, y1, x2, y2, outer_color)
        rectfill(x3, y3, x4, y4, inner_color)
        palt()
      end,
    }
    deploy(wall_right, {"wall_right"})
  end
  for i = 1, 9 do
    local wall_down = {
      x = null,
      y = null,
      type = "wall_down",
      draw = function(self)
        palt(0, false)
        local x_pos = (self.x - 1) * sprite_size + (self.x - 1) * tile_margin + padding_left
        local y_pos = (self.y - 1) * sprite_size + (self.y - 1) * tile_margin + padding_top

        local outer_color = bg_color
        local inner_color = wall_color

        local hero_u = find_type_in_tile("hero", {self.x, self.y})
        local hero_d = find_type_in_tile("hero", {self.x, self.y + 1})
        if hero_u and hero_u.ghost or hero_d and hero_d.ghost then
          inner_color = colors.white
        end

        local x3 = x_pos - ceil(tile_margin / 2)
        local y3 = y_pos + sprite_size + flr(tile_margin / 2)
        local x4 = x_pos + sprite_size + flr(tile_margin / 2)
        local y4 = y_pos + sprite_size + flr(tile_margin / 2)

        local x1 = x3 - 1
        local y1 = y3 - 1
        local x2 = x4 + 1
        local y2 = y4 + 1

        rectfill(x1, y1, x2, y2, outer_color)
        rectfill(x3, y3, x4, y4, inner_color)
        palt()
      end,
    }
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
        draw = function(self)
          spr(sprites.exit, self.screen_seq[1], self.s[2])
        end,
      }
      add(exits, exit)
      deploy(exit, {"button", "hero", "exit"})
    end
    return
  end

  local current_colors = {
    "blue",
    "green",
    "red",
    "orange"
  }
  local index = flr(rnd(#current_colors)) + 1
  local to_remove = current_colors[index]
  del(current_colors, to_remove)

  -- place new pads
  for next in all(current_colors) do
    local new_pad = {
      screen_seq = {},
      type = "pad",
      color = next,
      draw = function(self)
        local sprite = sprites.pad
        local sx = self.screen_seq[1][1]
        local sy = self.screen_seq[1][2]
        if
          find_type_in_tile("pad", {hero_a.x, hero_a.y}) or
          find_type_in_tile("pad", {hero_b.x, hero_b.y})
        then
          sprite = sprites.pad
        end
        palt(colors.tan, true)
        palt(colors.black, false)
        pal(colors.light_gray, colors[self.color])
        spr(sprite, sx, sy)
        pal()
      end,
    }
    add(pads, new_pad)
    deploy(new_pad, {"pad", "button", "hero"})
  end
end

function new_button(color)

  local new_button = {
    x = null,
    y = null,
    screen_seq = {},
    type = "button",
    color = color,
    draw = function(self)
      local sprite = sprites.button
      local sx = self.screen_seq[1][1]
      local sy = self.screen_seq[1][2]
      palt(colors.tan, true)
      palt(colors.black, false)
      pal(colors.light_gray, colors[self.color])
      if self.color == "blue" then
        pal(colors.dark_gray, colors.navy)
      elseif self.color == "green" then
        pal(colors.dark_gray, colors.forest)
      elseif self.color == "red" then
        pal(colors.dark_gray, colors.maroon)
      elseif self.color == "orange" then
        pal(colors.dark_gray, colors.brown)
      end
      spr(sprite, sx, sy)
      pal()
    end,
  }
  add(buttons, new_button)
  return new_button
end

__gfx__
00000000ffffffffff000fffffffffffffffffffffff6fffffff6fff000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffff070ffffffffffffff6ffffff6f6fffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff000fff0007000f000000fffff6ffffffffff6fffffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000007000f0777770f077770ffffffffff66ffffff6fffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000777770f0007000f007070ff66f6f66fffffff66fffffff6000000000000000000000000000000000000000000000000000000000000000000000000
000000000007000ff07070ff077770fffffffffff6ffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000f07070fff07070ff007700fffff6fffffff6f6ffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000f00000fff00000fff0000ffffff6fffffff6fffffff6ffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f66ff66fff6666ffeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f6ffff6ff666666feffffffe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000fffffffff666666fefeeeefe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000fffffffff566665fefeffefe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f6ffff6ff555555fefeeeefe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f66ff66fff5555ffeffffffe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffffeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000006070060006000060600000600600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000600600076000000000600006006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006006070006060006006060060000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060070060006000060000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006006076000600006000606006000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000600600070606060600060000060006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000006070000000000600607000600070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000060060077777777706006007000006070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000e00e000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000001343333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000001312222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000001312222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000001312222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000217521b7521775214752117520f7520d7520b75209752087520675205752047520475204752037520c7020b7020b7020a7020a7020970209702097020970200702007020070200702007020070200702
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

