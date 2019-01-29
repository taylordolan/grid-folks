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
-- [ ] enemies should trigger effect tiles when they spawn on them
-- [ ] replace melee with dash ability
-- [ ] rework _draw() so there's more space between tiles
-- [ ] have enemies appear on an increasing schedule
-- [ ] things should probably keep track of their own x and y locations

function _init()

	-- board size
	rows = 8
	cols = 8

	-- 2d array for the board
	board = {}
	for x = 1, rows do
		board[x] = {}
		for y = 1, cols do
			board[x][y] = {}
		end
	end

  -- some game state
  player_turn = true
	game_over = false
  score = 0
  turns = 0

  sprites = {
    hero = 017,
    hero_melee = 019,
    hero_shoot = 021,
    enemy = 002,
    pre_enemy = 004,
    wall_right = 005,
    wall_down = 006,
    effect_melee = 023,
    effect_shoot = 024,
    effect_health = 025,
    effect_score = 026,
    potential_melee = 007,
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

  local melee_tile = {
    type = "effect",
    name = "melee",
    sprite = sprites.effect_melee,
    hero_sprite = sprites.hero_melee
  }
  local shoot_tile = {
    type = "effect",
    name = "shoot",
    sprite = sprites.effect_shoot,
    hero_sprite = sprites.hero_shoot
  }
  local health_tile = {
    type = "effect",
    name = "health",
    sprite = sprites.effect_health,
  }
  local score_tile = {
    type = "effect",
    name = "score",
    sprite = sprites.effect_score,
  }
  set_tile(melee_tile, {3,3})
  set_tile(shoot_tile, {6,6})
  set_tile(health_tile, {3,6})
  set_tile(score_tile, {6,3})

  generate_potential_tiles()

  -- heroes
  hero_a = create_hero()
  hero_b = create_hero()
  heroes = {hero_a, hero_b}
  set_tile(hero_a, {4,4})
  set_tile(hero_b, {5,5})
  hero_a_active = true

	-- list of enemies
	enemies = {}
  pre_enemies = {}
  local new_pre_enemy = create_pre_enemy()
  deploy(new_pre_enemy, {"hero", "enemy", "pre-enemy"})
end

function _update()

  if btnp(5) then
    hero_a_active = not hero_a_active
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

function _draw()

  -- clear the screen
	cls()

  print("score: " ..score, 0, 0, 7)

	for x = 1, rows do
		for y = 1, cols do
			-- center the drawing based on the number of rows and cols
			local x_offset = (128 - 8 * rows) / 2 - 8
			local y_offset = (128 - 8 * cols) / 2 - 8
			local x_position = x * 8 + x_offset
			local y_position = y * 8 + y_offset
			-- draw a floor sprite
			spr("003", x_position, y_position)
			-- draw the sprite for anything at the current position
			if #board[x][y] > 0 then
				for next in all(board[x][y]) do
          local sprite = next.sprite
					spr(sprite, x_position, y_position)
          -- show health bar for things with health
          if (next.health) then
            for i = 1, next.health do
              pset(x_position + 7, y_position + i, 8)
            end
          end
				end
			end
		end
	end

  if game_over then
		local msg = "dead"
		local msg_x = 64 - (#msg * 4) / 2
		print(msg, msg_x, 62, 8)
	end
end

--[[
  helper functions
--]]

-- get the location of a thing
function find(thing)
	for x = 1, rows do
		for y = 1, cols do
			for next in all(board[x][y]) do
				if next == thing then
					local location = {}
					location.x = x
					location.y = y
					return location
				end
			end
		end
	end
end

-- get the col of a thing
function x(thing)
	for x = 1, rows do
		for y = 1, cols do
			local tile = board[x][y]
			for next in all(tile) do
				if next == thing then
					return x
				end
			end
		end
	end
end

-- get the row of a thing
function y(thing)
	for x = 1, rows do
		for y = 1, cols do
			local tile = board[x][y]
			for next in all(tile) do
				if next == thing then
					return y
				end
			end
		end
	end
end

-- returns a random tile from the board
function random_tile()
  -- create an array of all tiles
	local all_tiles = {}
	for x = 1, rows do
		for y = 1, cols do
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
	for x = 1, rows do
		for y = 1, cols do
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
  local x = tile[1]
  local y = tile[2]
  if
    x < 1 or
    x > cols or
    y < 1 or
    y > rows
  then
	  return false
	end
  return true
end

-- move a thing to a tile
function set_tile(thing, dest)

  local dest_x = dest[1]
  local dest_y = dest[2]

  -- do nothing if dest is off the board
	if location_exists(dest) == false then
	  return
	end

	-- remove it from its current tile
	for x = 1, rows do
		for y = 1, cols do
      local here = board[x][y]
      for next in all(here) do
        if next == thing then
          del(here, thing)
        end
      end
		end
	end

	-- add it to the dest tile
	add(board[dest_x][dest_y], thing)
end

-- deploys a thing to a random tile
-- avoid_list is a list of types. tiles with things of that type will be avoided.
function deploy(thing, avoid_list)

  local valid_tiles = {}

  for x = 1, rows do
		for y = 1, cols do
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

		type = "hero",
    base_sprite = 17,
    sprite = null,
    max_health = 4,
    health = 4,

    -- effects
    melee = false,
    shoot = false,

    -- update hero
		update = function(self)

      local self_x = x(self)
      local self_y = y(self)
      local self_tile = {self_x, self_y}

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
        -- local self_tile = {x(self), y(self)}
        local next_tile = {self_x + direction[1], self_y + direction[2]}
        if location_exists(next_tile) then
          shoot_target = get_shoot_target(direction)
          melee_target = get_melee_target(next_tile)
          if self.shoot and shoot_target then
            hit_enemy(shoot_target, 1)
          elseif self.melee and melee_target then
            hit_enemy(melee_target, 2)
          elseif melee_target then
            hit_enemy(melee_target, 1)
          else
            step(next_tile)
          end
        end
      end

      -- given a direction, this returns the nearest enemy in line of sight
      -- or `false` if there's not one
      function get_shoot_target(direction)

        local now_tile = self_tile
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

      -- given a direction, this returns an adjacent enemy to hit
      -- or `false` if there's not one
      function get_melee_target(next_tile)

        if is_wall_between(self_tile, next_tile) == false then
          local target = find_type_in_tile("enemy", next_tile)
          return target
        end
        return false
      end

      -- given an enemy and an amount of damage,
      -- hit it and then kill if it has no health
      function hit_enemy(enemy, damage)
        enemy_x = x(enemy)
        enemy_y = y(enemy)

        enemy.health -= damage

        if (enemy.health <= 0) then
          del(enemies, enemy)
          del(board[enemy_x][enemy_y], enemy)
        end
        end_turn()
      end

      -- updates the *other* hero's ability and sprite
      -- based on the effect tile that *this* hero is standing on
      function update_companion_effect()

        local here = {x(self), y(self)}

        -- -- find the other hero
        -- local companion
        -- if heroes[1] == self then
        --   companion = heroes[2]
        -- else
        --   companion = heroes[1]
        -- end

        -- set companion deets to their defaults
        companion.melee = false
        companion.shoot = false
        companion.base_sprite = sprites.hero

        -- check if this hero's tile is a effect tile
        local effect = find_type_in_tile("effect", here)
        if effect then
          if effect.name == "melee" or effect.name == "shoot" then
            -- apply the effect's effect to the companion hero
            companion[effect.name] = true
            companion.base_sprite = effect.hero_sprite
          end
        end
      end

      function update_potential_tiles()

        local companion_tile = {x(companion), y(companion)}
        local self_tile = {x(self), y(self)}
        self_potential_tile = find_type_in_tile("potential", self_tile)
        companion_potential_tile = find_type_in_tile("potential", companion_tile)

        if self_potential_tile and companion_potential_tile then

          local to_destroy = {self_potential_tile, companion_potential_tile}
          for next in all(to_destroy) do
            del(board[x(next)][y(next)], next)
          end

          for x = 1, rows do
            for y = 1, cols do
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

       -- moves the hero to an adjacent tile if there's not a wall in the way
      function step(next_tile)
        if is_wall_between(self_tile, next_tile) == false then
          set_tile(self, next_tile)
          update_potential_tiles()
          end_turn()
        end
      end

      -- does whatever needs to happen after a hero has done its thing
      function end_turn()
        update_companion_effect()
        for next in all(pre_enemies) do
          local current_x = x(next)
          local current_y = y(next)
          del(pre_enemies, next)
          del(board[current_x][current_y], next)
          local new_enemy = create_enemy({current_x, current_y})
          new_enemy.stunned = true
        end
        if turns > 0 and turns % 8 == 0 then
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
    type = "pre_enemy",
    sprite = sprites.pre_enemy
  }
  add(pre_enemies, pre_enemy)
  return pre_enemy
end

-- create an enemy and add it to the array of enemies
function create_enemy(tile)
	enemy = {
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

      local found_self = find(self)
			local self_x = found_self.x
			local self_y = found_self.y
      local self_tile = {self_x, self_y}

      local a = find(hero_a)
			local a_tile = {a.x, a.y}
			local a_dist = distance(self_tile, a_tile)

      local b = find(hero_b)
			local b_tile = {b.x, b.y}
			local b_dist = distance(self_tile, b_tile)

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
        local enemy_exists = find_type_in_tile("enemy", next) and true or false
        if
          distance(next, goal_tile) < current_dist and
          enemy_exists == false
        then
					add(valid_moves, next)
				end
      end

      -- if there are no valid moves based on the above criteria,
      -- then any adjacent tile that's not an enemy and doesn't have a wall in the way is valid
      if #valid_moves == 0 then
        local available_adjacent_tiles = {}
        for next in all(adjacent_tiles) do
          local enemy_exists = find_type_in_tile("enemy", next) and true or false
          if enemy_exists == false then
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
        -- local target_exists = target and true or false
        if target then
          if target.health > 0 then
            target.health -= 1
          end
        else
          set_tile(self, dest)
          local effect = find_type_in_tile("effect", dest)
          if effect then
            if effect.name == "health" then
              health_effect()
            end
            if effect.name == "score" then
              score_effect()
            end
          end
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
	for x = 1, rows do
		distance_map[x] = {}
		for y = 1, cols do
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

  for x = 1, rows do
		for y = 1, cols do
      local here = board[x][y]

      local wall_right = find_type_in_tile("wall_right", {x,y})
      local wall_right_exists = wall_right and true or false

      local wall_down = find_type_in_tile("wall_down", {x,y})
      local wall_down_exists = wall_down and true or false

      if wall_right_exists then
        del(here, wall_right)
      end
      if wall_down_exists then
        del(here, wall_down)
      end
    end
  end
end

function generate_walls()

  for i = 1, 16 do
    local wall_right = {
      type = "wall_right",
      sprite = sprites.wall_right
    }
    local wall_down = {
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
	for x = 1, rows do
		reached_map[x] = {}
		for y = 1, cols do
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
  for x = 1, rows do
		for y = 1, cols do
      if reached_map[x][y] == false then
        return false
      end
    end
  end

  return true
end

function generate_potential_tiles()

  local current_types = {
    "melee",
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
    deploy(tile, {"potential", "effect"})
  end
end

__gfx__
00000000000000000000000066666666000000000000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777777066666666077777700000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000757577066666666070000700000000d00000000000220000003300000088000000aa0000000000000000000000000000000000000000000
00000000000000000757577066666666070000700000000d0000000000200200003003000080080000a00a000000000000000000000000000000000000000000
00000000000000000777777066666666077007700000000d0000000000200200003003000080080000a00a000000000000000000000000000000000000000000
00000000000000000075570066666666007007000000000d00000000000220000003300000088000000aa0000000000000000000000000000000000000000000
00000000000000000077770066666666007777000000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000666666660000000000000000ddddddd0000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000005500000000000000220000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000550000005500000022000000220000003300000033000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000550000000000000022000000000000003300000000000000220000003300000088000000aa0000000000000000000000000000000000000000000
0000000000000000055555500000000002222220000000000333333000222200003333000088880000aaaa000000000000000000000000000000000000000000
0000000005555550000550000222222000022000033333300003300000222200003333000088880000aaaa000000000000000000000000000000000000000000
00000000000550000005500000022000000220000003300000033000000220000003300000088000000aa0000000000000000000000000000000000000000000
00000000005555000050050000222200002002000033330000300300000000000000000000000000000000000000000000000000000000000000000000000000
00000000005005000050050000200200002002000030030000300300000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
