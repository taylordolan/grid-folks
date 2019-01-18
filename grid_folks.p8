pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

-- todo
-- [x] walls between tiles
-- [ ] prevent wall generation from creating closed areas
-- [ ] health for enemies
-- [ ] power tiles for melee damage
-- [ ] use objects instead of arrays for locations

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

  -- sprite dictionary
  -- sprites = {
  --   -- hero = "001",
  --   -- enemy = "002",
  --   -- floor = "003",
  --   -- wall = "004",
  -- }

  -- create some walls
  for i = 1, 5 do
    local wall_right = {
      type = "wall_right",
      sprite = "005"
    }
    local wall_down = {
      type = "wall_down",
      sprite = "006"
    }
    deploy(wall_right)
    deploy(wall_down)
  end

  -- heroes
  hero_a = create_hero()
  hero_b = create_hero()
  deploy(hero_a)
  deploy(hero_b)

	-- list of enemies
	enemies = {}
	create_enemy()
  create_enemy()

	-- initial enemy position
	foreach(enemies, deploy)
end

function _update()

	-- move heroes
  if (btn(5)) then
    hero_a.sprite = "001"
    hero_b.sprite = "017"
    hero_a:update()
  else
    hero_a.sprite = "017"
    hero_b.sprite = "001"
    hero_b:update()
  end

  -- move enemies
  if player_turn == false then
    foreach(enemies, enemy.update)
  end

  -- game end test
  if hero_a.health == 0 or hero_b.health == 0 then
    game_over = true
  end
end

function _draw()

  -- clear the screen
	cls()

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
            for i = 0, next.health - 1 do
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

-- put a thing at a random empty tile
function deploy(thing)
	dest = random_empty_tile()
	set_tile(thing, dest)
end

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
    -- todo can I throw an error here?
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
      return i
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
    sprite = "001",
    health = 2,
    expected_modifier_value = 0,
		update = function(self)
      local location = find(self)
      local self_x = location.x
      local self_y = location.y

      -- move up
			if btnp(⬆️) then
        local dest = {self_x, self_y - 1}
        attempt_hero_move(dest)
      end
      -- move down
			if btnp(⬇️) then
        local dest = {self_x, self_y + 1}
        attempt_hero_move(dest)
      end
      -- move left
			if btnp(⬅️) then
        local dest = {self_x - 1, self_y}
        attempt_hero_move(dest)
      end
      -- move right
			if btnp(➡️) then
        local dest = {self_x + 1, self_y}
        attempt_hero_move(dest)
      end

      function attempt_hero_move(dest)
        local x = dest[1]
        local y = dest[2]
        if
          location_exists(dest) and
          find_type_in_tile("wall", dest) == false
        then
          local index = find_type_in_tile("enemy", dest)
          if index != false then
            -- todo: clean this up
            board[x][y][index].hit(board[x][y][index])
          else
            set_tile(self, dest)
          end
          player_turn = false
        end
      end
		end
	}
  return hero
end

--[[
  enemy stuff
--]]

-- create an enemy and add it to the array of enemies
function create_enemy()
	enemy = {
    type = "enemy",
    sprite = "002",
    update = function(self)
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
        if
          distance(next, goal_tile) < current_dist and
          find_type_in_tile("enemy", next) == false
        then
					add(valid_moves, next)
				end
      end

      -- if there are no valid moves based on the above criteria,
      -- then any adjacent tile that's not an enemy and doesn't have a wall in the way is valid
      if #valid_moves == 0 then

        local available_adjacent_tiles = {}
        for next in all(adjacent_tiles) do
          if
            find_type_in_tile("enemy", next) == false
          then
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
        local hero_in_dest = find_type_in_tile("hero", dest)
        if hero_in_dest != false then
          local target = board[dest[1]][dest[2]][hero_in_dest]
          target.health -= 1
        else
          set_tile(self, dest)
        end
      end
      player_turn = true
		end,
    hit = function(self)
      local self_x = x(self)
			local self_y = y(self)
      del(enemies, self)
      del(board[self_x][self_y], self)
    end
	}
	add(enemies, enemy)
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

__gfx__
00000000000550000000000066666666dddddddd0000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000550000777777066666666dddddddd0000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000757577066666666dddddddd0000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000055555500757577066666666dddddddd0000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000550000777777066666666dddddddd0000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000550000075570066666666dddddddd0000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005005000077770066666666dddddddd0000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005005000000000066666666dddddddd00000000ddddddd0000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000055555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
