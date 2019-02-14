pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

-- todo
-- [x] players still aren't gaining health when enemies spawn to health tiles
-- [x] you shouldn't be able to shoot through players
-- [x] implement a delay before enemy movement
-- [ ] write a function that prints a overview of the spawn rate throughout the game
-- [ ] add a debug mode where spawn rate and turn count show while playing
-- [ ] build the game end state
-- [ ] clean up _init()
-- [ ] allow restarting after game over by calling _init() again

sounds = {
  music = 002,
  health = 026,
  score = 022,
  shoot = 029,
  dash = 025,
  step = 021,
  advance = 027,
  potential_tile_step = 028, -- todo: this shouldn't trigger when you're just standing there
  switch_heroes = 000,
  enemy_bump = 000,
  hero_bump = 000
}

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
  delay = 0

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

  local dash_tile = {
    x = null,
    y = null,
    type = "effect",
    name = "dash",
    sprite = sprites.effect_dash,
    hero_sprite = sprites.hero_dash
  }
  local shoot_tile = {
    x = null,
    y = null,
    type = "effect",
    name = "shoot",
    sprite = sprites.effect_shoot,
    hero_sprite = sprites.hero_shoot
  }
  local health_tile = {
    x = null,
    y = null,
    type = "effect",
    name = "health",
    sprite = sprites.effect_health,
  }
  local score_tile = {
    x = null,
    y = null,
    type = "effect",
    name = "score",
    sprite = sprites.effect_score,
  }
  set_tile(dash_tile, {5,2})
  set_tile(shoot_tile, {5,4})
  set_tile(health_tile, {6,3})
  set_tile(score_tile, {4,3})

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

  -- start the music!
  music(sounds.music)
end

function get_spawn_rate()
  return spawn_modifier - flr(sqrt(spawn_base))
end

function maybe_spawn_enemy()
  local spawn_rate = get_spawn_rate()
  if turns - spawn_rate >= last_spawned_turn then
    local new_pre_enemy = create_pre_enemy()
    deploy(new_pre_enemy, {"hero", "enemy", "pre-enemy"})
    printh(spawn_base)
    last_spawned_turn = turns
  end
end

function _update()

  update_hero_sprites()
  -- if hero_a_active then
  --   hero_a.sprite = hero_a.base_sprite + 1
  --   hero_b.sprite = hero_b.base_sprite
  -- else
  --   hero_a.sprite = hero_a.base_sprite
  --   hero_b.sprite = hero_b.base_sprite + 1
  -- end

  if delay > 0 then
		delay = delay - 1
	elseif player_turn == true then
		if hero_a_active then
      hero_a:update()
    else
      hero_b:update()
    end
		-- if delay > 0 then turn=1 end
	elseif player_turn == false then
    -- if #enemies > 0 then
    for next in all(enemies) do
      next.update(next)
    end
    -- delay = delay + 30
    -- end
    player_turn = true
	end

  if btnp(5) then
    hero_a_active = not hero_a_active
    has_switched = true
  end

	-- move heroes
  -- if hero_a_active then
  --   hero_a.sprite = hero_a.base_sprite + 1
  --   hero_b.sprite = hero_b.base_sprite
  --   hero_a:update()
  -- else
  --   hero_a.sprite = hero_a.base_sprite
  --   hero_b.sprite = hero_b.base_sprite + 1
  --   hero_b:update()
  -- end

  -- move enemies
  -- if player_turn == false then
  --   for next in all(enemies) do
  --     next.update(next)
  --   end
  -- end

  -- game end test
  if hero_a.health <= 0 or hero_b.health <= 0 then
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
    local text = score.. " gold"
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
    spr(sprites.effect_shoot, x_pos + 7, y_pos - 2)
    print("=", x_pos + 18, y_pos, 06)
    spr(sprites.hero + 1, x_pos + 24, y_pos - 2)
    print(smallcaps("shoot"), x_pos + 32, y_pos, text_color)
    y_pos += line_height

    -- dash
    spr(sprites.hero, x_pos, y_pos - 2)
    spr(sprites.effect_dash, x_pos + 7, y_pos - 2)
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
		print(smallcaps(msg), msg_x, 47, 8)
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

  -- this is here for now because enemy effects need to be triggered when enemies step or are deployed
  -- todo: this should probably be done differently somehow
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
    sfx(sounds.health, 3)
  end

  function score_effect()
    score += 1
    sfx(sounds.score, 3)
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
    base_sprite = sprites.hero,
    sprite = null,
    max_health = 5,
    health = 5,

    -- effects
    dash = false,
    shoot = false,

    -- update hero
		update = function(self)

      if game_over then return end

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
            sfx(sounds.shoot, 3)
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
              sfx(sounds.dash, 3)
            end
            end_turn()
          else
            step_or_bump(direction)
            sfx(sounds.step, 3)
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
          if
            location_exists(next_tile) == false or
            is_wall_between(now_tile, next_tile) or
            find_type_in_tile("hero", next_tile)
          then
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

      -- -- -- given an enemy and an amount of damage,
      -- -- -- hit it and then kill if it has no health
      -- function hit_enemy(enemy, damage)

      --   enemy.health -= damage
      --   if (enemy.health <= 0) then
      --     has_killed = true
      --     del(enemies, enemy)
      --     del(board[enemy.x][enemy.y], enemy)
      --   end
      -- end

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
          sfx(sounds.advance, 3)
        elseif self_potential_tile then
          sfx(sounds.potential_tile_step, 3)
        end
      end

      -- does whatever needs to happen after a hero has done its thing
      function end_turn()
        update_potential_tiles()
        update_companion_effect()
        spawn_base += spawn_increment
        for next in all(pre_enemies) do
          del(pre_enemies, next)
          del(board[next.x][next.y], next)

          local found_hero = find_type_in_tile("hero", {next.x, next.y})
          local found_enemy = find_type_in_tile("enemy", {next.x, next.y})

          if found_hero then
            found_hero.health -= 1
          elseif found_enemy then
            hit_enemy(found_enemy, 1)
          else
            local new_enemy = create_enemy({next.x, next.y})
            new_enemy.stunned = true
          end
        end
        turns = turns + 1
        maybe_spawn_enemy()
        player_turn = false
        if #enemies > 0 then
          delay += 8
        end
      end
		end
	}
  return hero
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

-- given an enemy and an amount of damage,
-- hit it and then kill if it has no health
function hit_enemy(enemy, damage)

  enemy.health -= damage
  if (enemy.health <= 0) then
    has_killed = true
    del(enemies, enemy)
    del(board[enemy.x][enemy.y], enemy)
  end
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
          -- trigger_enemy_effects(dest)
        end
      end
      -- player_turn = true
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
0000000000000000ffffffff00000000ffffffff0000000d00000000ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000
0000000000000000000000ff00000000666666ff0000000d00000000ffcffcffffbffbffff8ff8ffff9ff9ffff7ff7ffff7777ff000000000000000000000000
0000000000000000077770ff00000000677776ff0000000d00000000fccffccffbbffbbff88ff88ff99ff99ff77ff77ff777777f000000000000000000000000
0000000000000000007070ff00000000667676ff0000000d00000000fffffffffffffffffffffffffffffffffffffffff777777f000000000000000000000000
0000000000000000077770ff00000000677776ff0000000d00000000fffffffffffffffffffffffffffffffffffffffff577775f000000000000000000000000
0000000000000000007700ff00000000667766ff0000000d00000000fccffccffbbffbbff88ff88ff99ff99ff77ff77ff555555f000000000000000000000000
0000000000000000f0000fff00000000f6666fff0000000d00000000ffcffcffffbffbffff8ff8ffff9ff9ffff7ff7ffff5555ff000000000000000000000000
0000000000000000ffffffff00000000ffffffff0000000dddddddddffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000
00000000ffffffffff000fffffffffffff000fffffffffffff000fffffffffffffffffffffffffffffffffff7777777700000000000000000000000000000000
00000000ffffffffff070fffffffffffff0c0fffffffffffff0b0fffffccccffffbbbbffff8888ffff9999ff7767767700000000000000000000000000000000
00000000ff000fff0007000fff000fff000c000fff000fff000b000ffccccccffbbbbbbff888888ff999999f7765567700000000000000000000000000000000
000000000007000f0777770f000c000f0ccccc0f000b000f0bbbbb0ffccccccffbbbbbbff888888ff999999f7566665700000000000000000000000000000000
000000000777770f0007000f0ccccc0f000c000f0bbbbb0f000b000ff1cccc1ff3bbbb3ff288882ff499994f7060060700000000000000000000000000000000
000000000007000ff07070ff000c000ff0c0c0ff000b000ff0b0b0fff111111ff333333ff222222ff444444f7066660700000000000000000000000000000000
00000000f07070fff07070fff0c0c0fff0c0c0fff0b0b0fff0b0b0ffff1111ffff3333ffff2222ffff4444ff7760067700000000000000000000000000000000
00000000f00000fff00000fff00000fff00000fff00000fff00000ffffffffffffffffffffffffffffffffff7777777700000000000000000000000000000000
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

