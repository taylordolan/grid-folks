pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- grid folks
-- taylor d

-- todo
-- [ ] balance enemy spawn rate

-- optimizations
-- [x] eliminate the colors dictionary
-- [x] instead of rendering the contents of each tile, render the contents of each list of objects
-- [x] have objects keep track of their lists so they can remove themselves from their lists
-- [x] make a generic `thing` object and a generic `actor` object
-- [ ] refactor shot drawing as an effect
-- [ ] find a way to reduce the token count of long animations
-- [ ] simplify input conditions
-- [ ] combine functions for creating wall_right and wall_down
-- [ ] kill the sprites dictionary

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
		red = 8,
		orange = 9,
		green = 11,
		blue = 12,
	}

	-- todo: remove this and add shots to effects{}
	shot_points = {} -- expects two {x,y} points for the beginning and end of a shot
	shot_direction = {} -- which direction the shot was fired in, e.g. {0, -1} for up
	remaining_shot_frames = 0 -- for how many frames should the current shot be drawn?

	-- sounds dictionary
	sounds = {
		music = 002,
		health = 026, -- when gaining health
		shoot = 029,
		jump = 025,
		step = 021,
		pad_step = 028, -- when stepping on a [ ] thing
		score = 022, -- when gaining gold
		advance = 027, -- when creating a new button
		switch_heroes = 000,
		enemy_bump = 000, -- when an enemy hits a hero
		hero_bump = 000, -- when a hero hits an enemy
		win = 000,
		lose = 000,
	}

	-- sprites dictionary
	sprites = {
		hero_inactive = 000,
		hero_active = 001,
		enemy_1 = 048,
		enemy_2 = 049,
		enemy_3 = 050,
		crosshair = 002,
		pad = 016,
		button_1 = 017,
		button_2 = 018,
		button_3 = 019,
		exit = 020,
		border_left = 032,
		border_top = 033,
		border_top_left = 034,
		border_top_right = 035,
		die_1 = 051,
		die_2 = 052,
		arrow_right = 003,
		arrow_down = 004,
	}

	-- some game state
	score = 0
	turns = 0
	player_turn = true
	debug_mode = false
	delay = 0
	has_advanced = false
	turn_score_gain = 0
	turn_health_gain = 0
  depth = 32
  mode = "title"

	-- lists of `things`
	heroes = {}
	enemies = {}
	pads = {}
	buttons = {}
	-- other lists
	exits = {}
	effects = {}
  walls = {}
	colors_bag = {}

	-- log of recent user input
	input_queue = {}

	-- initial buttons (for testing)
	-- set_tile(new_button(008), {4,2})
	-- set_tile(new_button(009), {4,4})
	-- set_tile(new_button(011), {5,3})
	-- set_tile(new_button(012), {3,3})

	-- heroes
	hero_a = new_hero()
	hero_b = new_hero()
	hero_a.active = true
	set_tile(hero_a, {3,3})
	set_tile(hero_b, {5,3})

	-- initial walls
	refresh_walls()
	for next in all({{2,3},{3,3},{4,3},{5,3}}) do
		local wall = find_type_in_tile("wall_right", next)
		if wall then
			wall:destroy()
		end
	end

	-- initial pads
	local initial_pad_tiles = {{2,3}, {4,3}, {6,3}}
	for next in all({008, 011, 012}) do
		local _i = flr(rnd(#initial_pad_tiles)) + 1
		set_tile(new_pad(next), initial_pad_tiles[_i])
		del(initial_pad_tiles, initial_pad_tiles[_i])
	end
	for next in all({{2,3}, {3,3}, {4,3}, {5,3}}) do
		local wall = find_type_in_tile("wall_right", next)
		if wall then
			del(board[next[1]][next[2]], wall)
		end
	end

	-- initial enemy
	spawn_enemy()

	-- spawn rate stuff
	spawn_rates = {
		[1] = 16,
		[30] = 14,
		[60] = 12,
		[90] = 10,
    [120] = 8,
		[150] = 6,
		[180] = 5,
		[210] = 4,
		[240] = 3,
		[300] = 2,
		[360] = 1,
	}
  spawn_turns = {0,0,0}
	spawn_rate = spawn_rates[1]
	-- this gets updated whenever an enemy spawns
	last_spawned_turn = 0
	-- this tracks whether we've spawned a turn early
	spawned_early = false

	-- start the music!
	music(sounds.music)
end

function _update60()

	if btnp(4) then
		debug_mode = not debug_mode
	end

	if mode == "title" and btnp(5) then
		mode = "game"
		return
	elseif mode == "game" and is_game_over() then
		if btnp(5) then
			_init()
			mode = "game"
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
			depth -= 1
			new_num_effect({26 + #(depth .. "") * 4,99}, -1, 007, 000)
		end
		shuffle(enemies)
		for next in all(enemies) do
			next.update(next)
		end
		update_spawn_turns()
		if turns > 0 then
			for i = 1, spawn_turns[turns] do
				if #enemies < 33 then
					spawn_enemy()
				end
			end
		end
		trigger_all_enemy_buttons()
		turn_health_gain = 0
		turn_score_gain = 0
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
			update_hero_abilities()
			score += 100
			depth -= 1
			sfx(sounds.win, 3)
		end
		-- game lost test
		if hero_a.health <= 0 or hero_b.health <= 0 then
			sfx(sounds.lose, 3)
		end
	end
end

function _draw()
	cls()

	-- title screen
	if mode == "title" then
		pal(005, 000)
		pal(001, 005)
		spr(008,34,36,8,4)
		local _text = smallcaps("press x to start")
		print(_text, 65 - #_text * 4 / 2, 99, 007)
		return
	end

	local board_origin = {11,11}
	local board_opposite = {116,86}

	-- draw_floor
	rectfill(board_origin[1], board_origin[2], board_opposite[1], board_opposite[2], 007)

	-- draw outlines
	-- this draws 1px inside and 1px outside the "rim" that gets drawn by the border tiles.
	-- this creates the appearance of walls around the floor of the board.
	rect(board_origin[1] - 1, board_origin[2] - 1, board_opposite[1] + 1, board_opposite[2] + 1, 000)
	rect(board_origin[1] + 1, board_origin[2] + 1, board_opposite[1] - 1, board_opposite[2] - 1, 000)

	-- draw objects
	for list in all({
		-- things at the bottom appear on top
		pads,
		exits,
		buttons,
		walls,
		enemies,
		heroes,
		effects,
	}) do
		for next in all(list) do
			next:draw()
		end
	end

	-- draw border
	pal(007, 007)
	pal(006, 007)
	-- top and bottom
	for x = 12, 115, 8 do
		spr(sprites.border_top, x, 4, 1, 1, false, false)
		spr(sprites.border_top, x, 86, 1, 1, true, true)
	end
	-- left and right
	for y = 13, 84, 8 do
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

	-- draw shot
	if #shot_points > 0 then
		local a = shot_points[1]
		local b = shot_points[2]
		local dir = shot_direction
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
		rectfill(ax, ay, bx, by, 011)
		remaining_shot_frames -= 1
		if remaining_shot_frames <= 0 then
			shot_points = {}
			shot_direction = {}
		end
	end

	if is_game_over() then
		-- draw game over state
		local msg
		local msg_x
		local msg_y
		-- line 1
		if depth != 0 then
			msg = smallcaps("you died with " .. score .. " gold")
		else
			msg = smallcaps("you escaped! +100 gold")
		end
		local msg_x = 65 - (#msg * 4) / 2
		local msg_y = 99
		print(msg, msg_x, msg_y, 007)
		-- line 2
		if depth != 0 then
			local txt = depth == 1 and " depth" or " depths"
			msg = smallcaps(depth .. txt .. " from the surface")
		else
			msg = smallcaps("final score: " .. score)
		end
		msg_x = 65 - (#msg * 4) / 2
		msg_y += 10
		print(msg, msg_x, msg_y, 007)
		-- line 3
		if debug_mode then
			msg = smallcaps("turns: " .. turns ..", spawn rate: " .. spawn_rate)
		else
			msg = smallcaps("press x to restart")
		end
		msg_x = 65 - (#msg * 4) / 2
		msg_y += 10
		print(msg, msg_x, msg_y, 005)
	elseif not has_advanced then
		-- draw intro
		pal(015, false)
		pal(006, 007)
		local _x = 22
		local _y = 99
		local _space = 3
		local _a = smallcaps("press x to switch")
		print(_a, _x, _y, 007)
		spr(sprites.hero_inactive, _x + #_a * 4 + _space, _y - 2)
		spr(sprites.hero_active, _x + #_a * 4 + 8 + _space, _y - 2)

		_x = 18
		_y += 10
		local _b = smallcaps("stand on 2")
		print(_b, _x, _y, 007)
		spr(sprites.pad, _x + #_b * 4 + _space, _y - 2)
		local _c = smallcaps("to advance")
		print(_c, _x + #_b * 4 + _space + 8 + _space, _y, 007)
		return
		pal()
	else
		-- draw instructions area
		if not debug_mode then
			local msg = smallcaps("depth")
			print(msg, 11, 99, 007)
			print(depth, 34, 99, 007)
		else
			local text = turns .."/"..spawn_rate
			print(text, 11, 99, 005)
		end
		-- score
		local text = smallcaps("gold")
		local num = score .. ""
		print(text, 118 - #text * 4, 99, 007)
		print(num, 99 - #num * 4, 99, 007)
		-- instructions
		spr(064, 11, 108, 7, 2)
		spr(071, 79, 108, 5, 2)
	end
	for next in all(effects) do
		next:draw()
	end

	-- grid
	-- local _g = 8
	-- for _x = 0, 127, _g do
	--   for _y = 0, 127, _g do
	--     pset(_x, _y, 014)
	--   end
	-- end
	-- for _x = 0, 127, _g do
	--   pset(_x, 127, 014)
	-- end
	-- for _y = 0, 127, _g do
	--   pset(127, _y, 014)
	-- end
	-- pset(127, 127, 014)
end

function new_thing()
	local new_thing = {
		x = null,
		y = null,
		-- a sequence of screen positions
		screen_seq = {},
		-- a sequence of sprites
		sprite_seq = {},
		-- a sequence of palette modifications
		pal_seq = {{10,10}},
		end_draw = function(self)
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
		destroy = function(self)
			del(board[self.x][self.y], self)
			del(self.list, self)
		end,
	}
	return new_thing
end

function new_hero()
	local new_hero = new_thing()

	new_hero.sprite_seq = {sprites.hero_inactive}
	new_hero.type = "hero"
	new_hero.max_health = 3
	new_hero.health = 3
	new_hero.active = false
	new_hero.jump = false
	new_hero.shoot = false
	new_hero.list = heroes

	new_hero.act = function(self, direction)

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

			-- if jump is enabled and there's a wall in the way
			if self.jump and wall or self.jump and enemy then
				if enemy then
					hit_enemy(enemy, 2)
					player_turn = false
				end
				local _here = tile_to_screen({self.x, self.y})
				local _next = tile_to_screen(next_tile)
				local _half = {(_here[1] + _next[1]) / 2, _here[2]-4}
				set_tile(self, next_tile)
				transition_to(self, {_half, _next}, 2, 0)
				delay += 4
				sfx(sounds.jump, 3)
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
					remaining_shot_frames = 4
					sfx(sounds.shoot, 3)

					delay += 4
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
					delay += 4
					player_turn = false
				end
			end
		end
	end

	new_hero.draw = function(self)

		-- set sprite based on the first value in sprite_seq
		local sprite = self.sprite_seq[1]
		-- if the sprite is hero_inactive and this hero is active, update the sprite
		if sprite == sprites.hero_inactive and self.active then
			sprite = sprites.hero_active
		end

		-- set the current screen destination using the first value in screen_seq
		local sx = self.screen_seq[1][1]
		local sy = self.screen_seq[1][2]
		local ax = tile_to_screen({self.x, self.y})[1]
		local ay = tile_to_screen({self.x, self.y})[2]

		-- default palette updates
		palt(015, true)
		palt(000, false)
		if self.shoot then
			pal(007, 011)
			pal(006, 011)
			pal(010, 007)
			if self.active then
				for next in all({{-1,0},{1,0},{0,-1},{0,1}}) do
					local _a = {self.x, self.y}
					local _b = {self.x + next[1], self.y + next[2]}
					local sprite = next[2] == 0 and sprites.arrow_right or sprites.arrow_down
					local flip_x
					local flip_y
					if next[1] == -1 then
						flip_x = true
					elseif next[2] == -1 then
						flip_y = true
					end
					if #get_shoot_targets(self, next) > 0 then
						spr(sprite, ax + next[1] * 8, ay + next[2] * 8, 1, 1, flip_x, flip_y)
					end
				end
			end
		elseif self.jump then
			pal(007, 012)
			pal(006, 012)
			pal(010, 007)
			if self.active then
				for next in all({{-1,0},{1,0},{0,-1},{0,1}}) do
					local _a = {self.x, self.y}
					local _b = {self.x + next[1], self.y + next[2]}
					local sprite = next[2] == 0 and sprites.arrow_right or sprites.arrow_down
					local flip_x
					local flip_y
					if next[1] == -1 then
						flip_x = true
					elseif next[2] == -1 then
						flip_y = true
					end
					if
						find_type_in_tile("enemy", _b) or
						location_exists(_b) and is_wall_between(_a, _b) and not find_type_in_tile("hero", _b)
					then
						spr(sprite, ax + next[1] * 8, ay + next[2] * 8, 1, 1, flip_x, flip_y)
					end
				end
			end
		else
			pal(010, 007)
			if self.active then
				for next in all({{-1,0},{1,0},{0,-1},{0,1}}) do
					local _a = {self.x, self.y}
					local _b = {self.x + next[1], self.y + next[2]}
					local sprite = next[2] == 0 and sprites.arrow_right or sprites.arrow_down
					local flip_x
					local flip_y
					if next[1] == -1 then
						flip_x = true
					elseif next[2] == -1 then
						flip_y = true
					end
					if not is_wall_between(_a, _b) and find_type_in_tile("enemy", _b) then
						spr(sprite, ax + next[1] * 8, ay + next[2] * 8, 1, 1, flip_x, flip_y)
					end
				end
			end
		end

		-- update the palette based using first value in pal_seq
		pal(self.pal_seq[1][1], self.pal_seq[1][2])

		-- draw the sprite and the hero's health
		spr(sprite, sx, sy)
		draw_health(sx, sy, self.health, 8)

		self:end_draw()
	end

	add(heroes, new_hero)
	return new_hero
end

function new_enemy()
	local new_enemy = new_thing()

	new_enemy.sprite_seq = {sprites.enemy_3}
	new_enemy.type = "enemy"
	new_enemy.stunned = true
	new_enemy.health = 2
	new_enemy.list = enemies

	new_enemy.update = function(self)

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
					local b_r = {000, 008}
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
	end

	new_enemy.draw = function(self)

		-- set sprite based on the first value in sprite_seq
		local sprite = self.sprite_seq[1]

		-- set the current screen destination using the first value in screen_seq
		local sx = self.screen_seq[1][1]
		local sy = self.screen_seq[1][2]

		-- default palette updates
		palt(015, true)
		palt(000, false)
		if self.stunned then
			pal(000, 006)
		end

		-- update the palette based using first value in pal_seq
		pal(self.pal_seq[1][1], self.pal_seq[1][2])

		-- draw the enemy and its health
		spr(sprite, sx, sy)
		draw_health(sx, sy, self.health, 7)

		-- draw crosshairs
		if self.health >= 1 then
			if self.is_shoot_target then
				pal(006, 011)
				spr(sprites.crosshair, sx, sy)
			end
			if self.is_jump_target then
				pal(006, 012)
				spr(sprites.crosshair, sx, sy)
			end
		end

		self.end_draw(self)
	end

	new_enemy.deploy = function(self)

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

	add(enemies, new_enemy)
	return new_enemy
end

function draw_health(x_pos, y_pos, amount, offset)
	for i = 1, amount do
		pset(x_pos + offset, y_pos + 10 - i * 3, 008)
		pset(x_pos + offset, y_pos + 9 - i * 3, 008)
	end
end

function update_spawn_turns()
  spawn_turns[turns + 2] = 0
	-- if the spawn rate has been reached this turn
	if turns - last_spawned_turn >= spawn_rate then
    -- 50% chance to spawn next turn instead
		if flr(rnd(2)) == 1 then
      spawn_turns[turns + 1] += 1
    else
      spawn_turns[turns] += 1
		end
    last_spawned_turn = turns
	end
end

function spawn_enemy()
	local new_enemy = new_enemy()
	new_enemy.deploy(new_enemy)
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

function is_game_over()
  return depth == 0 or hero_a.health <= 0 or hero_b.health <= 0
end

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
		local _c = tile_to_screen(dest)
		if thing.type == "enemy" then
			local _x = _c[1]
			local _y = _c[2]
			local _a = {_x,_y-2}
			local _b = {_x,_y-1}
			thing.screen_seq = {_a,_a,_a,_a,_b,_b,_b,_b,_c}
		else
			thing.screen_seq = {_c}
		end
	end

	-- this is here for now because enemy buttons need to be triggered when enemies step or are deployed
	-- todo: this should probably be done differently somehow
	if thing.type == "enemy" then
		local button = find_type_in_tile("button", {thing.x, thing.y})
		if button and button.color == "red" then
			turn_health_gain += 1
		elseif button and button.color == "orange" then
			turn_score_gain += 1
		end
	end

	if thing.type == "hero" and find_type_in_tile("pad", dest) then
		if find_type_in_tile("pad", dest) then
			sfx(sounds.pad_step, 3)
		else
			sfx(sounds.step, 3)
		end
	end
end

function tile_to_screen(board_position)
	local board_x = board_position[1]
	local board_y = board_position[2]
	local x_pos = (board_x - 1) * 8 + (board_x - 1) * 7 + 15
	local y_pos = (board_y - 1) * 8 + (board_y - 1) * 7 + 15
	return {x_pos, y_pos}
end

function shuffle(t)
	-- do a fisher-yates shuffle
	for i = #t, 1, -1 do
		local j = flr(rnd(i)) + 1
		t[i], t[j] = t[j], t[i]
	end
end

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

function trigger_all_enemy_buttons()
	for next in all(heroes) do
		local start = next.health
		next.health += turn_health_gain
		if next.health > next.max_health then
			next.health = next.max_health
		end
		local diff = next.health - start
		if diff > 0 then
			new_num_effect({next.screen_seq[1][1], next.screen_seq[1][2]}, diff, 008, 007)
			sfx(sounds.health, 3)
		end
	end
	if turn_score_gain > 0 then
		score += turn_score_gain
		local text = turn_score_gain .. ""
		sfx(sounds.score, 3)
		new_num_effect({95 - #text * 4, 99}, turn_score_gain, 009, 000)
	end
end

function new_num_effect(pos, amount, color, outline)
	local _x = pos[1]
	local _y = pos[2]
	local new_num_effect = {
		screen_seq = {
			{_x,_y},
			{_x,_y},
			{_x,_y},
			{_x,_y},
			{_x,_y-1},
			{_x,_y-1},
			{_x,_y-1},
			{_x,_y-1},
			{_x,_y-2},
			{_x,_y-2},
			{_x,_y-2},
			{_x,_y-2},
      {_x,_y-3},
			{_x,_y-3},
			{_x,_y-3},
			{_x,_y-3},
      {_x,_y-4},
			{_x,_y-4},
			{_x,_y-4},
			{_x,_y-4},
      {_x,_y-5},
			{_x,_y-5},
			{_x,_y-5},
			{_x,_y-5},
		},
		draw = function(self)
			local sx = self.screen_seq[1][1]
			local sy = self.screen_seq[1][2]
      local sign = amount > 0 and "+" or ""
			for next in all({{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{-1,1},{1,-1},{1,1}}) do
				print(sign .. amount, sx+next[1], sy+next[2], outline)
			end
			print(sign .. amount, sx, sy, color)
			if #self.screen_seq > 1 then
				del(self.screen_seq, self.screen_seq[1])
			else
				del(effects, self)
			end
			-- reset the palette
			pal()
		end,
	}
	add(effects, new_num_effect)
	return new_num_effect
end

function new_pop(pos)
	local _a = sprites.die_1
	local _b = sprites.die_2
	local new_pop = {
		s = pos,
		sprite_seq = {
			_a,_a,_a,_a,_b,_b,_b,_b,
		},
		draw = function(self)
			palt(015, true)
			local sprite = self.sprite_seq[1]
			spr(sprite, self.s[1], self.s[2])
			if #self.sprite_seq > 1 then
				del(self.sprite_seq, self.sprite_seq[1])
			end

			if #self.sprite_seq <= 1 then
				del(effects, self)
			end
			pal()
		end
	}
	add(effects, new_pop)
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
		next.is_jump_target = false
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
		if h.jump and h.active then
			local h_tile = {h.x, h.y}
			for d in all({{0, -1}, {0, 1}, {-1, 0}, {1, 0}}) do
				local enemy = find_type_in_tile("enemy", {h_tile[1] + d[1], h_tile[2] + d[2]})
				if enemy then
					enemy.is_jump_target = true
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
		next.jump = false
		next.shoot = false

		-- if the ally's tile is a button, update the hero's deets
		local button = find_type_in_tile("button", ally_xy)
		if button then
			if button.color == 012 then
				next.jump = true
			elseif button.color == 011 then
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
		new_pop({_x,_y})
		enemy:destroy()
	else
		local b_r = {000, 008}
		enemy.pal_seq = {
			b_r,b_r,b_r,b_r,{010,010},
		}
	end
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
  for next in all(walls) do
    del(board[next.x][next.y], next)
    del(walls, next)
  end
  walls = {}
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
				local x_pos = (self.x - 1) * 8 + (self.x - 1) * 7 + 15
				local y_pos = (self.y - 1) * 8 + (self.y - 1) * 7 + 15

				local hero_l = find_type_in_tile("hero", {self.x, self.y})
				local hero_r = find_type_in_tile("hero", {self.x + 1, self.y})

				local x3 = x_pos + 11
				local y3 = y_pos - 4
				local x4 = x_pos + 11
				local y4 = y_pos + 11

				local x1 = x3 - 1
				local y1 = y3 - 1
				local x2 = x4 + 1
				local y2 = y4 + 1

				rectfill(x1, y1, x2, y2, 000)
				rectfill(x3, y3, x4, y4, 007)

				-- reset the palette
				pal()
			end,
			destroy = function(self)
				del(board[self.x][self.y], self)
				del(walls, self)
			end,
		}
    add(walls, wall_right)
		deploy(wall_right, {"wall_right"})
	end
	for i = 1, 9 do
		local wall_down = {
			x = null,
			y = null,
			type = "wall_down",
			draw = function(self)
				palt(0, false)
				local x_pos = (self.x - 1) * 8 + (self.x - 1) * 7 + 15
				local y_pos = (self.y - 1) * 8 + (self.y - 1) * 7 + 15

				local hero_u = find_type_in_tile("hero", {self.x, self.y})
				local hero_d = find_type_in_tile("hero", {self.x, self.y + 1})

				local x3 = x_pos - 4
				local y3 = y_pos + 11
				local x4 = x_pos + 11
				local y4 = y_pos + 11

				local x1 = x3 - 1
				local y1 = y3 - 1
				local x2 = x4 + 1
				local y2 = y4 + 1

				rectfill(x1, y1, x2, y2, 000)
				rectfill(x3, y3, x4, y4, 007)

				-- reset the palette
				pal()
			end,
			destroy = function(self)
				del(board[self.x][self.y], self)
				del(walls, self)
			end,
		}
    add(walls, wall_down)
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

	has_advanced = true
	if #colors_bag == 0 then
		colors_bag = {008,008,009,009,011,011,012,012}
		shuffle(colors_bag)
	end

	-- delete all existing pads
	for next in all(pads) do
		next:destroy()
	end

	-- if there are only 5 spaces left, deploy exits
	-- right now i'm thinking it has to be 5 because otherwise pads get spawned below heroes
	-- but i should probably do something to make this more elegant.
	if #buttons == rows * cols - 4 then
		for i = 1, 2 do
			local exit = {
				x = null,
				y = null,
        screen_seq = {},
				type = "exit",
				draw = function(self)
          palt(015, true)
          local sx = self.screen_seq[1][1]
          local sy = self.screen_seq[1][2]
          local sprite = sprites.exit
					spr(sprite, sx, sy)
          pal()
				end,
			}
			add(exits, exit)
			deploy(exit, {"button", "hero", "exit"})
		end
		return
	end

	local current_colors = {008,009,011,012}
	del(current_colors, colors_bag[1])

	-- place new pads
	for next in all(current_colors) do
		local new_pad = new_pad(next)
		deploy(new_pad, {"pad", "button", "hero"})
	end
	del(colors_bag, colors_bag[1])
end

function new_pad(color)
	local new_pad = new_thing()
	new_pad.sprite_seq = {sprites.pad}
	new_pad.type = "pad"
	new_pad.color = color
	new_pad.list = pads
	new_pad.draw = function(self)
		local sprite = self.sprite_seq[1]
		local sx = self.screen_seq[1][1]
		local sy = self.screen_seq[1][2]
		palt(015, true)
		palt(000, false)
		pal(006, color)
		spr(sprite, sx, sy)
		self:end_draw()
	end
	add(pads, new_pad)
	return new_pad
end

function new_button(color)
	local new_button = new_thing()

	new_button.sprite_seq = {
		sprites.button_1,sprites.button_1,sprites.button_1,sprites.button_1,
		sprites.button_2,sprites.button_2,sprites.button_2,sprites.button_2,
		sprites.button_3,
	}
	new_button.type = "button"
	new_button.color = color
	new_button.list = buttons
	new_button.draw = function(self)
		-- set sprite based on the first value in sprite_seq
		local sprite = self.sprite_seq[1]
		local sx = self.screen_seq[1][1]
		local sy = self.screen_seq[1][2]
		palt(015, true)
		palt(000, false)
		pal(006, color)
		if self.color == 012 then
			pal(005, 001)
		elseif self.color == 008 then
			pal(005, 002)
		elseif self.color == 011 then
			pal(005, 003)
		elseif self.color == 009 then
			pal(005, 004)
		end
		spr(sprite, sx, sy)
		self:end_draw()
	end

	add(buttons, new_button)
	return new_button
end

__gfx__
ffffffffff000fffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffffff070ffffff6fffffffaaaffffffffff0000000000000000000000000000000000000777777000000777777000000770000777777000000000000000
ff000fff0007000ffff6ffffffaa6affffa6afff0000000000000000000000000000000000000777777000000777777000000770000777777000000000000000
0007000f0777770fffffffffff6aa6fffaaaaaff0000000000000000000000000000000000077775555000077775577770077770077775577770000000000000
0777770f0007000f66f6f66fffaa6afffa6a6aff0000000000000000000000000000000000077775555000077775577770077770077775577770000000000000
0007000ff07070fffffffffffffaaafffaa6aaff0000000000000000000000000000000000077771177770077771177770077770077771177770000000000000
f07070fff07070fffff6ffffffffffffffffffff0000000000000000000000000000000000077771177770077771177770077770077771177770000000000000
f00000fff00000fffff6ffffffffffffffffffff0000000000000000000000000000000000077770077770077777777550077770077770077770000000000000
ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000077770077770077777777550077770077770077770000000000000
f66ff66fffffffffffffffffff6666ffeeeeeeee0000000000000000000000000000000000055777777550077775577770077770077777777550000000000000
f6ffff6fffffffffff6666fff666666feffffffe0000000000000000000000000000000000055777777550077775577770077770077777777550000000000000
ffffffffff6666fff666666ff666666fefeeeefe0000000000000000000000000000000000011555555110055551155550055550055555555110000000000000
fffffffff666666ff666666ff566665fefeffefe0000000000000000000000000000000000011555555110055551155550055550055555555110000000000000
f6ffff6ff666666ff566665ff555555fefeeeefe0000000000000000000000000000000000000111111000011110011110011110011111111000000000000000
f66ff66fff6666ffff5555ffff5555ffeffffffe0000000000000000000000000000000000000111111000011110011110011110011111111000000000000000
ffffffffffffffffffffffffffffffffeeeeeeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000607006000600006060000060060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60060007600000000060000600600600000000000000000000000000000000000000000077777700007777770000007700000077000077000077770000000000
00600607000606000600606006000006000000000000000000000000000000000000000077777700007777770000007700000077000077000077770000000000
00006007006000600006000000006000000000000000000000000000000000000000007777777700777755777700777700007777007777007777550000000000
00600607600060000600060600600060000000000000000000000000000000000000007777777700777755777700777700007777007777007777550000000000
60060007060606060006000006000600000000000000000000000000000000000000007777555500777711777700777700007777777755007777777700000000
00000607000000000060060700060007000000000000000000000000000000000000007777555500777711777700777700007777777755007777777700000000
06006007777777770600600700000607000000000000000000000000000000000000007777777700777700777700777700007777557777005555777700000000
00707ffff7f7ffffffffffffffff6fffffff6fff0000000000000000000000000000007777777700777700777700777700007777557777005555777700000000
007070ff07777fffffffffffff6f6fffffffffff0000000000000000000000000000007777555500557777775500777777007777117777007777775500000000
007070ff007070ff000000ffffffff6fffffffff0000000000000000000000000000007777555500557777775500777777007777117777007777775500000000
007070ff007070ff077770ff66ffffff6fffffff0000000000000000000000000000005555111100115555551100555555005555005555005555551100000000
007070ff007070ff007070ffffffff66fffffff60000000000000000000000000000005555111100115555551100555555005555005555005555551100000000
077770ff077770ff077770fff6ffffffffffffff0000000000000000000000000000001111000000001111110000111111001111001111001111110000000000
007700ff007700ff007700fffff6f6ffffffffff0000000000000000000000000000001111000000001111110000111111001111001111001111110000000000
f0000ffff0000ffff0000ffffff6fffffff6ffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbb00000000000000b00000000000000000000000000000000000099990000000000000000000000000000000000000000000000000000000000000
0000000bbbbbb0000000000000b00000000000000000000000000000000000999999000000000000000000000000000000000000000000000000000000000000
0070000bbbbbb00007770000bbbbb000770707007700770777000000777700999999000077700007770077070007700000000000000000000000000000000000
77777003bbbb30000000000000b00007000707070707070070000000070700499994000000000007000707070007070000000000000000000000000000000000
0070000333333000077700000b0b0000070777070707070070000000777700444444000077700007070707070007070000000000000000000000000000000000
0707000033330000000000000b0b0007700707077007700070000000077000044440000000000007770770077707700000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000cccc00000000000000c00000000000000000000000000000000000088880000000000000000000000000000000000000000000000000000000000000
0000000cccccc0000000000000c00000000000000000000000000000000000888888000000000000000000000000000000000000000000000000000000000000
0070000cccccc00007770000ccccc007770707077707770000000000777700888888000077700007070777077707000000000000000000000000000000000000
77777001cccc10000000000000c00000700707077707070000000000070700288882000000000007070770070707000000000000000000000000000000000000
0070000111111000077700000c0c0000700707070707770000000000777700222222000077700007770700077707000000000000000000000000000000000000
0707000011110000000000000c0c0007700077070707000000000000077000022220000000000007070777070707770000000000000000000000000000000000
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

__sfx__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000217521b7521775214752117520f7520d7520b75209752087520675205752047520475204752037520c7020b7020b7020a7020a7020970209702097020970200702007020070200702007020070200702
012000200e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e75511755117551175511755117551175511755117551075510755107551075510755107550c7550c755
002000201d755000000000000000217550000000000000001d7550000000000000001d7550000000000000001d7550000000000000001a7550000000000000001d7550000000000000001d755000000000000000
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
