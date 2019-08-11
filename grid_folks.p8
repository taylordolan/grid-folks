pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- grid folks
-- taylor d

-- todo
-- [x] use different icons for player vs enemy buttons/totems
-- [x] enemy totems should be filled by default
-- [x] design player totems
-- [x] update instruction graphic (with plus signs and totems)
-- [x] explain totems
-- [x] make sure everything is aligned
-- [x] update style for num effects
-- [x] dash enemies should fill totems they touch while dashing
-- [x] has_bumped should only happen when they actually bump
-- [x] fixed starting places for pads (to help communicate how totems are created)?
-- [x] fix guide timing
-- [x] clean up sprite sheet

-- [x] only one grow enemy should pop during a merge
-- [x] communicate that pads turn into totems
-- [x] allow multiple dash enemies to attack the same hero in the same turn
-- [ ] capture a new gif
-- [ ] update game balance
-- [ ] write new instructions for itch page

function _init()

	-- board size
	rows = 5
	cols = 7

	-- 2d array for the board
	board = {}
	tiles = {}
	for x = 1, cols do
		board[x] = {}
		for y = 1, rows do
			board[x][y] = {}
			add(tiles, {x,y})
		end
	end

	-- sounds dictionary
	sounds = {
		["a_step"] = 011,
    ["b_step"] = 012,
		["pad_step"] = 013, -- stepping on a pad
    ["button_step"] = 021, -- stepping on a button
		["advance"] = 014, -- creating new buttons
		["bump"] = 015,
		["shoot"] = 016,
		["jump"] = 017,
    ["charge"] = 021,
		["health"] = 018, -- gaining health
		["score"] = 019, -- gaining gold
    ["enemy_dash"] = 020,
	}

  -- lower sounds are higher priority
  sound_priorities = {
		"a_step",
    "b_step",
		"pad_step",
    "button_step",
		"bump",
		"jump",
    "charge",
		"health",
		"score",
    "enemy_dash",
		"advance",
		"shoot",
	}

  -- no need to list the actual sounds here since they're all false by default
  active_sounds = {}

	-- some game state
	score = 0
	turns = 0
	p_turn = true
	debug = false
	delay = 0
  completed_guides = {}
	depth = 32
	ani_frames = 4
	shakes = {{0,0}}
	game_over = false
	time = 0
  has_advanced = false
  has_bumped = false
  has_switched = false

	-- lists of `things`
	heroes = {}
	enemies = {}
	pads = {}
	buttons = {}
	-- other lists
	exits = {}
	effects = {}
	particles = {}
	charges = {}
	walls = {}
	colors_bag = {}
	o_dirs = {{-1,0},{1,0},{0,-1},{0,1}}

	-- log of recent user input
	queue = {}

	-- initial walls
	refresh_walls()
  for next in all({{2,3},{3,3},{4,3},{5,3}}) do
    local wall = find_type("wall_right", next)
    if wall then
      wall:kill()
    end
  end
  for next in all({{2,3},{4,2},{6,3}}) do
    local wall = find_type("wall_down", next)
    if wall then
      wall:kill()
    end
  end

	-- heroes
	hero_a = new_hero()
	hero_b = new_hero()
	hero_a.active = true
	set_tile(hero_a, {3,3})
	set_tile(hero_b, {5,3})
	update_maps()

	-- initial pads
	refresh_pads({{2,4}, {4,2}, {6,4}})

	-- spawn stuff
	function get_spawn_rates(base, starting_spawn_rate, offset)
    local spawn_rates = {
      [001] = starting_spawn_rate,
    }
    local previous = 1
    local increase = base
    for i=1, starting_spawn_rate - 1 do
      increase += i + offset
      local next = previous + flr(increase)
      spawn_rates[next] = starting_spawn_rate - i
      previous = next
    end
    return spawn_rates
  end
  spawn_rates = get_spawn_rates(12, 12, 4)
	spawn_bags = {
		[001] = {"baby"},
		[026] = {"baby", "dash"},
		[051] = {"baby", "dash", "timid"},
		[076] = {"slime", "dash", "timid"},
		[101] = {"slime", "dash", "timid", "grow"},
	}
	spawn_functions = {
		["baby"] = function()
			new_e_baby():deploy()
		end,
		["timid"] = function()
			new_e_timid():deploy()
		end,
		["slime"] = function()
			new_e_slime():deploy()
		end,
		["dash"] = function()
			new_e_dash():deploy()
		end,
		["grow"] = function()
			new_e_grow():deploy()
			new_e_grow():deploy()
		end,
	}
	spawn_rate = spawn_rates[1]
	spawn_bag = spawn_bags[1]
	spawn_bag_instance = copy(spawn_bag)
	shuff(spawn_bag_instance)
	spawn_turns = {0,0,0}
	-- this gets updated whenever an enemy spawns
	last_spawned_turn = 0
	-- this tracks whether we've spawned a turn early
	spawned_early = false

	-- initial enemy
	spawn_enemy()

	-- start the music!
	music(000)
end

function _update60()

	time += 1

	for next in all(enemies) do
		if next.health <= 0 and #next.pixels <= 1 then
			next:kill()
			local _s = pos_pix(tile(next))
      if (not next.no_pop) new_pop(_s, true)
    end
	end

	-- if btnp(4) then
	-- 	-- debug = not debug
  --   -- new_text_effect(hero_a, small("+1 health"), 008, 007)
	-- 	-- if depth > 2 then
	-- 	-- 	local open_tiles = {}
	-- 	-- 	for next in all(tiles) do
	-- 	-- 		if
	-- 	-- 			not find_type("button", next) and
	-- 	-- 			not find_type("pad", next)
	-- 	-- 		then
	-- 	-- 			add(open_tiles, next)
	-- 	-- 		end
	-- 	-- 	end
	-- 	-- 	shuff(open_tiles)
  --   --   local _b = new_button(008)
	-- 	-- 	set_tile(_b, open_tiles[1])
  --   --   _b:charge()
	-- 	-- 	depth -= 1
	-- 	-- end
  --   -- set_tile(new_button(011), {2,2})
  --   -- set_tile(new_button(008), {3,2})
  --   -- set_tile(new_charge(008), {3,2})
  --   -- score += 1
  --   -- grid = not grid
	-- end

	if game_over then
		if btnp(5) then
			_init()
		end
		return
	end

	-- for complicated reasons, this value should be set to one *less* than the
	-- maximum allowed number of rapid player inputs
	if #queue < 2 then
		local input
		for i=0, 3 do
			if btnp(i) then
				add(queue, o_dirs[i+1])
			end
		end
		if btnp(5) then
			add(queue, 5)
		end
	end

	if delay > 0 then
		delay -= 1
	-- game win
	elseif find_type("exit", tile(hero_a)) and find_type("exit", tile(hero_b)) then
		score += 100
		depth = 0
		game_over = true
	-- game lose
	elseif hero_a.health <= 0 or hero_b.health <= 0 then
		game_over = true
	-- player turn
	elseif p_turn == true and #queue > 0 then
		if queue[1] == 5 then
			for next in all(heroes) do
				has_switched = true
				next.active = not next.active
			end
			crosshairs()
			active_sounds["switch"] = true
		else
			active_hero():act(queue[1])
		end
		del(queue, queue[1])
	-- enemy turn
	elseif p_turn == false then
		if should_advance() then
			add_button()
			refresh_walls()
			update_maps()
			refresh_pads()
			depth -= 1
		else
			update_maps()
		end

		shuff(enemies)
		for next in all(enemies) do
			next:update()
		end

		-- spawn bag stuff
		if spawn_bags[turns] then
			spawn_bag = spawn_bags[turns]
			spawn_bag_instance = copy(spawn_bag)
			shuff(spawn_bag_instance)
		end

		-- spawn rate stuff
		turns += 1
		update_spawn_turns()
		for i = 1, spawn_turns[turns] do
			spawn_enemy()
		end
		if spawn_rates[turns] then
			spawn_rate = spawn_rates[turns]
		end
		-- update game state
		crosshairs()
		p_turn = true
	end
	h_btns()

  local active_sound = false
  for next in all(sound_priorities) do
    if active_sounds[next] then
      active_sound = next
    end
    active_sounds[next] = false
  end
  if active_sound then
    sfx(sounds[active_sound], 3)
  end

	if stat(1) > 1 then printh(stat(1)) end
end

function shake(dir)
	local a = {0,0}
	local b = {-dir[1],-dir[2]}
	local c = {-dir[1]*2,-dir[2]*2}
	shakes = {a,c,c,b,a}
end

function trim(_a)
	if #_a > 1 then
		del(_a,_a[1])
	end
end

function _draw()
	cls()

	local _s = shakes[1]
	camera(_s[1],_s[2])
	trim(shakes)

	-- draw_floor
	rectfill(11, 11, 116, 86, 007)
	-- draw outlines
	rect(12, 12, 115, 85, 000)
	-- draw border
	-- top and bottom
	for x = 12, 115, 8 do
		spr(008, x, 4)
		spr(008, x, 86, 1, 1, true, true)
	end
	-- left and right
	for y = 13, 84, 8 do
		spr(007, 4, y)
		spr(007, 116, y, 1, 1, true, true)
	end
	-- top left
	spr(009, 4, 5)
	-- top right
	spr(010, 116, 5, 1, 1, true)
	-- bottom left
	spr(010, 4, 85, 1, 1, false, true)
	-- bottom right
	spr(009, 116, 85, 1, 1, true, true)
	pal()

	-- draw objects
	for list in all({
		-- things at the bottom appear on top
		pads,
		exits,
		buttons,
		walls,
		particles,
		charges,
		heroes,
		enemies,
		effects,
	}) do
		for next in all(list) do
			next:draw()
		end
	end

  local a_btn = find_type("button",  tile(hero_a))
  local b_btn = find_type("button",  tile(hero_b))
  local a_btn_clr = false
  local b_btn_clr = false
  if (a_btn) a_btn_clr = a_btn.color
  if (b_btn) b_btn_clr = b_btn.color

	if game_over then
		-- draw game over state
		local msg
		local msg_x
		local msg_y
		-- line 1
		if depth != 0 then
			msg = small("you died with " .. score .. " gold")
		else
			msg = small("you escaped! +100 gold")
		end
		local msg_x = 64 - #msg * 2
		print(msg, msg_x, 99, 007)
		-- line 2
		if depth != 0 then
			local txt = depth == 1 and " depth" or " depths"
			msg = small(depth .. txt .. " from the surface")
		else
			msg = small("final score: " .. score)
		end
		msg_x = 64 - #msg * 2
		print(msg, msg_x, 109, 007)
		-- line 3
		print(small("press x to restart"), 28, 119, 005)
	elseif not (has_switched and has_bumped and has_advanced) then
		-- draw intro
		print(small("press x to switch heroes"), 16, 99, has_switched and 005 or 007)
		print(small("bump to attack"), 36, 109, has_bumped and 005 or 007)
		print(small("stand on 2"), 19, 119, has_advanced and 005 or 007)
		palt(015, true)
		pal(006, has_advanced and 005 or 007)
		spr(016, 61, 116)
		print(small("to ascend"), 73, 119, has_advanced and 005 or 007)
		-- return
		pal()
  elseif current_guide == 012 and not completed_guides[012] and (a_btn_clr == 012 and hero_a.took_guide_step == true or b_btn_clr == 012 and hero_b.took_guide_step == true) then
    -- print messages
    print(small("when a hero stands on"), 15, 99, 007)
    print(",", 111, 99, 007)
    print(small("the other hero can jump"), 18, 109, 007)
    -- print sprite
    palt(15,true)
    pal(005,001)
    pal(006,012)
    spr(018, 102, 96)
    pal()
  elseif current_guide == 011 and not completed_guides[011] and (a_btn_clr == 011 and hero_a.took_guide_step == true or b_btn_clr == 011 and hero_b.took_guide_step == true) then
    -- print messages
    print(small("when a hero stands on"), 15, 99, 007)
    print(",", 111, 99, 007)
    print(small("the other hero can shoot"), 16, 109, 007)
    -- print sprite
    palt(15,true)
    pal(005,003)
    pal(006,011)
    spr(018, 102, 96)
    pal()
  elseif current_guide == 008 and not completed_guides[008] and (a_btn_clr == 008 and hero_a.took_guide_step == true or b_btn_clr == 008 and hero_b.took_guide_step == true) then
    -- print messages
    print(small("are refilled with health"), 22, 99, 007)
    print(small("when enemies step on them"), 14, 109, 007)
    -- print sprite
    palt(15,true)
    pal(005,002)
    pal(006,008)
    spr(017, 10, 96)
    pal()
  elseif current_guide == 009 and not completed_guides[009] and (a_btn_clr == 009 and hero_a.took_guide_step == true or b_btn_clr == 009 and hero_b.took_guide_step == true) then
    -- print messages
    print(small("are refilled with gold"), 26, 99, 007)
    print(small("when enemies step on them"), 14, 109, 007)
    -- print sprite
    palt(15,true)
    pal(005,004)
    pal(006,009)
    spr(017, 14, 96)
    pal()
	else
		-- draw instructions area
		-- depth
		print(small("depth"), 11, 99, 007)
		print(depth, 34, 99, 007)
		-- score
		local num = score .. ""
		print(small("gold"), 102, 99, 007)
		print(num, 99 - #num * 4, 99, 007)
		-- instructions
		spr(032, 11, 106, 7, 1) -- green
    spr(048, 11, 116, 7, 1) -- blue
		spr(039, 70, 106, 6, 1) -- orange
    spr(055, 70, 116, 6, 1) -- red
	end

	for next in all(effects) do
		next:draw()
	end

  -- draw grid
  -- if grid then
  --   for x = -1, 128, 8 do
  --     for y = -1, 128, 8 do
  --       pset(x, y, 014)
  --       pset(x+1, y, 014)
  --       pset(x, y+1, 014)
  --       pset(x+1, y+1, 014)
  --     end
  --   end
  -- end
end

function copy(_a)
	local _b = {}
	for next in all(_a) do
		add(_b, next)
	end
	return _b
end

function new_thing()
	local new_thing = {
		x = null,
		y = null,
		-- a sequence of screen positions
		pixels = {},
		-- a sequence of palette modifications
		pals = {{010,010}},
		sprites = {100},
		end_draw = function(self)
			trim(self.pixels)
			trim(self.pals)
			trim(self.sprites)
			pal()
		end,
		kill = function(self)
			if self.x and self.y then
				del(board[self.x][self.y], self)
			end
			del(self.list, self)
		end,
	}
	return new_thing
end

function new_hero()
	local _h = new_thing()

	_h.type = "hero"
	_h.target_type = "enemy"
	_h.max_health = 3
	_h.health = 3
	_h.list = heroes
  _h.took_guide_step = false

	_h.act = function(self, direction)

		local ally = heroes[1] == self and heroes[2] or heroes[1]
		local next_tile = add_pairs(tile(self), direction)

		-- if the destination exists and the tile isn't occupied by your ally
		if location_exists(next_tile) and not find_type("hero", next_tile) then

			local enemy = find_type("enemy", next_tile)
			local wall = is_wall_between(tile(self), next_tile)

			-- if jump is enabled
			if self.jump then
        if (enemy or wall) completed_guides[012] = true
        if (enemy) hit_target(enemy, 3, direction)
				local _here = pos_pix(tile(self))
				local _next = pos_pix(next_tile)
				local _half = {(_here[1] + _next[1]) / 2, _here[2]-4}
				set_tile(self, next_tile)
				ani_to(self, {_half, _next}, ani_frames/2, 0)
				delay = ani_frames
				active_sounds["jump"] = true
				p_turn = false

			-- if there's no wall
			elseif not wall then
				-- if shoot is enabled and shoot targets exist
				local shoot_targets = get_ranged_targets(self, direction)
				if self.shoot and #shoot_targets > 0 then
					for next in all(shoot_targets) do
						hit_target(next, 1, {-direction[1],-direction[2]})
					end
					new_shot(self, direction)
          completed_guides[011] = true
					active_sounds["shoot"] = true
					delay = ani_frames
					p_turn = false

				-- otherwise, if there's an enemy in the destination, hit it
				elseif enemy then
					active_sounds["bump"] = true
          has_bumped = true
					hit_target(enemy, 1, direction)
					local here = pos_pix(tile(self))
					local bump = {here[1] + direction[1] * 4, here[2] + direction[2] * 4}
					ani_to(self, {bump, here}, ani_frames/2, 0)
					delay = ani_frames
					p_turn = false

				-- otherwise, move to the destination
				else
					set_tile(self, next_tile)
					ani_to(self, {pos_pix(next_tile)}, ani_frames, 0)
					delay = ani_frames
					p_turn = false
				end
			end
		end
		-- update buttons
		ally.jump = false
		ally.shoot = false
		local _b = find_type("button", tile(self))
		if _b then
			if _b.color == 012 then
				ally.jump = true
			elseif _b.color == 011 then
				ally.shoot = true
			end
		end
	end

	_h.draw = function(self)

		-- set sprite
		local sprite = self.active and 001 or 000

		-- set the current screen destination using the first value in pixels
		local sx = self.pixels[1][1]
		local sy = self.pixels[1][2]
		-- todo: clean this up
		local ax = pos_pix(tile(self))[1]
		local ay = pos_pix(tile(self))[2]

		-- default palette updates
		palt(015, true)
		palt(000, false)
		if not self.active then
			pal(000, 006)
		end

		if self.shoot then
			pal(007, 011) -- white to green
			pal(006, 011) -- light gray to green
			pal(005, 007) -- dark gray to white
			if self.active then
				for next in all(o_dirs) do
					local _a = tile(self)
					local _b = {self.x + next[1], self.y + next[2]}
					local sprite = next[2] == 0 and 003 or 004
					local flip_x
					local flip_y
					if next[1] == -1 then
						flip_x = true
					elseif next[2] == -1 then
						flip_y = true
					end
					if #get_ranged_targets(self, next) > 0 then
						spr(sprite, ax + next[1] * 8, ay + next[2] * 8, 1, 1, flip_x, flip_y)
					end
				end
			end
		elseif self.jump then
			pal(007, 012) -- white to blue
			pal(006, 012) -- light gray to blue
			pal(005, 007) -- dark gray to white
			if self.active then
				for next in all(o_dirs) do
					local _a = tile(self)
					local _b = {self.x + next[1], self.y + next[2]}
					local sprite = next[2] == 0 and 003 or 004
					local flip_x
					local flip_y
					if next[1] == -1 then
						flip_x = true
					elseif next[2] == -1 then
						flip_y = true
					end
					if
						find_type("enemy", _b) or
						location_exists(_b) and is_wall_between(_a, _b) and not find_type("hero", _b)
					then
						spr(sprite, ax + next[1] * 8, ay + next[2] * 8, 1, 1, flip_x, flip_y)
					end
				end
			end
		else
			pal(005, 007) -- dark gray to white
			if self.active then
				for next in all(o_dirs) do
					local _a = tile(self)
					local _b = {self.x + next[1], self.y + next[2]}
					local sprite = next[2] == 0 and 003 or 004
					local flip_x
					local flip_y
					if next[1] == -1 then
						flip_x = true
					elseif next[2] == -1 then
						flip_y = true
					end
					if not is_wall_between(_a, _b) and find_type("enemy", _b) then
						spr(sprite, ax + next[1] * 8, ay + next[2] * 8, 1, 1, flip_x, flip_y)
					end
				end
			end
		end

		-- update the palette using first value in pals
		pal(self.pals[1][1], self.pals[1][2])

		-- draw the sprite and the hero's health
		spr(sprite, sx, sy)
		draw_health(sx, sy, self.health, 0, 8)

		self:end_draw()
	end

	add(heroes, _h)
	return _h
end

function new_e()
	local _e = new_thing()
	_e.sprites = {021}
	_e.type = "enemy"
	_e.target_type = "hero"
	_e.stunned = true
	_e.health = 2
	_e.is_target = 0
	_e.list = enemies
	_e.target = nil
	_e.step = nil

	_e.update = function(self)
		if p_turn == false then
			if self.stunned == true then
				self.stunned = false
			else
				self.target = self:get_target()
				self.step = self:get_step()
				self:attack()
				self:move()
			end
		end
	end

	_e.get_target = function(self)
		local targets = {}
		for next in all(heroes) do
			if distance_by_map(next.dmap_ideal, tile(self)) == 1 then
				add(targets, next)
			end
		end
		if #targets >= 1 then
			shuff(targets)
			return targets[1]
		else
			return nil
		end
	end

	_e.get_step_to_hero = function(self)

		local here = tile(self)
		local target
		local current_dist
		local steps = {}
		local target_options

		local a_ideal = distance_by_map(hero_a.dmap_ideal, here)
		local b_ideal = distance_by_map(hero_b.dmap_ideal, here)
		local a_avoid = distance_by_map(hero_a.dmap_avoid, here)
		local b_avoid = distance_by_map(hero_b.dmap_avoid, here)

		-- pick a hero to target

		local close_heroes_ideal = closest(here, heroes, false)
		local close_heroes_avoid = closest(here, heroes, true)
		if #close_heroes_ideal > 1 and #close_heroes_avoid > 0 then
			target_options = close_heroes_avoid
		else
			target_options = close_heroes_ideal
		end
		shuff(target_options)
		target = target_options[1]
		current_dist = distance_by_map(target.dmap_ideal, here)

		-- get valid steps to target

		-- get adjacent tiles that don't have enemies in them
		local adjacent_tiles = get_adjacent_tiles(here)
		for next in all(adjacent_tiles) do
			if find_type("enemy", next) then
				del(adjacent_tiles, next)
			end
		end
		-- get closer adjacent tiles
		for next in all(adjacent_tiles) do
			if distance_by_map(target.dmap_ideal, next) < current_dist then
				add(steps, next)
			end
		end
		-- if there aren't any closer adjacent tiles, then get closer adjacent tiles
		-- on paths that avoid enemies
		if #steps == 0 then
			for next in all(adjacent_tiles) do
				if distance_by_map(target.dmap_avoid, next) < current_dist then
					add(steps, next)
				end
			end
		end
		-- if there still aren't any options, then move randomly
		if #steps == 0 then
			steps = adjacent_tiles
		end
		-- set the step
		if #steps > 0 then
			shuff(steps)
			return steps[1]
		end
	end

	_e.get_step = function(self)
		-- if not attacking this turn
		if not self.target then
			return self:get_step_to_hero()
		end
	end

	_e.attack = function(self)
		if self.target then
			local direction = get_direction(tile(self), tile(self.target))
			hit_target(self.target, 1, direction)
			local here = pos_pix(tile(self))
			local bump = {here[1] + direction[1] * 4, here[2] + direction[2] * 4}
			ani_to(self, {bump, here}, ani_frames/2, 2)
			delay = ani_frames
			active_sounds["bump"] = true
		end
	end

	_e.move = function(self)
		if self.step then
			set_tile(self, self.step)
			ani_to(self, {pos_pix(self.step)}, ani_frames, 0)
			delay = ani_frames
		end
	end

	_e.draw = function(self)

		local sprite = self.sprites[1]

		-- set the current screen destination using the first value in pixels
		local sx = self.pixels[1][1]
		local sy = self.pixels[1][2]

		-- default palette updates
		palt(015, true)
		palt(000, false)
		if self.stunned and p_turn == false or self.stunned and delay == 0 then
			pal(000, 006)
		end

		-- update the palette using first value in pals
		pal(self.pals[1][1], self.pals[1][2])

		-- draw the enemy and its health
		spr(sprite, sx, sy)
		local _t = self.is_target == 012 and 3 or self.is_target > 0 and 1 or 0
		draw_health(sx, sy, self.health, _t, 8)

		-- draw crosshairs
		if self.health >= 1 and self.is_target > 006 then
			pal(006, self.is_target)
			spr(002, sx, sy)
		end

		self:end_draw()
	end

	_e.deploy = function(self)
		local valid_tiles = {}
		for next in all(tiles) do
			if
				not find_type("hero", next) and
				not find_type("enemy", next) and
        distance_by_map(hero_a.dmap_ideal, next) >= 3 and
        distance_by_map(hero_b.dmap_ideal, next) >= 3
			then
				add(valid_tiles, next)
			end
		end

		if #valid_tiles > 0 then
			shuff(valid_tiles)
			set_tile(self, valid_tiles[1])
		else
			self:kill()
		end
	end

	add(enemies, _e)
	return _e
end

function new_e_timid()
	local _e = new_e()
	_e.sprites = {021}
	_e.health = 1

	_e.get_step = function(self)
		-- if not attacking this turn
		if not self.target then
			local here = tile(self)
			local step = self:get_step_to_hero()
			if step then
				if
					distance_by_map(hero_a.dmap_ideal, step) > 1 and
					distance_by_map(hero_b.dmap_ideal, step) > 1
				then
					return step
				-- wait
				else
					local dir = get_direction(tile(self), step)
					local _a = pos_pix(tile(self))
					local _b = {_a[1] + dir[1] * 2, _a[2] + dir[2] * 2}
					self.sprites = stretch({027, 021})
				end
			end
		end
	end

	return _e
end

function new_e_dash()
	local _e = new_e()
	_e.sprites = {026}
	_e.health = 1
	_e.dir = {0,0}

	-- returns a dash target if one exists, and sets `self.dir` to the direction
	-- the target is in
	_e.get_target = function(self)
		local target
		for dir in all(o_dirs) do
			local candidate = get_ranged_targets(self, dir)[1]
			-- if multiple targets are available, set `target` to the closest one
			if candidate and target then
				local c_dist = distance_by_map(candidate.dmap_ideal, tile(self))
				local t_dist = distance_by_map(target.dmap_ideal, tile(self))
				if c_dist < t_dist then
					target = candidate
					self.dir = dir
				end
			elseif candidate then
				target = candidate
				self.dir = dir
			end
		end
		if target then
			return target
		else
			self.dir = {0,0}
			return nil
		end
	end

	_e.get_step = function(self)
		if not self.target then
			return self:get_step_to_hero()
		end
	end

	_e.attack = function(self)
		if self.target then
			hit_target(self.target, 1, self.dir)
			local _t = tile(self.target)
			local _n = tile(self)
			local _tiles = {_n}
			while true do
				_n = add_pairs(_n,self.dir)
				if pair_equal(_n,_t) then
					break
				end
				add(_tiles, _n)
			end
			for i=1, #_tiles do
        local _b = find_type("button", _tiles[i])
        local _c = find_type("charge", _tiles[i])
        if _b and (_b.color == 009 or _b.color == 008) and not _c then
          _b:charge(i*2)
        end
				new_pop(pos_pix(_tiles[i]), false, 1, 4+i*8)
			end
			set_tile(self, _t)
			ani_to(self, {pos_pix(_t)}, ani_frames, 0)
			delay = ani_frames
			active_sounds["enemy_dash"] = true
			self.health = 0
		end
	end

	return _e
end

function new_e_slime()
	local _e = new_e()
	_e.sprites = {022}

	_e.move = function(self)
		if self.step then
			set_tile(new_e_baby(), tile(self))
			set_tile(self, self.step)
			ani_to(self, {pos_pix(self.step)}, ani_frames, 0)
			delay = ani_frames
			self.stunned = true
		end
	end

	_e.attack = function(self)
		if self.target then
			local direction = get_direction(tile(self), tile(self.target))
			hit_target(self.target, 1, direction)
			local here = pos_pix(tile(self))
			local bump = {here[1] + direction[1] * 4, here[2] + direction[2] * 4}
			ani_to(self, {bump, here}, ani_frames/2, 2)
			delay = ani_frames
			active_sounds["enemy_bump"] = true
			self.stunned = true
		end
	end

	return _e
end

function new_e_baby()
	local _e = new_e()
	_e.health = 1
	_e.sprites = {023}
	return _e
end

function tile(thing)
	return {thing.x,thing.y}
end

function get_random_moves(start)
	local _a = get_adjacent_tiles(start)
	local _b = {}
	for next in all(_a) do
		if
			not find_type("enemy", next) and
			not find_type("hero", next)
		then
			add(_b, next)
		end
	end
	return _b
end

function new_e_grow()
	local _e = new_e()
	_e.health = 1
	_e.sprites = {024}
	_e.sub_type = "grow"

	_e.get_friends = function(self)
		local friends = {}
		for next in all(enemies) do
			if next.sub_type == "grow" then
				add(friends, next)
			end
		end
		del(friends, self)
		shuff(friends)
		return friends
	end

	-- this is only called if there is at least one friend
	_e.get_step_to_friend = function(self)

		local here = tile(self)
		local friends = self:get_friends()
		local steps = {}
		local target_options

		-- pick a friend to target

		-- find the closest friends by ideal distance and avoid distance
		local close_friends_ideal = closest(tile(self), friends, false)
		local close_friends_avoid = closest(tile(self), friends, true)
		-- if there's more than one friend by ideal distance, use closest friends by
		-- avoid distance, if there are any
		if #close_friends_ideal > 1 and #close_friends_avoid > 0 then
			target_options = close_friends_avoid
		else
			target_options = close_friends_ideal
		end
		-- pick a random target
		shuff(target_options)
		local target = target_options[1]
		local current_dist = distance_by_map(target.dmap_ideal, here)

		-- get valid steps to target

		-- if they're already on the same tile, don't move
		if current_dist == 0 then
			return nil
		end
		-- otherwise, get adjacent tiles that don't have enemies or heroes in them
		local adjacent_tiles = get_adjacent_tiles(tile(self))
		for next in all(adjacent_tiles) do
			local enemy = find_type("enemy", next)
			if
				find_type("hero", next) or
				enemy and enemy.sub_type != "grow"
			then
				del(adjacent_tiles, next)
			end
		end
		-- get closer adjacent tiles
		for next in all(adjacent_tiles) do
			if distance_by_map(target.dmap_ideal, next) < current_dist then
				add(steps, next)
			end
		end
		-- if there aren't any closer adjacent tiles, then get closer adjacent tiles
		-- on paths that avoid enemies and heroes
		if #steps == 0 then
			for next in all(adjacent_tiles) do
				if distance_by_map(target.dmap_avoid, next) < current_dist then
					add(steps, next)
				end
			end
		end
		-- if there still aren't any options, then move randomly
		if #steps == 0 then
			steps = adjacent_tiles
		end
		-- set the step
		if #steps > 0 then
			shuff(steps)
			return steps[1]
		end
	end

	_e.get_step = function(self)
		-- if there are friends
		if #self:get_friends() > 0 then
			return self:get_step_to_friend()
		-- if there's no friend and this enemy isn't attacking this turn
		elseif not self.target then
			return self:get_step_to_hero()
		end
	end

	_e.move = function(self)
		if self.health > 0 then
			-- move, if necessary
			if self.step then
				set_tile(self, self.step)
				ani_to(self, {pos_pix(self.step)}, ani_frames, 0)
				delay = ani_frames
			end
			-- grow, if possible
			for next in all(board[self.x][self.y]) do
				if next != self and next.sub_type == "grow" then
					self.health = 0
          self.no_pop = true
					next.health = 0
					set_tile(new_e_grown(), tile(self))
				end
			end
		end
	end

	_e.get_target = function(self)
		local friends = self:get_friends()
		if #friends == 0 then
			local targets = {}
			for next in all(heroes) do
				if distance_by_map(next.dmap_ideal, tile(self)) == 1 then
					add(targets, next)
				end
			end
			if #targets > 0 then
				shuff(targets)
				return targets[1]
			end
		end
	end

	_e.deploy = function(self)
		function is_too_close(dest, grow_enemies)
			for next in all(grow_enemies) do
				if
					next.x and next.y and
					distance_by_map(next.dmap_ideal, dest) < 5
				then
					return true
				end
			end
			return false
		end
		local valid_tiles = {}
		local grow_enemies = {}
		for next in all(enemies) do
			if next.sub_type == "grow" then
				add(grow_enemies, next)
			end
		end
		for next in all(tiles) do
			if not is_too_close(next, grow_enemies) then
				add(valid_tiles, next)
			end
		end
		for next in all(valid_tiles) do
			if
				find_type("enemy", next) or
				distance_by_map(hero_a.dmap_ideal, next) < 3 or
				distance_by_map(hero_b.dmap_ideal, next) < 3
			then
				del(valid_tiles,next)
			end
		end
		if #valid_tiles > 0 then
			shuff(valid_tiles)
			set_tile(self, valid_tiles[1])
			self.dmap_ideal = get_distance_map(tile(self))
			self.dmap_avoid = get_distance_map(tile(self), {"enemy", "hero"})
		else
			self:kill()
		end
	end

	return _e
end

function new_e_grown()
	local _e = new_e()
	_e.health = 3
	_e.sprites = {025}
	return _e
end

-- from an array of options, return an array of the ones that are closest to a
-- start tile. `avoid` is a bool of whether or not to use the options' "avoid
-- distance" maps
function closest(start, options, avoid)
	local avoid = avoid or {}
	local closest = {options[1]}
	for i = 2, #options do
		local now_dist = distance_by_map(avoid and closest[1].dmap_avoid or closest[1].dmap_ideal, start)
		local new_dist = distance_by_map(avoid and options[i].dmap_avoid or options[i].dmap_ideal, start)
		if new_dist < now_dist then
			closest = {options[i]}
		elseif new_dist == now_dist then
			add(closest, options[i])
		end
	end
	return closest
end

function new_shot(thing, dir)

	local wall = nil
	local now_tile = tile(thing)

	while wall == nil do
		-- define the next tile
		local next_tile = {now_tile[1] + dir[1], now_tile[2] + dir[2]}
		-- if `next_tile` is off the map, or there's a wall in the way, return false
		if
			not location_exists(next_tile) or
			is_wall_between(now_tile, next_tile)
		then
			wall = now_tile
		end
		-- set `current` to `next_tile` and keep going
		now_tile = next_tile
	end

	local _a = pos_pix(tile(thing))
	local _b = pos_pix(wall)
	local _ax = _a[1]
	local _ay = _a[2]
	local _bx = _b[1]
	local _by = _b[2]

	-- up
	if pair_equal(dir, {0, -1}) then
		_ax += 3
		_bx += 3
		_ay -= 3
		_by += 0
	-- down
	elseif pair_equal(dir, {0, 1}) then
		_ax += 3
		_bx += 3
		_ay += 10
		_by += 7
	-- left
	elseif pair_equal(dir, {-1, 0}) then
		_ax -= 3
		_bx += 0
		_ay += 3
		_by += 3
	-- right
	elseif pair_equal(dir, {1, 0}) then
		_ax += 10
		_bx += 7
		_ay += 3
		_by += 3
	end

	local new_shot = {
		frames = 6,
		draw = function(self)
			rectfill(_ax, _ay, _bx, _by, 011)
			self.frames -= 1
			if self.frames == 0 then
				del(effects, self)
			end
		end,
	}
	add(effects, new_shot)
end

function stretch(a, n)
	local n = n or ani_frames
	local b = {}
	for next in all(a) do
		for i=1, n do
			add(b, next)
		end
	end
	return b
end

function merge(lists)
  local merged = {}
  for list in all(lists) do
    for next in all(list) do
      add(merged, next)
    end
  end
  return merged
end

function draw_health(x_pos, y_pos, current, threatened, offset)
	-- draw current amount of health in dark red
  for i = 1, current do
    pset(x_pos + offset, y_pos + 10 - i * 3, not game_over and flr(time/24) % 2 == 0 and 002 or 008)
    pset(x_pos + offset, y_pos + 9 - i * 3, not game_over and flr(time/24) % 2 == 0 and 002 or 008)
  end
	-- draw current - threatened amount of health in light red
	for i = 1, current - threatened do
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
	if #spawn_bag_instance == 0 then
		spawn_bag_instance = copy(spawn_bag)
		shuff(spawn_bag_instance)
	end
	spawn_functions[spawn_bag_instance[1]]()
	del(spawn_bag_instance, spawn_bag_instance[1])
end

function active_hero()
	if hero_a.active then
		return hero_a
	else
		return hero_b
	end
end

function dark(color)
  if (color == 012) return 001 -- blue
  if (color == 008) return 002 -- red
  if (color == 011) return 003 -- green
  if (color == 009) return 004 -- orange
end

function small(s)
	local d=""
	local c
	for i=1,#s do
		local a=sub(s,i,i)
		if a!="^" then
			if not c then
				for j=1,26 do
					if a==sub("abcdefghijklmnopqrstuvwxyz",j,j) then
						a=sub("\65\66\67\68\69\70\71\72\73\74\75\76\77\78\79\80\81\82\83\84\85\86\87\88\89\90\91\92",j,j)
					end
				end
			end
			d=d..a
			c=true
		end
		c=not c
	end
	return d
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

function ani_to(thing, dests, frames, wait)

	local _p = {}
	local _c = thing.pixels[1]

	for i=1, wait do
		add(_p, _c)
	end

	for next in all(dests) do
		local frame_v = {(next[1] - _c[1]) / frames, (next[2] - _c[2]) / frames}
		for j=1, frames do
			local next_x = _c[1] + frame_v[1]
			local next_y = _c[2] + frame_v[2]
			local next = {next_x, next_y}
			add(_p, next)
			_c = next
		end
	end

	thing.pixels = _p
end

function set_tile(thing, dest)

	-- do nothing if dest is off the board
	if not location_exists(dest) then
		return
	end

  -- local _c = find_type("charge", dest)

  -- trigger hero step sounds
	-- checking for x because we don't want to make this sound if the hero is
  -- being deployed
	if thing.type == "hero" and thing.x then
    -- tracks whether the hero's last step triggered a guide so that stepping on
    -- a filled totem won't later trigger a guide
    thing.took_guide_step = false
    local _b = find_type("button", dest)
    local _p = find_type("pad", dest)
    if thing == hero_a then
			active_sounds["a_step"] = true
      -- if the friend is standing on a button that hasn't had its guide
      -- completed yet, then set the guide to that color
      local _f = find_type("button", tile(hero_b))
      if (_f and not completed_guides[_f.color] and hero_b.took_guide_step == true) current_guide = _f.color
    else
      active_sounds["b_step"] = true
      local _f = find_type("button", tile(hero_a))
      if (_f and not completed_guides[_f.color] and hero_a.took_guide_step == true) current_guide = _f.color
		end
		if _p then
			active_sounds["pad_step"] = true
    elseif _b then
      local _c = find_type("charge", dest) and true or false
      -- make sound for green or blue buttons
      if _b.color == 011 or _b.color == 012 then
        active_sounds["button_step"] = true
      end
      -- set current guide
      if _b.color and not completed_guides[_b.color] and not _c then
        thing.took_guide_step = true
        current_guide = _b.color
      end
    end
	end

	-- remove it from its current tile
	if thing.x then
		del(board[thing.x][thing.y], thing)
	end

	-- add it to the dest tile
	add(board[dest[1]][dest[2]], thing)

	-- set its x and y values
	thing.x = dest[1]
	thing.y = dest[2]

	-- enter transitions for enemies
	if thing.pixels and #thing.pixels == 0 then
		local pix = pos_pix(dest)
		if thing.type == "enemy" then
			for i = -4, 0 do
				add(thing.pixels, {pix[1], pix[2] + i})
			end
		else
			thing.pixels = {pix}
		end
	end

	-- trigger enemy buttons when they step or are deployed
	if thing.type == "enemy" then
		local _b = find_type("button", tile(thing)) -- change these to dest?
		local _c = find_type("charge", tile(thing))
		if _b and _b.color == 008 and not _c then
      _b:charge()
      completed_guides[008] = true
      active_sounds["charge"] = true
		elseif _b and _b.color == 009 and not _c then
      _b:charge()
      completed_guides[009] = true
      active_sounds["charge"] = true
		end
	end
end

-- update distance maps for heroes and grow enemies
function update_maps()
	for next in all(heroes) do
		next.dmap_ideal = get_distance_map(tile(next))
		next.dmap_avoid = get_distance_map(tile(next), {"enemy"})
	end
	for next in all(enemies) do
		if next.sub_type == "grow" then
			next.dmap_ideal = get_distance_map(tile(next))
			next.dmap_avoid = get_distance_map(tile(next), {"enemy", "hero"})
		end
	end
end

-- todo: why am I not doing this as part of set_tile()?
function h_btns()
	for hero in all(heroes) do
		local _c = find_type("charge", tile(hero))
		if _c then
			if _c.color == 008 then
				if hero.health < hero.max_health then
					hero.health = min(hero.health + 1, hero.max_health)
					new_text_effect(hero, small("+1 health"), 008, 007)
				else
					new_text_effect(hero, small("+0 health"), 008, 007)
				end
        active_sounds["health"] = true
			elseif _c.color == 009 then
				score += 1
				new_text_effect(hero, small("+1 gold"), 009, 007)
        active_sounds["score"] = true
			end
			_c:kill()
		end
	end
end

-- converts board position to screen pixels
function pos_pix(_bp)
	local _bx = _bp[1] - 1
	local _by = _bp[2] - 1
	return {_bx * 15 + 15, _by * 15 + 15}
end

function shuff(t)
	for i = #t, 1, -1 do
		local j = flr(rnd(i)) + 1
		t[i], t[j] = t[j], t[i]
	end
end

function deploy(thing, avoid_list)
	local valid_tiles = {}
	for next in all(tiles) do
		local tile_is_valid = true
		local x = next[1]
		local y = next[2]
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
	local index = flr(rnd(#valid_tiles)) + 1
	local dest = valid_tiles[index]
	set_tile(thing, dest)
end

-- todo: make this a `thing`?
function new_text_effect(parent, string, color, outline)
	local _n = {
		parent = parent, -- hero to base position of effect on
		_x = function(self)
			return self.parent.pixels[1][1]
		end,
		_y = function(self)
			return self.parent.pixels[1][2]
		end,
		offset = 0,
		t = 0,
		draw = function(self)
      -- the screen position where the main color text gets drawn
			local base = {self:_x() - #string * 2 + 4, self:_y() + self.offset}
      -- outline
			for next in all({{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{-1,1},{1,-1},{1,1}}) do
				local result = add_pairs(base, next)
				print(string, result[1], result[2], outline)
			end
      print(string, base[1], base[2] + 2, outline)
      print(string, base[1] - 1, base[2] + 2, outline)
      print(string, base[1] + 1, base[2] + 2, outline)
      -- dark color
      print(string, base[1], base[2] + 1, dark(color))
      -- main color
			print(string, base[1], base[2], color)
			if self.t < 96 then
				self.t += 1
				self.offset = max(-8, self.offset - 1)
			else
				del(effects, self)
			end
			pal()
		end,
	}
	add(effects, _n)
	return _n
end

function new_pop(pix, should_move, particle_count, frames)
	local particle_count = particle_count or 8
	local frames = frames or 15
	function new_particle(pix, frames, should_move)
		local vel_x = should_move and {1,-1,1.5,-1.5,2,-2} or {0}
		local vel_y = copy(vel_x)
		shuff(vel_x)
		shuff(vel_y)
		local particle = {
			pix_x = pix[1],
			pix_y = pix[2],
			vel_x = vel_x[1],
			vel_y = vel_y[1],
			max_frames = frames,
			frames = frames,
			sprite = 011,
			speed = 1,
			draw = function(self)
				if self.frames == flr(self.max_frames * 2/3) then
					self.sprite = 005
					self.speed /= 3
				elseif self.frames == flr(self.max_frames * 1/3) then
					self.sprite = 006
					self.speed /= 3
				end
				palt(015,true)
				self.pix_x += self.vel_x * self.speed
				self.pix_y += self.vel_y * self.speed
				spr(self.sprite,self.pix_x,self.pix_y)
				self.frames -= 1
				if self.frames <= 0 then
					del(particles,self)
				end
				pal()
			end
		}
		add(particles, particle)
	end
	for i=1, particle_count do
		new_particle(pix, frames, should_move)
	end
end

function array_has_tile(array, tile)
	for next in all(array) do
		if tile[1] == next[1] and tile[2] == next[2] then
			return true
		end
	end
	return false
end

function find_type(type, tile)
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

function find_types(types, tile)
	local found = false
	for next in all(types) do
		if find_type(next, tile) then
			found = true
		end
	end
	return found
end

-- avoids walls
function get_adjacent_tiles(tile)

	local self_x = tile[1]
	local self_y = tile[2]
	local adjacent_tiles = {}

	-- todo: use `o_dirs` to clean this up
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

function get_ranged_targets(thing, direction)

	local now_tile = tile(thing)
	local targets = {}

	while true do
		-- define the current target
		local next_tile = {now_tile[1] + direction[1], now_tile[2] + direction[2]}
		local target = find_type(thing.target_type, next_tile)
		-- if `next_tile` is off the map, or there's a wall in the way, or a thing
    -- of the same type is in the way, then stop checking tiles
		if
			not location_exists(next_tile) or
			is_wall_between(now_tile, next_tile) or
			find_type(thing.type, next_tile) and not target
		then
			return targets
		end
		-- if there's a target in the tile, add it to the list of targets
		if target then
			add(targets, target)
		end
		-- set `current` to `next_tile` and keep going
		now_tile = next_tile
	end
end

function add_pairs(tile, dir)
	return {tile[1] + dir[1], tile[2] + dir[2]}
end

function crosshairs()
	local hero = active_hero()
	for next in all(enemies) do
		next.is_target = 0
		if distance_by_map(hero.dmap_ideal, tile(next)) == 1 then
			next.is_target = 006
		end
	end
	for dir in all(o_dirs) do
		if hero.shoot then
			local targets = get_ranged_targets(hero, dir)
			for next in all(targets) do
				next.is_target = 011
			end
		elseif hero.jump then
			local enemy = find_type("enemy", add_pairs(tile(hero), dir))
			if enemy then
				enemy.is_target = 012
			end
		end
	end

end

function should_advance()
	-- find any pads that heroes are occupying
	-- if there are heroes occupying two pads
	return find_type("pad", tile(hero_a)) and find_type("pad", tile(hero_b))
end

function add_button()

	has_advanced = true
	-- find the other pad
	local o_p
	for next in all(pads) do
		if
			next != find_type("pad", tile(hero_a)) and
			next != find_type("pad", tile(hero_b))
		then
			o_p = next
		end
	end

	-- put a button in its position
  new_button(o_p.color):deploy({o_p.x, o_p.y})

	-- make the advance sound
	active_sounds["advance"] = true
end

function hit_target(target, damage, direction)
	target.health -= damage
	if target.type == "enemy" then
    if target.health <= 0 then
      active_sounds["bump"] = true
    end
	end
	local r = {000,008}
	local y = {010,010}
	target.pals = {y,y,r,r,r,r,y}
	shake(direction)
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
	return a[1] == b[1] and a[2] == b[2]
end

function dumb_distance(a,b)
	local x_dist = abs(a[1] - b[1])
	local y_dist = abs(a[2] - b[2])
	return x_dist + y_dist
end

function get_distance_map(start, avoid)
	local avoid = avoid or {}
	local frontier = {start}
	local next_frontier = {}
	local steps = 0
	local distance_map = {}
	for x = 1, cols do
		distance_map[x] = {}
		for y = 1, rows do
			-- this is a hack but it's easier than using a different type
			distance_map[x][y] = 1000
		end
	end
	distance_map[start[1]][start[2]] = 0

	while #frontier > 0 do
		for i = 1, #frontier do
			local here = frontier[i]

			for next in all(get_adjacent_tiles(here)) do
				-- if the distance hasn't been set, then the tile hasn't been reached yet
				if distance_map[next[1]][next[2]] == 1000 then
					-- set the distance for the tile
					distance_map[next[1]][next[2]] = steps + 1
					if
						-- make sure it wasn't already added by a different check in the same step
						not array_has_tile(next_frontier, next) and
						-- make sure the tile doesn't contain avoid things
						not find_types(avoid, next)
					then
						add(next_frontier, next)
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

function distance_by_map(map, tile)
	return map[tile[1]][tile[2]]
end

function is_wall_between(tile_a, tile_b)

	local a_x = tile_a[1]
	local a_y = tile_a[2]
	local b_x = tile_b[1]
	local b_y = tile_b[2]

	-- if b is above a
	if b_x == a_x and b_y == a_y - 1 then
		-- this is a bit weird but it works
		return find_type("wall_down", tile_b) and true or false
	-- if b is below a
	elseif b_x == a_x and b_y == a_y + 1 then
		return find_type("wall_down", tile_a) and true or false
	-- if b is left of a
	elseif b_x == a_x - 1 and b_y == a_y then
		return find_type("wall_right", tile_b) and true or false
	-- if b is right of a
	elseif b_x == a_x + 1 and b_y == a_y then
		return find_type("wall_right", tile_a) and true or false
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

function new_wall(type)
	local _w = {
			x = null,
			y = null,
			type = type,
			draw = function(self)
				palt(0, false)
				local x_pos = (self.x - 1) * 8 + (self.x - 1) * 7 + 15
				local y_pos = (self.y - 1) * 8 + (self.y - 1) * 7 + 15

				local x3 = x_pos + 11
				local y3 = y_pos + 11
				local x4 = x_pos + 11
				local y4 = y_pos + 11

				if self.type == "wall_right" then
					y3 = y_pos - 4
				elseif self.type == "wall_down" then
					x3 = x_pos - 4
				end

				local x1 = x3 - 1
				local y1 = y3 - 1
				local x2 = x4 + 1
				local y2 = y4 + 1

				rectfill(x1, y1, x2, y2, 000)
				rectfill(x3, y3, x4, y4, 007)
				pal()
			end,
			kill = function(self)
				del(board[self.x][self.y], self)
				del(walls, self)
			end,
		}
		add(walls, _w)
		return _w
end

function generate_walls()
	for i=1, 12 do
		deploy(new_wall("wall_right"), {"wall_right"})
	end
	for i=1, 9 do
		deploy(new_wall("wall_down"), {"wall_down"})
	end
end

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
					if array_has_tile(next_frontier, next) == false then
						add(next_frontier, next)
					end
				end
			end
		end
		frontier = next_frontier
		next_frontier = {}
	end

	-- if any position in reached_map is false, then the map isn't contiguous
	for next in all(tiles) do
		if reached_map[next[1]][next[2]] == false then
			return false
		end
	end

	return true
end

function refresh_pads(preset_tiles)

  local preset_tiles = preset_tiles or {}
	if #colors_bag == 0 then
		colors_bag = {008,008,008,009,011,012}
		shuff(colors_bag)
	end

	-- delete all existing pads
	for next in all(pads) do
		next:kill()
	end

	-- if there are only 4 spaces left, deploy exits (the 2 spaces where heroes
	-- are currently standing will remain empty)
	if #buttons == rows * cols - 4 then
		for i = 1, 2 do
			local exit = {
				x = null,
				y = null,
				pixels = {},
				type = "exit",
				draw = function(self)
					palt(015, true)
					local sx = self.pixels[1][1]
					local sy = self.pixels[1][2]
					spr(020, sx, sy)
					pal()
				end,
			}
			add(exits, exit)
			deploy(exit, {"button", "hero", "exit"})
		end
		return
	end

	local pad_colors = {008,009,011,012}
	del(pad_colors, colors_bag[1])
	del(colors_bag, colors_bag[1])

	-- place new pads
	local pads = {new_pad(pad_colors[1]), new_pad(pad_colors[2]), new_pad(pad_colors[3])}
  if #preset_tiles > 0 then
    shuff(preset_tiles)
    for i=1, #pads do
      set_tile(pads[i], preset_tiles[i])
    end
  else
    local open_tiles = {}
    for next in all(tiles) do
      if
        not find_type("pad", next) and
        not find_type("button", next) and
        not find_type("hero", next)
      then
        add(open_tiles, next)
      end
    end
    -- find open tiles that are > 3 tiles away from heroes
    local dist_3_tiles = {}
    for next in all(open_tiles) do
      if
        distance_by_map(hero_a.dmap_ideal, next) >= 3 and
        distance_by_map(hero_b.dmap_ideal, next) >= 3
      then
        add(dist_3_tiles, next)
        del(open_tiles, next)
      end
    end
    -- find open tiles that are > 2 tiles away from heroes
    local dist_2_tiles = {}
    for next in all(open_tiles) do
      if
        distance_by_map(hero_a.dmap_ideal, next) >= 2 and
        distance_by_map(hero_b.dmap_ideal, next) >= 2
      then
        add(dist_2_tiles, next)
        del(open_tiles, next)
      end
    end

    shuff(dist_3_tiles)
    shuff(dist_2_tiles)
    shuff(open_tiles)

    for i=1, #pads do
      if dist_3_tiles[1] then
        set_tile(pads[i], dist_3_tiles[1])
        del(dist_3_tiles, dist_3_tiles[1])
      elseif dist_2_tiles[1] then
        set_tile(pads[i], dist_2_tiles[1])
        del(dist_2_tiles, dist_2_tiles[1])
      else
        set_tile(pads[i], open_tiles[1])
        del(open_tiles, open_tiles[1])
      end
    end
  end
end

function new_pad(color)
	local _p = new_thing()
	_p.sprites = {016}
	_p.type = "pad"
	_p.color = color
	_p.list = pads
	_p.draw = function(self)
		local sprite = self.sprites[1]
		local sx = self.pixels[1][1]
		local sy = self.pixels[1][2]
		palt(015, true)
		palt(000, false)
		pal(006, color)
		spr(sprite, sx, sy)
		self:end_draw()
	end
	add(pads, _p)
	return _p
end

-- extra_delay is used when a dash enemy charges multiple buttons while dashing
-- so that they appear to be charged in sequence
-- when a charge is created along with a new button…
  -- extra_delay is used to hide the charge until flashing is done
  -- offset is set to 0 so the charge shows up in place
function new_charge(color, extra_delay, offset)
	local _c = new_thing()
  local _e = extra_delay or 0
  local offset = offset or -8

	_c.type = "charge"
	_c.color = color
	_c.list = charges
	_c.offset = offset
	_c.delay = ani_frames + _e
	_c.draw = function(self)
		if self.delay > 0 then
			self.delay -= 1
		else
			palt(015, true)
			palt(000, false)
			pal(006, color)
      pal(005, dark(color))
			local sx = self.pixels[1][1]
			local sy = self.pixels[1][2] - 2
			spr(019,sx,sy + self.offset)
			self.offset = min(self.offset + 1, 0)
			pal()
		end
	end

	add(charges, _c)
	return _c
end

function new_button(color)
	local _b = new_thing()
  local sprites
  local charge

  -- green or blue
  if color == 011 or color == 012 then
    sprites = merge({stretch({018}, 12), stretch({016}, 9), stretch({018}, 6), stretch({016}, 3), {018}})
    charge = function(self, extra_delay, offset)
      return
    end
  -- red or orange
  elseif color == 008 or color == 009 then
    sprites = merge({stretch({028}, 12), stretch({016}, 9), stretch({028}, 6), stretch({016}, 3), {017}})
    charge = function(self, extra_delay, offset)
      set_tile(new_charge(color, extra_delay, offset), tile(self))
    end
  end

  _b.sprites = sprites
	_b.type = "button"
	_b.color = color
	_b.list = buttons
  _b.charge = charge
  _b.deploy = function(self, tile)
    set_tile(self, tile)
    self:charge(26, 0) -- cancel out delay, no offset
  end
	_b.draw = function(self)
		local sprite = self.sprites[1]
		local sx = self.pixels[1][1]
		local sy = self.pixels[1][2]
		palt(015, true)
		palt(000, false)
		pal(006, color)
    pal(005, dark(self.color))
		spr(sprite, sx, sy)
		self:end_draw()
	end

	add(buttons, _b)
	return _b
end

__gfx__
ffffffffff000fffffffffffffffffffffffffffffffffffffffffff00000707007000700007070000070070ffffffff00000000000000000000000000000000
ffffffffff070ffffff6fffffff555ffffffffffffffffffffffffff70070007700000000070000700700700ffffffff00000000000000000000000000000000
ff000fff0007000ffff6ffffff5565ffff565fffffffffffffffffff00700707000707000700707007000007ffffffff00000000000000000000000000000000
0007000f0777770fffffffffff6556fff55555fffff6ffffffffffff00007007007000700007000000007000ff666fff00000000000000000000000000000000
0777770f0007000f66fff66fff5565fff56565ffff666ffffff6ffff00700707700070000700070700700070ff666fff00000000000000000000000000000000
0007000ff07070fffffffffffff555fff55655fffff6ffffffffffff70070007070707070007000007000700ff666fff00000000000000000000000000000000
f07070fff07070fffff6ffffffffffffffffffffffffffffffffffff00000707000000000070070700070007ffffffff00000000000000000000000000000000
f00000fff00000fffff6ffffffffffffffffffffffffffffffffffff07007007777777770700700700000707ffffffff00000000000000000000000000000000
fffffffffffffffffff65fffffffffffffffffffffffffffffffffffffffffffffffffff000000fffffffffffffffffffff66fff000000000000000000000000
fffffffffffffffffff65ffffff77fffeeeeeeee00000fffffffffffffffffff000000ff077770ffffffffffffffffffff6765ff000000000000000000000000
fffffffffffffffffff65fffff7667ffeffffffe07070ffff0000fffffffffff077770ff007070ff000000ff00000fffff6665ff000000000000000000000000
f66ff66ffffffffff666555ff767657fefeeeefe07070fff077770fff0000fff007070ff077770ff077770ff07070ffffff55fff000000000000000000000000
f6ffff6ff6ffff5ffff66ffff766657fefeffefe077770ff077770ff077770ff077770ff007770ff007070ff07070ffff6ffff5f000000000000000000000000
fffffffff666555ff666555fff7557ffefeeeefe007070ff007070ff007070ff0077770ff077770f0777770f077770fff666555f000000000000000000000000
f6ffff6ffff66ffffff66ffffff77fffeffffffe077770ff0777770f077770fff070700ff070700f0707070f077770fffff66fff000000000000000000000000
f66ff66ff666555ff666555fffffffffeeeeeeee000000ff0000000f000000fff00000fff00000ff0000000f000000fff666555f000000000000000000000000
00000000000000b30000000000000000000000000000000000000000000000000000000000000000009900000000000000000000000000000000000000000000
00000000000000b30000000000000000000000000000000000000000000000000000000000000000097940000000000000000000000000000000000000000000
00000000000000b300000000000b0000000000000000000000000000000000000000000000000000099940000000000000000000000000000000000000000000
000000000000bbb333000000000b0000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000
00700000700000bb000077700bbbbb00077070700770077077700000000000070009000040077700900004007770077070007700000000000000000000000000
777770077700bbb333000000000b0000700070707070707007000000777700777009994440000000999444007000707070007070000000000000000000000000
00700000700000bb0000777000b0b000007077707070707007000000070700070000094000077700009900007070707070007070000000000000000000000000
070700000000bbb33300000000b0b000770070707700770007000000777700000009994440000000999444007770770077707700000000000000000000000000
00000000000000c10000000000000000000000000000000000000000000000000000000000000000008800000000000000000000000000000000000000000000
00000000000000c10000000000000000000000000000000000000000000000000000000000000000087820000000000000000000000000000000000000000000
00000000000000c100000000000c0000000000000000000000000000000000000000000000000000088820000000000000000000000000000000000000000000
000000000000ccc111000000000c0000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000
00700000700000cc000077700ccccc00777070707770777000000000000000070008000020077700800002007070777077707000000000000000000000000000
777770077700ccc111000000000c0000070070707770707000000000777700777008882220000000888222007070770070707000000000000000000000000000
00700000700000cc0000777000c0c000070070707070777000000000070700070000088000077700008800007770700077707000000000000000000000000000
070700000000ccc11100000000c0c000770007707070700000000000777700000008882220000000888222007070777070707770000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070000000000000
00000007070070000000700000007000000070000000700000007000000070000000700000007000000070000000700000007000000070000000070070000000
00000070000700070700000707000007070000070700000707000007070000070700000707000007070000070700000707000007070000070700007007000000
00000700707000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070700000700000
00000007000070007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000000700000000
00000700070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070007000000
00000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007000700000
00000070070777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770700070000000
00000700700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000707000000000
00000000070707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770700700700000
00007007000707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770707000000000
000000700707077777777777777777777777777777777777777777777777777777777777777777c1777777777777777777777777777777777770700070070000
000000007007077777777777777777777777777777777777777777777777777777777777777777c1777777777777777777777777777777777770707007000000
000000700707077777777777777777777777777777777777777777777777777777777777777777c1777777777777777777777777777777777770700700000000
0000700700070777887788777777777777777777777777777777777777777777777777777777ccc111777777777777777777777777bb77bb7770707007000000
000000000707077787777877777777777777777777777777777777777777777777777777777777cc77777777777777777777777777b7777b7770700070070000
0000070070070777777777777777777777777777777777777777777777777777777777777777ccc1117777777777777777777777777777777770707000000000
000000000707077787777877777777777777777777777777777777777777777777777777777777cc77777777777777777777777777b7777b7770700700700000
0000700700070777887788777777777777777777777777777777777777777777777777777777ccc111777777777777777777777777bb77bb7770707000000000
00000070070707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770700070070000
00000000700707777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770707007000000
00000070070000000000000000000000000000000007777777777770000000000000000000000000000000007777777777777777777777777770700700000000
00007007000777777777777777707777777777777707777777777770777777777777770777777777777777707777777777777777777777777770707007000000
00000000070000000000000000000000000000000007777777777770000000000000000000000000000000007777777777777777777777777770000070070000
00000700700707777777777770707777777777777777777777777777777777777777777777777777777770707777777777777777777777777770707000000000
00000000070707777777777770707777777777777777777777777777777777777777777777777777777770707777777777777777777777777770700700700000
000070070007077777777777707077777b3777777777777777777777777777777777777777777777777770707777788777777777777777777770707000000000
000000700707077777777777707077777b3777777777777777777777777777777777777777777777777770707777878277777777777777777770700070070000
000000007007077777777777707077777b3777777777777777777777777777777777777777777777777770707777888277777777777777777770707007000000
0000007007070777777777777070777bbb3337777777777777777777777777777777777777777777777770707777722777777777777777777770700700000000
000070070007077777777777707077777bb777777777777777777777777777777777777777777777777770707778777727777777777777777770707007000000
0000000007070777777777777070777bbb3337777777777777777777777777777777777777777777777770707778882227777777777777777770700070070000
000007007007077777777777707077777bb777777777777777777777777777777777777777777777777770707777788777777777777777777770707000000000
0000000007070777777777777070777bbb3337777777777777777777777777777777777777777777777770707778882227777777777777777770700700700000
00007007000707777777777770707777777777777777777777777777777777777777777777777777777770707777777777777777777777777770707000000000
00000070070707777777777770707777777777777777777777777777777777777777777777777777777770707777777777777777777777777770700070070000
00000000700707777777777770707777777777770007777777777770007777777777770000000000000000000000000000000007777777777770707007000000
00000070070707777777777770707777777777770707777777777770707777777777770777777777777770777777777777777707777777777770700700000000
00007007000707777777777770007777777777770707777777777770707777777777770000000000000000000000000000000007777777777770007007000000
00000000070707777777777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770700070070000
00000700700707777777777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770707000000000
000000000707077777b3777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770700700700000
000070070007077777b3777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770707000000000
000000700707077777b3777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770700070070000
0000000070070777bbb3337777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770707007000000
000000700707077777bb777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770700700000000
0000700700070777bbb3337777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770707007000000
000000000707077777bb777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770700070070000
0000070070070777bbb3337777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770707000000000
00000000070707777777777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770700700700000
00007007000707777777777777777777777777770707777777777770707777777777777777777777777770707777777777777777777777777770707000000000
00000070070707777777777770007777777777770707777777777770707777777777770007777777777770707777777777777777777777777770000070070000
00000000700707777777777770707777777777770707777777777770707777777777770707777777777770707777777777777777777777777770707007000000
00000070070707777777777770707777777777770007777777777770007777777777770707777777777770007777777777777777777777777770700700000000
00007007000707777777777770707777777777777777777777777777777777777777770707777777777777777777777777777777777777777770707007000000
00000000070707777777777770707777777777777777777777777777777777777777770707777777777777777777777777777777777777777770700070070000
000007007007077777777777707077777c1777777777777777777777777777000777770707777777777777777777777777777777777799777770707000000000
000000000707077777777777707077000b07777777777777777777777777770b0777770707777777777777777777777777777777777979477770700700700000
000070070007077777777777707077070b077777777777777777777b7777000b0007770707777777777777777770000777777777777999477770707000000000
000000700707077777777777707077070701177777777777777777b77b770bbbbb07870707779977997777777707777077877777770000777770700070070000
000000007007077777777777707077bb777bb777777777777777777b7777000b0007870707779777797777777707777077877777707777047770707007000000
00000070070707777777777770707700707017777777777777777777777770b0b077770707777777777777777700707077777777700707047770700700000000
000070070007077777777777707077077b7077277777777777777777777770b0b077870707779777797777777707777707877777707777077870707007000000
000000000707077777777777707077000b0017277777777777777777777770000077870707779977997777777700000007877777700000047870700070070000
00000700700707777777777770707777777777777777777777777777777777777777770707777777777777777777777777777777777777777770707000000000
00000000070707777777777770707777777777777777777777777777777777777777770707777777777777777777777777777777777777777770700700700000
00007007000707777777777770707777777777770007777777777777777777777777770707777777777770000000000000000007777777777770707000000000
00000070070707777777777770707777777777770707777777777777777777777777770707777777777770777777777777777707777777777770700070070000
00000000700707777777777770007777777777770707777777777777777777777777770007777777777770000000000000000007777777777770007007000000
00000070070707777777777777777777777777770707777777777777777777777777770707777777777777777777777777777777777777777770700700000000
00007007000707777777777777777777777777770707777777777777777777777777770707777777777777777777777777777777777777777770707007000000
000000000707077777887777777777777777777707077777777777777777777777777707077777777777777777777b3777777777777777777770700070070000
000007007007077778782777777777777777777707077777777777777777777777777707077777777777777777777b3777777777777777777770707000000000
00000000070707777888277777777777777777770707777777777777777777777777770707777777777777777777666777777777777777777770700700700000
00007007000707777722777777777777777777770707777777777777777777777777770707777777777777777766676667877777770000777770707000000000
00000070070707778777727777777777777777770707779777747777777777777777770707777777777777777767777767877777707777077770700070070000
00000000700707778882227777777777777777770707779994447777777777777777770707777777777777777766676667777777700707077770707007000000
00000070070707777788777777777777777777770707777799777777777777777777770707777777777777777776767677877777707777077870700700000000
00007007000707778882227777777777777777770707779994447777777777777777770707777777777777777776666637877777700000077870707007000000
00000000070707777777777777777777777777770707777777777777777777777777770707777777777777777777777777777777777777777770700070070000
00000700700707777777777777777777777777770707777777777777777777777777770707777777777777777777777777777777777777777770707000000000
00000000070700000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000700700700000
00000007000777777777777777777777777777770707777777777777777777777777770777777777777770777777777777777707777777777777707007000000
00000700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000
00000070007070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707000700000
00000000700000070007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000070000000
00000700000707000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070700700000
00000070070000707000007070000070700000707000007070000070700000707000007070000070700000707000007070000070700000707000700007000000
00000007007000000007000000070000000700000007000000070000000700000007000000070000000700000007000000070000000700000007007070000000
00000000000007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700070007000700000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000007770777000000000000000000000000000000000000000000000000000000777000000000000000000000000000000
00000000000770077707770777070700000070007000000000000000000000000000000000000000000000000000000007000077700770700077000000000000
00000000000707077007070070070700007770077000000000000000000000000000000000000000000000000000000777000070007070700070700000000000
00000000000707070007770070077700007000007000000000000000000000000000000000000000000000000000000700000070707070700070700000000000
00000000000770077707000070070700007770777000000000000000000000000000000000000000000000000000000777000077707700777077000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000b300000000000000000000000000000000000000000000000000000000000000000000099000000000000000000000000000000
0000000000000000000000000b300000000000000000000000000000000000000000000000000000000000000000000979400000000000000000000000000000
0000000000000000000000000b300000000000b00000000000000000000000000000000000000000000000000000000999400000000000000000000000000000
00000000000000000000000bbb333000000000b00000000000000000000000000000000000000000000000000000000044000000000000000000000000000000
0000000000000700000700000bb000077700bbbbb000770707007700770777000000000000000700090000400777009000040077700770700077000000000000
00000000000777770077700bbb333000000000b00007000707070707070070000000007777007770099944400000009994440070007070700070700000000000
0000000000000700000700000bb0000777000b0b0000070777070707070070000000000707000700000940000777000099000070707070700070700000000000
00000000000070700000000bbb33300000000b0b0007700707077007700070000000007777000000099944400000009994440077707700777077000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000c100000000000000000000000000000000000000000000000000000000000000000000088000000000000000000000000000000
0000000000000000000000000c100000000000000000000000000000000000000000000000000000000000000000000878200000000000000000000000000000
0000000000000000000000000c100000000000c00000000000000000000000000000000000000000000000000000000888200000000000000000000000000000
00000000000000000000000ccc111000000000c00000000000000000000000000000000000000000000000000000000022000000000000000000000000000000
0000000000000700000700000cc000077700ccccc007770707077707770000000000000000000700080000200777008000020070707770777070000000000000
00000000000777770077700ccc111000000000c00000700707077707070000000000007777007770088822200000008882220070707700707070000000000000
0000000000000700000700000cc0000777000c0c0000700707070707770000000000000707000700000880000777000088000077707000777070000000000000
00000000000070700000000ccc11100000000c0c0007700077070707000000000000007777000000088822200000008882220070707770707077700000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000000001d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0020000021515225052651522505215152250526515225051f5152150522515215051f5152150522515215051a5151d505215151d5051a5151d505215151d505185151a5051b5151a505185151a5051b5151a505
002000200e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e7550e75511755117551175511755117551175511755117551075510755107551075510755107550c7550c755
002000201d755000000000000000217550000000000000001d7550000000000000001d7550000000000000001d7550000000000000001a7550000000000000001d7550000000000000001d755000000000000000
0040002010037000071003700007100370000710037000071303718007130370000713037180071303700007150370c0071503700007150370c00715037000071d037000071c037000071a037000071803700007
004100001f0301f035000050000500005000052303023035210302103500005000050000500005260302603528030280350000000000000000000000000000000000000000000000000000000000000000000000
002000000254300500005000050013615176001760000500025430050000500005001361500500005000050002543005000050000500136150050000500005000254300500005000050013615005000050000500
0080001007745007000c7450070007745007000a7450070007745007000f7450070007745007000e7450070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00200000217150070518715007051f715007051b715007051d715007051b715007051f715007051a715007051d715007051a715007051f7150070518715007051a715007051b715007051f715007051a71500705
0020000021515225152651522515215152251526515225151f5152151522515215151f5152151522515215151a5151d515215151d5151a5151d515215151d515185151a5151b5151a515185151a5151b5151a515
0020000021515225152651522505215152250526515225051f5152151522515215051f5152150522515215051a5151d515215151d5051a5151d505215151d505185151a5151b5151a505185151a5051b5151a505
000800000f765027652670522705217052270526705227051f7052170522705217051f7052170522705217051a7051d705217051d7051a7051d705217051d705187051a7051b7051a705187051a7051b7051a705
000800000c7650276500705007052f705177051770500705027050070500705007052f705007050070500705027050070500705007052f705007050070500705027050070500705007052f705007050070500705
000400000c633076030c6330c62300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
000c0000037140f7211b7312774133722337250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800000306103065000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000271201d121131210010300100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00080000000610006100065000000100003000040000a000090000100001000010000000000001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
000800000c0740f0741b0740000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004
000800002774537735377350070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000800000363103625036150a60002603126052f60505605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
000400000c633075001b0302202535000120052f00505705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
00080000277152b51537715335053b505395050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505
000800000c755027350c7000f7030d7030b7030970307703067030570304703037030370302703017030170301703017030170301703017030170301703017030170301703017030170301703017030170301703
000400000f715027150c715027150f715027150c71502715007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
010400001c7150371518715037151c715037151871503715007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
010c00000c7540f7341a7240f7040d7040b7040970407704067040570404704037040370402704017040170401704017040170401704017040170401704017040170401704017040170401704017040170401704
00200000037140f7211b7312774133722337250000000001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000000000000000
000600000f0330c613130331f60300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300000
010c00002b15318133131130f1000d1040b1040910307103061030510304103031030310302103011030110301103011030110301103011030110301103011030110301103011030110301103011030110301103
000800000503105031050000500004700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010800000303103035000050200004001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
0108000008150160100c6000c6000c6000e6000e60010600106001060011600176001560013600116000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
010800000f7330c61313703056031d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001b7501d7501b750207001c700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010400000305103051006230002100051000550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 07404040
01 07084006
00 07080106
00 07080a06
00 0748094c
00 0708094c
00 07080906
02 07080106
00 4748494c
00 47484b4c
04 42434040
04 44454040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040

