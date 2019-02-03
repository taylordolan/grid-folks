pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

-- todo
-- [x] walls between tiles
-- [x] prevent wall generation from creating closed areas
-- [x] tiles with walls should count as empty for the purpose of deploying enemies and heroes
-- [x] health for enemies
-- [x] clean up power stuff
-- [x] power tiles for melee damage
-- [x] press 'x' to switch heroes (instead of holding it)
-- [x] power tiles for health
-- [x] power tiles for score
-- [x] rename power tiles to effect tiles
-- [x] have some power tiles by default
-- [x] have some start locations for heroes
-- [x] make a sprite dictionary again
-- [x] add potential tiles for each type
    -- deploy 3 random ones at the beginning of the game
    -- include conditions for turning them into power tiles
-- [x] when a potential tile is triggered, reset walls and deploy 3 more random ones
-- [x] have enemies appear on a fixed schedule
-- [x] telegraph enemy arrival a turn in advance
-- [x] things should probably keep track of their own x and y locations
-- [x] replace melee with dash ability
-- [x] fix bug where sometimes enemies show up to fast
-- [x] enemies should trigger effect tiles when they spawn on them
-- [x] rework _draw() so there's more space between tiles
-- [ ] have enemies appear on an increasing schedule
-- [ ] build the game end state

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

  -- some game state
  player_turn = true
	game_over = false
  score = 0
  turns = 0

  sprites = {
    floor = 003,
    hero = 017,
    hero_dash = 019,
    hero_shoot = 021,
    enemy = 002,
    pre_enemy = 004,
    wall_right = 005,
    wall_down = 006,
    effect_dash = 023,
    effect_shoot = 024,
    effect_health = 025,
    effect_score = 026,
    potential_dash = 007,
    potential_shoot = 008,
    potential_health = 009,
    potential_score = 010,
  }

  -- create walls
  generate_walls()
  while is_map_contiguous() == false do
    clear_all_walls()
    generate_walls()
  end

  -- local dash_tile = {
  --   x = null,
  --   y = null,
  --   type = "effect",
  --   name = "dash",
  --   sprite = sprites.effect_dash,
  --   hero_sprite = sprites.hero_dash
  -- }
  -- local shoot_tile = {
  --   x = null,
  --   y = null,
  --   type = "effect",
  --   name = "shoot",
  --   sprite = sprites.effect_shoot,
  --   hero_sprite = sprites.hero_shoot
  -- }
  -- local health_tile = {
  --   x = null,
  --   y = null,
  --   type = "effect",
  --   name = "health",
  --   sprite = sprites.effect_health,
  -- }
  -- local score_tile = {
  --   x = null,
  --   y = null,
  --   type = "effect",
  --   name = "score",
  --   sprite = sprites.effect_score,
  -- }
  -- set_tile(dash_tile, {3,3})
  -- set_tile(shoot_tile, {6,6})
  -- set_tile(health_tile, {3,6})
  -- set_tile(score_tile, {6,3})

  generate_potential_tiles()

  -- heroes
  hero_a = create_hero()
  hero_b = create_hero()
  heroes = {hero_a, hero_b}
  set_tile(hero_a, {4,2})
  set_tile(hero_b, {6,4})
  hero_a_active = true

	-- list of enemies
	enemies = {}
  pre_enemies = {}
  local new_pre_enemy = create_pre_enemy()
  deploy(new_pre_enemy, {"hero", "enemy", "pre-enemy"})

  local has_switched = false
  local has_killed = false
  -- local has_advanced = false
end

function _update()

  if btnp(5) then
    hero_a_active = not hero_a_active
    has_switched = true
  end

	-- move heroes
  if hero_a_active then
    hero_a.sprite = hero_a.base_sprite + 1
    hero_b.sprite = hero_b.base_sprite
    hero_a:update()
  else
    hero_a.sprite = hero_a.base_sprite
    hero_b.sprite = hero_b.base_sprite + 1
    hero_b:update()
  end

  -- move enemies
  if player_turn == false then
    for next in all(enemies) do
      next.update(next)
    end
  end

  -- game end test
  if hero_a.health == 0 or hero_b.health == 0 then
    game_over = true
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

function _draw()

	cls()
  local text_color = 07
  local background_color = 00
  local floor_color = 07
  local wall_color = 07

  local screen_size = 128
  local sprite_size = 8
  local margin = 5

  local total_sprites_width = sprite_size * cols
  local total_margins_width = margin * (cols - 1)
  local total_map_width = total_sprites_width + total_margins_width

  local total_sprites_height = sprite_size * rows
  local total_margins_height = margin * (rows - 1)
  local total_map_height = total_sprites_height + total_margins_height

  local padding_left = flr((screen_size - total_map_width) / 2)
  -- local padding_top = flr((screen_size - total_map_height) / 2)
  local padding_top = 20


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

  function draw_score()
    local text = score.." gold"
    print(smallcaps(text), 128 - padding_left + ceil(margin / 2) - (#text * 4) + 1, 06, 09)
    print(smallcaps("grid folks"), padding_left - ceil(margin / 2), 06, 07)
  end

  function draw_instructions()
    if not has_switched or not has_killed then
      draw_intro_instructions()
    else
      draw_button_instructions()
    end
  end

  function draw_intro_instructions()
    palt(0, false)
    palt(15, true)
    local x_pos = padding_left - ceil(margin / 2)
    local y_pos = 90
    local line_height = 11
    print(smallcaps("press \151 to switch"), x_pos, y_pos)
    spr(sprites.hero + 1, x_pos + 75, y_pos - 2)
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

    -- advance
    spr(sprites.hero + 1, x_pos, y_pos - 2)
    spr(011, x_pos + 7, y_pos - 2)
    print("+", x_pos + 18, y_pos, 06)
    spr(sprites.hero + 1, x_pos + 23, y_pos - 2)
    spr(011, x_pos + 30, y_pos - 2)
    print("=", x_pos + 41, y_pos, 06)
    spr(012, x_pos + 47, y_pos - 2)
    y_pos += line_height

    -- shoot
    spr(sprites.hero + 1, x_pos, y_pos - 2)
    spr(sprites.effect_shoot, x_pos + 7, y_pos - 2)
    print("=", x_pos + 18, y_pos, 06)
    print(smallcaps("shoot"), x_pos + 25, y_pos, text_color)
    y_pos += line_height

    -- dash
    spr(sprites.hero + 1, x_pos, y_pos - 2)
    spr(sprites.effect_dash, x_pos + 7, y_pos - 2)
    print("=", x_pos + 18, y_pos, 06)
    print(smallcaps("dash"), x_pos + 25, y_pos, text_color)

    x_pos += 72
    y_pos -= line_height

    -- health
    spr(sprites.enemy, x_pos, y_pos - 2)
    spr(sprites.effect_health, x_pos + 7, y_pos - 2)
    print("=", x_pos + 18, y_pos, 06)
    print(smallcaps("heal"), x_pos + 25, y_pos, text_color)
    y_pos += line_height

    -- gold
    spr(sprites.enemy, x_pos, y_pos - 2)
    spr(sprites.effect_score, x_pos + 7, y_pos - 2)
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
  -- draw_switch_instructions()
  -- draw_button_instructions()

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
            spr(sprite, x_pos, y_pos)
              -- draw a health bar for things with health
            if (next.health) then
              draw_health(x_pos, y_pos, next.health)
            end
            palt()
          end
				end
			end
		end
	end

  draw_outlines()

  if game_over then
		local msg = "dead"
		local msg_x = 64 - (#msg * 4) / 2
		print(msg, msg_x, 61, 8)
	end
end

--[[
  helper functions
--]]

-- returns a random tile from the board
function random_tile()
  -- create an array of all tiles
	local all_tiles = {}
	for x = 1, cols do
		for y = 1, rows do
      add(all_tiles, {x,y})
		end
	end
  -- return one of them
	local index = flr(rnd(#all_tiles)) + 1
  return all_tiles[index]
end

-- returns an empty tile from the board
function random_empty_tile()
	-- create an array of all empty tiles
	local empty_tiles = {}
	for x = 1, cols do
		for y = 1, rows do
			if #board[x][y] == 0 then
				add(empty_tiles, {x,y})
			end
		end
	end
  -- return one of them
	local index = flr(rnd(#empty_tiles)) + 1
	return empty_tiles[index]
end

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

  -- trigger enemy effects if an enemy was deployed
  -- todo: this should probably be like a special version of set_tile() in `enemy`
  if (thing.type == "enemy") then
    trigger_enemy_effects(dest)
  end
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

function trigger_enemy_effects(enemy_tile)

  function health_effect()
    for next in all(heroes) do
      if (next.health < next.max_health) then
        next.health = next.health + 1
      end
    end
  end

  function score_effect()
    score = score + 1
  end

  local effect = find_type_in_tile("effect", enemy_tile)
  if effect then
    if effect.name == "health" then
      health_effect()
    end
    if effect.name == "score" then
      score_effect()
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

    x = null,
    y = null,
		type = "hero",
    base_sprite = 17,
    sprite = null,
    max_health = 4,
    health = 4,

    -- effects
    dash = false,
    shoot = false,

    -- update hero
		update = function(self)

      -- find the other hero
      local companion
      if heroes[1] == self then
        companion = heroes[2]
      else
        companion = heroes[1]
      end

      -- move up
			if btnp(⬆️) then
        local direction = {0, -1}
        act(direction)
      end
      -- move down
			if btnp(⬇️) then
        local direction = {0, 1}
        act(direction)
      end
      -- move left
			if btnp(⬅️) then
        local direction = {-1, 0}
        act(direction)
      end
      -- move right
			if btnp(➡️) then
        local direction = {1, 0}
        act(direction)
      end

      -- this is called when the player hits a direction on their turn.
      -- it determines which action should be taken and triggers it.
      function act(direction)
        local next_tile = {self.x + direction[1], self.y + direction[2]}
        if
          location_exists(next_tile) and
          not is_wall_between({self.x, self.y}, next_tile) and
          not find_type_in_tile("hero", next_tile)
        then
          shoot_target = get_shoot_target(direction)
          if self.shoot and shoot_target then
            shoot_target.stunned = true
            hit_enemy(shoot_target, 1)
            end_turn()
          elseif self.dash then
            step_or_bump(direction)
            next_tile = {self.x + direction[1], self.y + direction[2]}
            if
              location_exists(next_tile) and
              not is_wall_between({self.x, self.y}, next_tile) and
              not find_type_in_tile("hero", next_tile)
            then
              step_or_bump(direction)
            end
            end_turn()
          else
            step_or_bump(direction)
            end_turn()
          end
        end
      end

      function step_or_bump(direction)
        local target_tile = {self.x + direction[1], self.y + direction[2]}
        local enemy = find_type_in_tile("enemy", target_tile)
        if enemy then
          hit_enemy(enemy, 1)
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
          if location_exists(next_tile) == false or is_wall_between(now_tile, next_tile) then
            return false
          end
          -- if there's an enemy in the target, return it
          local enemy = find_type_in_tile("enemy", next_tile)
          if enemy then
            return enemy
          end
          -- set `current` to `next_tile` and keep going
          now_tile = next_tile
        end
      end

      -- -- given an enemy and an amount of damage,
      -- -- hit it and then kill if it has no health
      function hit_enemy(enemy, damage)

        enemy.health -= damage
        if (enemy.health <= 0) then
          has_killed = true
          del(enemies, enemy)
          del(board[enemy.x][enemy.y], enemy)
        end
      end

      -- updates the *other* hero's ability and sprite
      -- based on the effect tile that *this* hero is standing on
      function update_companion_effect()

        local here = {self.x, self.y}

        -- set companion deets to their defaults
        companion.dash = false
        companion.shoot = false
        companion.base_sprite = sprites.hero

        -- check if this hero's tile is a effect tile
        local effect = find_type_in_tile("effect", here)
        if effect then
          if effect.name == "dash" or effect.name == "shoot" then
            -- apply the effect's effect to the companion hero
            companion[effect.name] = true
            companion.base_sprite = effect.hero_sprite
          end
        end
      end

      function update_potential_tiles()

        local companion_tile = {companion.x, companion.y}
        self_potential_tile = find_type_in_tile("potential", {self.x, self.y})
        companion_potential_tile = find_type_in_tile("potential", companion_tile)

        if self_potential_tile and companion_potential_tile then

          -- has_advanced = true
          local to_destroy = {self_potential_tile, companion_potential_tile}
          for next in all(to_destroy) do
            del(board[next.x][next.y], next)
          end

          -- todo: optimize this
          for x = 1, cols do
            for y = 1, rows do
              local potential_tile = find_type_in_tile("potential", {x,y})
              if potential_tile then
                potential_tile.type = "effect"
                potential_tile.sprite = sprites["effect_" ..potential_tile.name]
                potential_tile.hero_sprite = sprites["hero_" ..potential_tile.name]
              end
            end
          end

          generate_potential_tiles()
          clear_all_walls()
          generate_walls()
          while is_map_contiguous() == false do
            clear_all_walls()
            generate_walls()
          end
        end
      end

      -- does whatever needs to happen after a hero has done its thing
      function end_turn()
        update_potential_tiles()
        update_companion_effect()
        for next in all(pre_enemies) do
          del(pre_enemies, next)
          del(board[next.x][next.y], next)
          if not find_type_in_tile("hero", {next.x, next.y}) and not find_type_in_tile("enemy", {next.x, next.y}) then
            local new_enemy = create_enemy({next.x, next.y})
            new_enemy.stunned = true
          end
        end
        if turns > 0 and turns % 12 == 0 then
          local new_pre_enemy = create_pre_enemy()
          deploy(new_pre_enemy, {"hero", "enemy", "pre-enemy"})
        end
        turns = turns + 1
        player_turn = false
      end
		end
	}
  return hero
end

--[[
  enemy stuff
--]]

function create_pre_enemy()
  pre_enemy = {
    x = null,
    y = null,
    type = "pre_enemy",
    sprite = sprites.pre_enemy
  }
  add(pre_enemies, pre_enemy)
  return pre_enemy
end

-- create an enemy and add it to the array of enemies
function create_enemy(tile)
	enemy = {
    x = null,
    y = null,
    type = "enemy",
    sprite = sprites.enemy,
    health = 3,
    stunned = true,
    update = function(self)

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
            target.health -= 1
          end
        else
          set_tile(self, dest)
          trigger_enemy_effects(dest)
        end
      end
      player_turn = true
		end
	}
	add(enemies, enemy)
  set_tile(enemy, tile)
  return enemy
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

function generate_potential_tiles()

  local current_types = {
    "dash",
    "shoot",
    "health",
    "score"
  }
  local index = flr(rnd(#current_types)) + 1
  local to_remove = current_types[index]
  del(current_types, to_remove)

  for next in all(current_types) do
    local tile = {
      type = "potential",
      name = next,
      sprite = sprites["potential_" ..next]
    }
    deploy(tile, {"potential", "effect", "hero"})
  end
end

__gfx__
0000000000000000ffffffff55555555ffffffff0000000d00000000ffffffffffffffffffffffffffffffffffffffffffffffff555555558888888800000000
0000000000000000000000ff55555555666666ff0000000d00000000ffcffcffffbffbffff8ff8ffff9ff9ffff7ff7ffff7777ff55dddd558888888800000000
0000000000000000077770ff55555555677776ff0000000d00000000fccffccffbbffbbff88ff88ff99ff99ff77ff77ff777777f5dd55dd58888888800000000
0000000000000000007070ff55555555667676ff0000000d00000000fffffffffffffffffffffffffffffffffffffffff777777f5d5555d58888888800000000
0000000000000000077770ff55555555677776ff0000000d00000000fffffffffffffffffffffffffffffffffffffffff577775f5d5555d58888888800000000
0000000000000000007700ff55555555667766ff0000000d00000000fccffccffbbffbbff88ff88ff99ff99ff77ff77ff555555f5dd55dd58888888800000000
0000000000000000f0000fff55555555f6666fff0000000d00000000ffcffcffffbffbffff8ff8ffff9ff9ffff7ff7ffff5555ff55dddd558888888800000000
0000000000000000ffffffff55555555ffffffff0000000dddddddddffffffffffffffffffffffffffffffffffffffffffffffff555555558888888800000000
00000000ffffffffff000fffffffffffff000fffffffffffff000fffffffffffffffffffffffffffffffffff5555555555555555555555550000000000000000
00000000ffffffffff070fffffffffffff0c0fffffffffffff0b0fffffccccffffbbbbffff8888ffff9999ff55aaaa5555cccc5555dddd550000000000000000
00000000ff000fff0007000fff000fff000c000fff000fff000b000ffccccccffbbbbbbff888888ff999999f5aaaaaa55cccccc55dddddd50000000000000000
000000000007000f0777770f000c000f0ccccc0f000b000f0bbbbb0ffccccccffbbbbbbff888888ff999999f5aaaaaa55cccccc55dddddd50000000000000000
000000000777770f0007000f0ccccc0f000c000f0bbbbb0f000b000ff1cccc1ff3bbbb3ff288882ff499994f59aaaa9551cccc1551dddd150000000000000000
000000000007000ff07070ff000c000ff0c0c0ff000b000ff0b0b0fff111111ff333333ff222222ff444444f5999999551111115511111150000000000000000
00000000f07070fff07070fff0c0c0fff0c0c0fff0b0b0fff0b0b0ffff1111ffff3333ffff2222ffff4444ff5599995555111155551111550000000000000000
00000000f00000fff00000fff00000fff00000fff00000fff00000ffffffffffffffffffffffffffffffffff5555555555555555555555550000000000000000
00000000550005555500005555555555555555555555555500000000555555555555555555555555555555555555555555555555555555555555555500000000
0000000055070555550770550000005500000555000000050000000055cccc5555888855558888555599995557777785577777b5588888855bbbbbb500000000
000000000007000500077000077770550777055507777705000000005cccccc55888888558888885599999955788882557bbbb35585555855b5555b500000000
000000000777770507777770007070550707055507070705000000005cccccc55888888558888885599999955788882557bbbb35585555855b5555b500000000
0000000000070005000770000777705507770555077777050000000051cccc155288882552888825549999455788882557bbbb35585555855b5555b500000000
00000000507070555070070500770055070705550000000500000000511111155222222552222225544444455788882557bbbb35585555855b5555b500000000
0000000050707055507007055000055507070555507770550000000055111155552222555522225555444455582222255b333335588888855bbbbbb500000000
00000000500000555000000555555555000005555000005500000000555555555555555555555555555555555555555555555555555555555555555500000000
00000000000000005555555555000555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555500000000
000000000000000055555555550c055500000055666666655555555555555555555555555555555555555555577777c5577777a55cccccc55aaaaaa500000000
000000000000000055000555000c000507777055655555655500055555cccc5555bbbb55558888555599995557cccc1557aaaa955c5555c55a5555a500000000
0000000000000000000c00050ccccc050070705565656565000900055cccccc55bbbbbb5588888855999999557cccc1557aaaa955c5555c55a5555a500000000
00000000000000000ccccc05000c00050777705565555565099999055cccccc55bbbbbb5588888855999999557cccc1557aaaa955c5555c55a5555a500000000
0000000000000000000c000550c0c05500770055665556650009000551cccc1553bbbb35528888255499994557cccc1557aaaa955c5555c55a5555a500000000
000000000000000050c0c05550c0c055500005555655565550909055551111555533335555222255554444555c1111155a9999955cccccc55aaaaaa500000000
00000000000000005000005550000055555555555666665550000055555555555555555555555555555555555555555555555555555555555555555500000000
__sfx__
000a0000125703f3503f3303f3103f3003f3000230000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
