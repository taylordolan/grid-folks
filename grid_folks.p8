pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- grid folks
-- taylor d

-- todo
-- [x] prevent the player from stepping off the edge of the board
-- [x] add walls
-- [x] make a sprite dictionary
-- [x] prevent the player from stepping into walls
-- [x] prevent enemies from moving the the player attempts an invalid move
-- [x] add and render health for the player
-- [x] implement bump hits for enemies
-- [x] implement bump hits for player
-- [x] make enemies avoid other enemies
-- [ ] make a `thing` class that other things inherit from
-- [ ] clean up player movement
-- [ ] clean up enemy movement
-- [ ] use objects instead of arrays for locations?
-- [ ] move enemies randomly if there are no valid moves
-- [ ] prevent wall generation from creating closed areas

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
	game_over = false

	-- player object
	player = {
		type = "player",
    health = 3,
		update = function(self)
      local location = find(player)
      local self_x = location.x
      local self_y = location.y
      -- move up
			if btnp(⬆️) then
        local up = {self_x, self_y - 1}
        if
          location_exists(up) and
          find_type_in_tile("wall", up) == false
        then
          attempt_player_move(up)
          foreach(enemies, enemy.step)
        end
      end
      -- move down
			if btnp(⬇️) then
        local down = {self_x, self_y + 1}
        if
          location_exists(down) and
          find_type_in_tile("wall", down) == false
        then
          attempt_player_move(down)
          foreach(enemies, enemy.step)
        end
      end
      -- move left
			if btnp(⬅️) then
        local left = {self_x - 1, self_y}
        if
          location_exists(left) and
          find_type_in_tile("wall", left) == false
        then
          attempt_player_move(left)
          foreach(enemies, enemy.step)
        end
      end
      -- move right
			if btnp(➡️) then
        local right = {self_x + 1, self_y}
        if
          location_exists(right) and
          find_type_in_tile("wall", right) == false
        then
          attempt_player_move(right)
          foreach(enemies, enemy.step)
        end
      end
		end
	}

  -- sprite dictionary
  sprites = {
    player = "001",
    enemy = "002",
    floor = "003",
    wall = "004",
  }

  -- create some walls
  for i = 1, 5 do
    local wall = {
      type = "wall"
    }
    deploy(wall)
  end

	-- list of enemies
	enemies = {}
	create_enemy()
  create_enemy()

	-- initial player position
	deploy(player)

	-- initial enemy position
	foreach(enemies, deploy)
end

function _update()

	-- move player and enemies
	player:update()

  -- game end test
  if player.health == 0 then
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
			spr(sprites.floor, x_position, y_position)
			-- draw the sprite for anything at the current position
			if #board[x][y] > 0 then
				for next in all(board[x][y]) do
          local sprite = sprites[next.type]
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

function attempt_player_move(tile)
  local index = find_type_in_tile("enemy", tile)
  local x = tile[1]
  local y = tile[2]
  if index != false then
    board[x][y][index].hit(board[x][y][index])
  else
    set_tile(player, tile)
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

-- returns an empty tile
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
			if board[x][y][1] == thing then
				del(board[x][y], thing)
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

--[[
  enemy stuff
--]]

-- create an enemy and add it to the array of enemies
function create_enemy()
	enemy = {
    type = "enemy",
    step = function(self)
      local found_self = find(self)
			local self_x = found_self.x
			local self_y = found_self.y
      local self_tile = {self_x, self_y}

      local found_player = find(player)
			local goal_tile = {found_player.x, found_player.y}

			local distance_map = create_distance_map(goal_tile)
			local current_dist = distance(distance_map, self_tile)
			local closer_tiles = {}

      local up = {self_x, self_y - 1}
      local down = {self_x, self_y + 1}
      local left = {self_x - 1, self_y}
      local right = {self_x + 1, self_y}

			-- check if up is closer
			if self_y != 1 then
				if
          distance(distance_map, up) < current_dist and
          find_type_in_tile("enemy", up) == false
        then
					add(closer_tiles, up)
				end
			end
			-- check if down is closer
			if self_y != rows then
				if
          distance(distance_map, down) < current_dist and
          find_type_in_tile("enemy", down) == false
        then
					add(closer_tiles, down)
				end
			end
			-- check if left is closer
			if self_x != 1 then
				if
          distance(distance_map, left) < current_dist and
          find_type_in_tile("enemy", left) == false
        then
					add(closer_tiles, left)
				end
			end
			-- check if right is closer
			if self_x != cols then
				if
          distance(distance_map, right) < current_dist and
          find_type_in_tile("enemy", right) == false
        then
					add(closer_tiles, right)
				end
			end

      local valid_moves = closer_tiles

      -- if there are no available options, move randomly
      if #closer_tiles == 0 then

        local empty_adjacent_tiles = {}

        -- check if up is closer
        if self_y != 1 then
          if
            find_type_in_tile("enemy", up) == false and
            find_type_in_tile("wall", up) == false
          then
            add(empty_adjacent_tiles, up)
          end
        end
        -- check if down is closer
        if self_y != rows then
          if
            find_type_in_tile("enemy", down) == false and
            find_type_in_tile("wall", down) == false
          then
            add(empty_adjacent_tiles, down)
          end
        end
        -- check if left is closer
        if self_x != 1 then
          if
            find_type_in_tile("enemy", left) == false and
            find_type_in_tile("wall", left) == false
          then
            add(empty_adjacent_tiles, left)
          end
        end
        -- check if right is closer
        if self_x != cols then
          if
            find_type_in_tile("enemy", right) == false and
            find_type_in_tile("wall", right) == false
          then
            add(empty_adjacent_tiles, right)
          end
        end

        printh(#empty_adjacent_tiles)
        valid_moves = empty_adjacent_tiles
      end

			-- hit the player, or pick a closer tile and move to it
			index = flr(rnd(#valid_moves)) + 1
			selected_tile = valid_moves[index]
      if find_type_in_tile("player", selected_tile) != false then
        player.health -= 1
      else set_tile(self, selected_tile)
      end
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

-- creates a map where the value at [x][y] is the distance from that position to the goal
function create_distance_map(goal)
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

	while #frontier > 0 do
		for i = 1, #frontier do
			local tile_x = frontier[i][1]
			local tile_y = frontier[i][2]
			distance_map[tile_x][tile_y] = steps

			-- check up tile, if it exists
			if tile_y != 1 then
				local up = {tile_x, tile_y - 1}
				-- if the distance hasn't been set, then the tile hasn't been reached yet
				if distance_map[up[1]][up[2]] == 1000 then
					if (
            is_in_tile_array(next_frontier, up) == false and
            find_type_in_tile("wall", up) == false
          ) then
						add(next_frontier, up)
					end
				end
			end
			-- check down tile, if it exists
			if tile_y != rows then
				local down = {tile_x, tile_y + 1}
				if distance_map[down[1]][down[2]] == 1000 then
					-- make sure it wasn't already added by a different check in the same step
					if (
            is_in_tile_array(next_frontier, down) == false and
            find_type_in_tile("wall", down) == false
          ) then
						add(next_frontier, down)
					end
				end
			end
			-- check left tile, if it exists
			if tile_x != 1 then
				local left = {tile_x - 1, tile_y}
				if distance_map[left[1]][left[2]] == 1000 then
					if (
            is_in_tile_array(next_frontier, left) == false and
            find_type_in_tile("wall", left) == false
          ) then
						add(next_frontier, left)
					end
				end
			end
			-- check right tile, if it exists
			if tile_x != cols then
				local right = {tile_x + 1, tile_y}
				if distance_map[right[1]][right[2]] == 1000 then
					if (
            is_in_tile_array(next_frontier, right) == false and
            find_type_in_tile("wall", right) == false
          ) then
						add(next_frontier, right)
					end
				end
			end
		end
		steps += 1
		frontier = next_frontier
		next_frontier = {}
	end
	return distance_map
end

function distance(distance_map, tile)
	return distance_map[tile[1]][tile[2]]
end

__gfx__
000000000070070000077000dddddddd0ffffff033440003ffffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000077770000777700ddddddddff4f444f43488333ffffffff000000000000000000000000000000000000000000000000000000000000000000000000
0000000000766700007b7700ddddddddffffffff84444404ffffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000627726066666666ddddddddf4f4ffff44484484ffffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000627726000000000ddddddddf4ffffff44044448ffffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000622226000077000ddddddddffffff0f88444844ffffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000020020000000000ddddddddff0fffff44834443ffffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000020020000777700dddddddd0fff0ff033333343ffffffff000000000000000000000000000000000000000000000000000000000000000000000000
__label__
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000ddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddd7777dddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddd7b77dddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddd66666666dddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000ddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddd7777dddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddd7dd7dddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddd7777dddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddd7667dddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000ddddddddddddddddddddddddddddddddddddddddddd627726ddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000ddddddddddddddddddddddddddddddddddddddddddd627726ddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000ddddddddddddddddddddddddddddddddddddddddddd622226ddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddd2dd2dddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddd2dd2dddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
00010000000001c05023030180501e0602106024060270701e0702807028070280702704024070210701d0701a07018070170701605016070180701a070230703107023170241702417027170000700007000070
