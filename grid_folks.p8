pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- grid folks
-- taylor d

-- todo
-- [x] make inactive heroes gray
-- [x] show "+0" when not gaining health
-- [x] bring back intro animations for buttons
-- [ ] do something about when dash enemies dash to a health or score tile
-- [ ] try giving enemies more health
-- [ ] create a trim function for removing the first item in a table if its length is > 1

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

	-- sounds dictionary
	sounds = {
		music = 002,
		health = 026, -- gaining health
		shoot = 029,
		jump = 025,
		step = 021,
		pad_step = 028, -- stepping on a pad
		score = 022, -- gaining gold
		advance = 027, -- creating new buttons
		switch = 000, -- switching heroes
		enemy_bump = 000,
		hero_bump = 000,
		win = 000,
		lose = 000,
	}

	-- some game state
	score = 0
	turns = 0
	p_turn = true
	debug = false
	delay = 0
	has_advanced = false
	t_score = 0
	t_health = 0
  depth = 32
  ani_frames = 4
  shakes = {{0,0}}

	-- lists of `things`
	heroes = {}
	enemies = {}
  -- grow_enemies = {}
	pads = {}
	buttons = {}
	-- other lists
	exits = {}
	effects = {}
  particles = {}
  walls = {}
	colors_bag = {}
  o_dirs = {{-1,0},{1,0},{0,-1},{0,1}}
  s_dirs = {{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{-1,1},{1,-1},{1,1}}

	-- log of recent user input
	queue = {}

	-- heroes
	hero_a = new_hero()
	hero_b = new_hero()
	hero_a.active = true
	set_tile(hero_a, {3,3})
	set_tile(hero_b, {5,3})

	-- initial walls
	refresh_walls()
	for next in all({{2,3},{3,3},{4,3},{5,3}}) do
		local wall = find_type("wall_right", next)
		if wall then
			wall:kill()
		end
	end

	-- initial pads
  local _c = {008,011,012}
	local _t = {{2,3},{4,3},{6,3}}
  shuff(_t)
  for i=1, 3 do
    set_tile(new_pad(_c[i]), _t[i])
  end
	for next in all({{2,3},{3,3},{4,3},{5,3}}) do
		local wall = find_type("wall_right", next)
		if wall then
			del(board[next[1]][next[2]], wall)
		end
	end

	-- spawn stuff
	spawn_rates = {
		[001] = 12,
		[040] = 10,
		[080] = 8,
		[120] = 6,
    [160] = 4,
		[200] = 3,
		[240] = 2,
		[280] = 1,
	}
  spawn_bags = {
    [001] = {"dash"},
    [020] = {"dash","timid"},
    [040] = {"dash","timid","slime"},
    [060] = {"dash","timid","slime","grow"},
  }
  spawn_functions = {
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
	music(sounds.music)
end

function _update60()

  for next in all(enemies) do
    if next.health <= 0 and #next.pixels <= 1 then
      next:kill()
      local _s = pos_pix(tile(next))
      new_pop({_s[1],_s[2]})
    end
  end

	if btnp(4) then
		debug = not debug
	end

	if is_game_over() and btnp(5) then
    _init()
		return
	end

	-- for complicated reasons, this value should be set to
	-- one *less* than the maximum allowed number of rapid player inputs
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
	-- player turn
	elseif p_turn == true and #queue > 0 then
		if queue[1] == 5 then
			for next in all(heroes) do
				next.active = not next.active
			end
			crosshairs()
			sfx(sounds.switch, 3)
		else
			active_hero():act(queue[1])
		end
		del(queue, queue[1])
	elseif p_turn == false then

		if should_advance() then
			add_button()
			refresh_pads()
			refresh_walls()
			depth -= 1
			new_num_effect({26 + #(depth .. "") * 4,99}, -1, 007, 000)
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
    turns = turns + 1
		update_spawn_turns()
    for i = 1, spawn_turns[turns] do
      spawn_enemy()
    end
    if spawn_rates[turns] then
			spawn_rate = spawn_rates[turns]
		end
    -- update game state
		trigger_btns()
		crosshairs()
		p_turn = true
	end

  -- for next in all(enemies) do
  --   if next.health <= 0 and #next.pixels <= 1 then
  --     next:kill()
  --     local _s = pos_pix(tile(next))
  --     new_pop({_s[1],_s[2]})
  --   end
  -- end

	if delay <= 0 then
		-- game won test
		local a_exit = find_type("exit", tile(hero_a))
		local b_exit = find_type("exit", tile(hero_b))
		if a_exit and b_exit then
			score += 100
			depth -= 1
			sfx(sounds.win, 3)
		-- game lost test
		elseif hero_a.health <= 0 or hero_b.health <= 0 then
			sfx(sounds.lose, 3)
		end
	end
end

function shake(dir)
  local a = {0,0}
  local b = {-dir[1],-dir[2]}
  shakes = {a,a,b,b,b,b,a}
end

function _draw()
	cls()

  local _s = shakes[1]
  camera(_s[1],_s[2])
  if #shakes > 1 then
    del(shakes, _s)
  end

	-- draw_floor
	rectfill(11, 11, 116, 86, 007)
	-- draw outlines
	rect(10, 10, 117, 87, 000)
	rect(12, 12, 115, 85, 000)
	-- draw objects
	for list in all({
		-- things at the bottom appear on top
		pads,
		exits,
		buttons,
		walls,
    particles,
		enemies,
		heroes,
		effects,
	}) do
		for next in all(list) do
			next:draw()
		end
	end

	-- draw border
	pal(006, 007)
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

	if is_game_over() then
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
		local msg_x = 65 - (#msg * 4) / 2
		local msg_y = 99
		print(msg, msg_x, msg_y, 007)
		-- line 2
		if depth != 0 then
			local txt = depth == 1 and " depth" or " depths"
			msg = small(depth .. txt .. " from the surface")
		else
			msg = small("final score: " .. score)
		end
		msg_x = 65 - (#msg * 4) / 2
		msg_y += 10
		print(msg, msg_x, msg_y, 007)
		-- line 3
		if debug then
			msg = small("turns: " .. turns ..", spawn rate: " .. spawn_rate)
		else
			msg = small("press x to restart")
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
		local _a = small("press x to switch")
		print(_a, _x, _y, 007)
		spr(000, _x + #_a * 4 + _space, _y - 2)
		spr(001, _x + #_a * 4 + 8 + _space, _y - 2)

		_x = 18
		_y += 10
		local _b = small("stand on 2")
		print(_b, _x, _y, 007)
		spr(016, _x + #_b * 4 + _space, _y - 2)
		local _c = small("to advance")
		print(_c, _x + #_b * 4 + _space + 8 + _space, _y, 007)
		return
		pal()
	else
		-- draw instructions area
		if not debug then
			local msg = small("depth")
			print(msg, 11, 99, 007)
			print(depth, 34, 99, 007)
		else
			local text = turns .."/"..spawn_rate
			print(text, 11, 99, 005)
		end
		-- score
		local text = small("gold")
		local num = score .. ""
		print(text, 118 - #text * 4, 99, 007)
		print(num, 99 - #num * 4, 99, 007)
		-- instructions
		spr(032, 11, 108, 7, 2)
		spr(039, 79, 108, 5, 2)
	end
	for next in all(effects) do
		next:draw()
	end
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
		sprite = 100,
		end_draw = function(self)
      for next in all({self.pixels, self.pals}) do
        if #next > 1 then
          del(next, next[1])
        end
      end
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

	_h.sprite = 000
	_h.type = "hero"
  _h.target_type = "enemy"
	_h.max_health = 3
	_h.health = 3
	_h.list = heroes

	_h.act = function(self, direction)

		local ally = heroes[1] == self and heroes[2] or heroes[1]
		local next_tile = add_pairs(tile(self), direction)

		-- this is where the actual acting starts
		-- if the destination exists and the tile isn't occupied by your ally
		if location_exists(next_tile) and not find_type("hero", next_tile) then

			local enemy = find_type("enemy", next_tile)
			local wall = is_wall_between(tile(self), next_tile)

			-- if jump is enabled and there's a wall in the way
			if self.jump then
				if enemy then
					hit_target(enemy, 3, direction)
					p_turn = false
				end
				local _here = pos_pix(tile(self))
				local _next = pos_pix(next_tile)
				local _half = {(_here[1] + _next[1]) / 2, _here[2]-4}
				set_tile(self, next_tile)
				ani_to(self, {_half, _next}, ani_frames/2, 0)
				delay = ani_frames * 1.5
				sfx(sounds.jump, 3)
				p_turn = false

			-- if there's no wall
			elseif not wall then

				-- if shoot is enabled and shoot targets exist
				local shoot_targets = get_ranged_targets(self, direction)
				if self.shoot and #shoot_targets > 0 then
          for next in all(shoot_targets) do
            hit_target(next, 1, direction)
          end
					new_shot(self, direction)
					sfx(sounds.shoot, 3)
					delay = ani_frames * 1.5
					p_turn = false

				-- otherwise, if there's an enemy in the destination, hit it
				elseif enemy then
					hit_target(enemy, 1, direction)
					sfx(sounds.hero_bump, 3)
					local here = pos_pix(tile(self))
					local bump = {here[1] + direction[1] * 4, here[2] + direction[2] * 4}
					ani_to(self, {bump, here}, ani_frames/2, 0)
					delay = ani_frames * 1.5
					p_turn = false

				-- otherwise, move to the destination
				else
					set_tile(self, next_tile)
					ani_to(self, {pos_pix(next_tile)}, ani_frames, 0)
					delay = ani_frames * 1.5
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
		local sprite = self.active and 001 or self.sprite

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
			pal(007, 011)
			pal(006, 011)
			pal(010, 007)
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
			pal(007, 012)
			pal(006, 012)
			pal(010, 007)
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
			pal(010, 007)
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
  _e.sprite = 021
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
      if distance(tile(self),tile(next)) == 1 then
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
    local start = tile(self)
    -- find the closest heroes by ideal distance
    local targets = closest(self, heroes)
    -- if there's more than one
    if #targets > 1 then
      -- find the closest targets by avoid distance
      local alt_targets = closest(self, heroes, {"enemy"})
      -- if any targets can be reached via avoid distance, then they're the targets
      targets = #alt_targets > 0 and alt_targets or targets
    end
    -- pick randomly from what's left
    shuff(targets)
    local target = targets[1]
    -- get possible steps by ideal distance
    local steps = get_steps(start,tile(target))
    -- eliminate any ideal steps that have enemies in them
    for next in all(steps) do
      if find_type("enemy", next) then
        del(steps, next)
      end
    end
    -- if there are now no options, get possible steps by avoid distance
    if #steps == 0 then
      steps = get_steps(start,tile(target),{"enemy"})
    end
    -- if there are still no options, then move randomly
    if #steps == 0 then
      steps = get_random_moves(start)
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
      printh(self:get_step_to_hero())
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
      delay = ani_frames * 1.5
      sfx(sounds.enemy_bump, 3)
    end
  end

  _e.move = function(self)
    if self.step then
      set_tile(self, self.step)
      ani_to(self, {pos_pix(self.step)}, ani_frames, 0)
      delay = ani_frames * 1.5
    end
  end

	_e.draw = function(self)

		local sprite = self.sprite

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
		for x = 1, cols do
			for y = 1, rows do
				local _t = {x,y}
        if
          not find_type("hero", _t) and
          not find_type("enemy", _t) and
          dumb_distance(tile(hero_a), _t) >= 2 and
          dumb_distance(tile(hero_b), _t) >= 2
        then
					add(valid_tiles, _t)
				end
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
  _e.sprite = 021
	_e.health = 1

  _e.get_step = function(self)
    -- if not attacking this turn
    if not self.target then
      local step = self:get_step_to_hero()
      if step then
        if
          distance(step, tile(hero_a)) > 1 and
          distance(step, tile(hero_b)) > 1
        then
          return step
        else
          local dir = get_direction(tile(self), step)
          local _a = pos_pix(tile(self))
          local _b = {_a[1] + dir[1] * 2, _a[2] + dir[2] * 2}
          ani_to(self, {_b,_a}, ani_frames / 2, 0)
        end
      end
    end
  end

  return _e
end

function new_e_dash()
  local _e = new_e()
  _e.sprite = 026
  _e.health = 1
  _e.dir = {0,0}

  _e.get_target = function(self)
    local target
    for dir in all(o_dirs) do
      local _t = get_ranged_targets(self, dir)[1]
      if _t and target then
        local s_t = tile(self)
        local t_t = tile(_t)
        local tar_t = tile(target)
        if distance(s_t,t_t) < distance(s_t,tar_t) then
          target = _t
        end
      elseif _t then
        target = _t
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
    if self.target then
      return tile(self.target)
    else
      return self:get_step_to_hero()
    end
  end

  _e.attack = function(self)
    if self.target then
      hit_target(self.target, 1, self.dir)
      local dest = pos_pix(tile(self.target))
      ani_to(self, {dest}, ani_frames / 2, 0)
      delay = ani_frames * 1.5
      sfx(sounds.enemy_bump, 3)
      self.health = 0
    end
  end

  return _e
end

function new_e_slime()
  local _e = new_e()
  _e.sprite = 022

  _e.move = function(self)
    if self.step then
      set_tile(new_e_baby(), tile(self))
      set_tile(self, self.step)
      ani_to(self, {pos_pix(self.step)}, ani_frames, 0)
      delay = ani_frames * 1.5
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
      delay = ani_frames * 1.5
      sfx(sounds.enemy_bump, 3)
      self.stunned = true
    end
  end

  return _e
end

function new_e_baby()
  local _e = new_e()
	_e.health = 1
  _e.sprite = 023
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
  _e.sprite = 024
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
    local start = tile(self)
    -- find the closest friends by ideal distance
    local friends = self:get_friends()
    friends = closest(self, friends)
    -- if there's more than one
    if #friends > 1 then
      -- find the closest friends by avoid distance
      local alt_friends = closest(self, friends, {"enemy", "hero"})
      -- if any friends can be reached via avoid distance, then they're the friends
      friends = #alt_friends > 0 and alt_friends or friends
    end
    -- pick randomly from what's left
    shuff(friends)
    local friend = friends[1]
    -- get possible steps by ideal distance
    local steps = get_steps(start,tile(friend))
    -- eliminate any ideal steps that have non-friend enemies or heroes in them
    for next in all(steps) do
      local enemy = find_type("enemy", next)
      if (enemy and enemy.sub_type ~= "grow") or find_type("hero", next) then
        del(steps, next)
      end
    end
    -- if there are now no options, get possible steps by avoid distance
    if #steps == 0 then
      steps = get_steps(start,tile(friend),{"enemy","hero"})
    end
    -- if there still no options, or friend is on the same tile
    if
      #steps == 0 or
      pair_equal(start,tile(friend))
    then
      steps = get_random_moves(start)
    end
    if #steps > 0 then
      shuff(steps)
      return steps[1]
    end
  end

  _e.get_step = function(self)
    local friends = self:get_friends()
    -- if there are friends
    if #friends > 0 then
      return self:get_step_to_friend()
    -- if there's no friend and this enemy isn't attacking this turn
    elseif not self.target then
      return self:get_step_to_hero()
    end
  end

  _e.move = function(self)
    if self.step then
      set_tile(self, self.step)
      ani_to(self, {pos_pix(self.step)}, ani_frames, 0)
      delay = ani_frames * 1.5

      local grow_enemies = {}
      for next in all(enemies) do
        if next.sub_type == "grow" then
          add(grow_enemies, next)
        end
      end
      if #grow_enemies > 1 then
        local friends = grow_enemies
        del(friends, self)
        local friends = closest(self, friends, {"hero"})
        local friend = friends[1]
        if pair_equal(tile(self),tile(friend)) then
          self.health = 0
          friend.health = 0
          local big = new_e_grown()
          set_tile(big,tile(self))
        end
      end
    end
  end

  _e.get_target = function(self)
    local grow_enemies = {}
    for next in all(enemies) do
      if next.sub_type == "grow" then
        add(grow_enemies, next)
      end
    end
    if #grow_enemies <= 1 then
      local targets = {}
      for next in all(heroes) do
        if distance(tile(self),tile(next)) == 1 then
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
  end

  _e.deploy = function(self)
    function is_too_close(_t, grow_enemies)
      for next in all(grow_enemies) do
        if
          next.x and
          distance(_t,tile(next)) < 5
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
    for x = 1, cols do
      for y = 1, rows do
        if not is_too_close({x,y}, grow_enemies) then
          add(valid_tiles, {x,y})
        end
      end
    end
    for next in all(valid_tiles) do
      if
        find_type("enemy", next) or
        dumb_distance(tile(hero_a), next) < 2 or
        dumb_distance(tile(hero_b), next) < 2
      then
        del(valid_tiles,next)
      end
    end
    if #valid_tiles > 0 then
      shuff(valid_tiles)
      set_tile(self, valid_tiles[1])
    else
      self:kill()
    end
  end

  return _e
end

function new_e_grown()
  local _e = new_e()
	_e.health = 3
  _e.sprite = 025
  return _e
end

function closest(thing, options, avoid_a)
  local avoid = avoid_a or {}
  local closest = {options[1]}
  local here = tile(thing)

  for i = 2, #options do
    local a = tile(closest[1])
    local a_dist = distance(here, a, avoid)
    local b = tile(options[i])
    local b_dist = distance(here, b, avoid)
    if b_dist < a_dist then
      closest = {options[i]}
    elseif b_dist == a_dist then
      add(closest, options[i])
    end
  end

  return closest
end

function get_steps(start, goal, avoid_a)
  local avoid = avoid_a or {}
  local current_dist = distance(start, goal, avoid)
  local valid_tiles = {}

  for next in all(get_adjacent_tiles(start)) do
    -- local should_avoid = find_types(avoid, next)
    -- local next_dist = distance(next, goal, avoid)
    if
      not find_types(avoid, next) and
      distance(next, goal, avoid) < current_dist
    then
      add(valid_tiles, next)
    end
  end

  return valid_tiles
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

function frames(a, n)
  local n = n or 4
	local b = {}
	for next in all(a) do
		for i = 1, n do
			add(b, next)
		end
	end
	return b
end

function draw_health(x_pos, y_pos, current, threatened, offset)
  -- draw current amount of health in dark red
	for i = 1, current do
		pset(x_pos + offset, y_pos + 10 - i * 3, 002)
		pset(x_pos + offset, y_pos + 9 - i * 3, 002)
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

function ani_to(thing, destinations, frames, wait)

	local s = {}
	local current = thing.pixels[1]

	for i = 1, wait do
		add(s, thing.pixels[1])
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

	thing.pixels = s
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

  -- enter transitions for enemies
	if thing.pixels and #thing.pixels == 0 then
		local _c = pos_pix(dest)
		if thing.type == "enemy" then
			local _x = _c[1]
			local _y = _c[2]
			thing.pixels = frames({{_x,_y-2},{_x,_y-1},_c})
		else
			thing.pixels = {_c}
		end
	end

	-- trigger enemy buttons when they step or are deployed
	if thing.type == "enemy" then
		local _b = find_type("button", tile(thing))
		if _b and (_b.color == 008 or _b.color == 009) then
			_b.charged = true
		end
  -- trigger hero step sounds
	elseif thing.type == "hero" then
    local _b = find_type("button", tile(thing))
		if _b and _b.charged then
      if _b.color == 008 then
        if thing.health < thing.max_health then
          thing.health = min(thing.health + 1, thing.max_health)
          new_num_effect(thing, 1, 008, 007)
        else
          new_num_effect(thing, 0, 008, 007)
        end
      elseif _b.color == 009 then
        score += 1
        new_num_effect({79, 99}, 1, 009, 000)
      end
      _b.charged = false
		end
		if find_type("pad", dest) then
			sfx(sounds.pad_step, 3)
		else
			sfx(sounds.step, 3)
		end
	end
end

-- converts board position to screen pixels
function pos_pix(board_position)
	local board_x = board_position[1]
	local board_y = board_position[2]
	local x_pos = (board_x - 1) * 8 + (board_x - 1) * 7 + 15
	local y_pos = (board_y - 1) * 8 + (board_y - 1) * 7 + 15
	return {x_pos, y_pos}
end

function shuff(t)
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

function trigger_btns()
	for next in all(heroes) do
		local start = next.health
		next.health += t_health
		if next.health > next.max_health then
			next.health = next.max_health
		end
		local diff = next.health - start
		if diff > 0 then
			new_num_effect(next, diff, 008, 007)
			sfx(sounds.health, 3)
		end
	end
	if t_score > 0 then
		score += t_score
		local text = t_score .. ""
		sfx(sounds.score, 3)
		new_num_effect({95 - #text * 4, 99}, t_score, 009, 000)
	end
  t_health = 0
  t_score = 0
end

function new_num_effect(ref, amount, color, outline)
	local new_num_effect = {
    ref = ref, -- position or parent thing
    _x = function(self)
      return #self.ref == 2 and self.ref[1] or self.ref.pixels[1][1]
    end,
    _y = function(self)
      return #self.ref == 2 and self.ref[2] or self.ref.pixels[1][2]
    end,
		pixels = frames({0,-1,-2,-3,-4,-5,-6,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7}, 2),
		draw = function(self)
      local base = {self:_x(),self:_y()+self.pixels[1]}
      local sign = amount >= 0 and "+" or ""
			for next in all(s_dirs) do
        local result = add_pairs(base,next)
        print(sign .. amount, result[1], result[2], outline)
			end
			print(sign .. amount, base[1], base[2], color)
			if #self.pixels > 1 then
				del(self.pixels, self.pixels[1])
			else
				del(effects, self)
			end
			pal()
		end,
	}
	add(effects, new_num_effect)
	return new_num_effect
end

function new_pop(s)

  function new_particle(s)
    local v_x = {.125,-.125,.5,-.5}
    local v_y = copy(v_x)
    shuff(v_x)
    shuff(v_y)
    local _p = {
      s_x = s[1],
      s_y = s[2],
      v_x = v_x[1],
      v_y = v_y[1],
      frames = 18,
      draw = function(self)
        local sprite = 005
        if self.frames < 6 then
          sprite = 006
        end
        palt(015,true)
        spr(sprite,self.s_x,self.s_y)
        self.frames -= 1
        self.s_x += self.v_x
        self.s_y += self.v_y
        if self.frames <= 0 then
          del(particles,self)
        end
        pal()
      end
    }
    add(particles,_p)
  end
  for i=1, 8 do
    new_particle(s)
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

function get_ranged_targets(thing, direction)

	local now_tile = tile(thing)
  local targets = {}

	while true do
		-- define the current target
		local next_tile = {now_tile[1] + direction[1], now_tile[2] + direction[2]}
		-- if `next_tile` is off the map, or there's a wall in the way, return false
		if
			not location_exists(next_tile) or
			is_wall_between(now_tile, next_tile) or
			find_type(thing.type, next_tile)
		then
			return targets
		end
		-- if there's a target in the tile, return it
		local target = find_type(thing.target_type, next_tile)
		if target then
			add(targets,target)
		end
		-- set `current` to `next_tile` and keep going
		now_tile = next_tile
	end
end

function add_pairs(tile,dir)
  return {tile[1] + dir[1], tile[2] + dir[2]}
end

function crosshairs()
  local h = active_hero()
	for next in all(enemies) do
		next.is_target = 0
    if distance(tile(h), tile(next)) == 1 then
      next.is_target = 006
    end
	end
  for d in all(o_dirs) do
    if h.shoot then
      local targets = get_ranged_targets(h, d)
      for next in all(targets) do
        next.is_target = 011
      end
    elseif h.jump then
      local enemy = find_type("enemy", add_pairs(tile(h),d))
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

  -- find the other pad
	local o_p
	for next in all(pads) do
		if
      next ~= find_type("pad", tile(hero_a)) and
      next ~= find_type("pad", tile(hero_b))
    then
			o_p = next
		end
	end

	-- put a button in its position
	set_tile(new_button(o_p.color), {o_p.x, o_p.y})

	-- make the advance sound
	sfx(sounds.advance, 3)
end

-- given an enemy and an amount of damage,
-- hit it and then kill if it has no health
function hit_target(target, damage, direction)
	target.health -= damage
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

-- takes two tiles
function distance(start, goal, avoid_a)
	local avoid = avoid_a or {}
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
					if
						-- make sure it wasn't already added by a different check in the same step
						not array_has_tile(next_frontier, next) and
            -- if tile is `start`, or if it's not `start` but it doesn't contain avoid things
            (pair_equal(next, start) or find_types(avoid, next) == false)
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

function generate_walls()
  -- todo: combine this with the stuff below for creating wall_down
	for i = 1, 12 do
		local wall_right = {
			x = null,
			y = null,
			type = "wall_right",
			draw = function(self)

				palt(0, false)
				local x_pos = (self.x - 1) * 8 + (self.x - 1) * 7 + 15
				local y_pos = (self.y - 1) * 8 + (self.y - 1) * 7 + 15

				local hero_l = find_type("hero", tile(self))
				local hero_r = find_type("hero", {self.x + 1, self.y})

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
			kill = function(self)
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

				local hero_u = find_type("hero", tile(self))
				local hero_d = find_type("hero", {self.x, self.y + 1})

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
			kill = function(self)
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
		colors_bag = {008,008,008,008,008,008,009,011,012}
		shuff(colors_bag)
	end

	-- delete all existing pads
	for next in all(pads) do
		next:kill()
	end

	-- if there are only 5 spaces left, deploy exits
	-- right now i'm thinking it has to be 5 because otherwise pads get spawned below heroes
	-- but i should probably do something to make this more elegant.
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
          -- local sprite = 020
					spr(020, sx, sy)
          pal()
				end,
			}
			add(exits, exit)
			deploy(exit, {"button", "hero", "exit"})
		end
		return
	end

	local _c = {008,009,011,012}
	del(_c, colors_bag[1])

	-- place new pads
	for next in all(_c) do
		local new_pad = new_pad(next)
		deploy(new_pad, {"pad", "button", "hero"})
	end
	del(colors_bag, colors_bag[1])
end

function new_pad(color)
	local new_pad = new_thing()
	new_pad.sprite = 016
	new_pad.type = "pad"
	new_pad.color = color
	new_pad.list = pads
	new_pad.draw = function(self)
		local sprite = self.sprite
		local sx = self.pixels[1][1]
		local sy = self.pixels[1][2]
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
	local _b = new_thing()

  _b.sprites = {016,016,016,016,017,017,017,017,018}
	_b.type = "button"
	_b.color = color
	_b.list = buttons
  _b.charged = false
	_b.draw = function(self)
		local sprite = self.sprites[1]
		local sx = self.pixels[1][1]
		local sy = self.pixels[1][2]
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
    if self.charged then
      spr(019,sx,sy-1)
    end
		spr(sprite, sx, sy)
		self:end_draw()
    if #self.sprites > 1 then
      del(self.sprites,self.sprites[1])
    end
	end

	add(buttons, _b)
	return _b
end

__gfx__
ffffffffff000fffffffffffffffffffffffffffffffffffffffffff000006070060006000060600000700600000000000000000000000000000000000000000
ffffffffff070ffffff6fffffffaaaffffffffffffffffffffffffff600600076000000000600006006006000000000000000000000000000000000000000000
ff000fff0007000ffff6ffffffaa6affffa6afffffffffffffffffff006006070006060006006060060000060000000000000000000000000000000000000000
0007000f0777770fffffffffff6aa6fffaaaaafffff6ffffffffffff000060070060006000060000000060000000000000000000000000000000000000000000
0777770f0007000f66fff66fffaa6afffa6a6affff666ffffff6ffff006006076000600006000606006000600000000000000000000000000000000000000000
0007000ff07070fffffffffffffaaafffaa6aafffff6ffffffffffff600600070606060600060000060006000000000000000000000000000000000000000000
f07070fff07070fffff6ffffffffffffffffffffffffffffffffffff000006070000000000600607000600070000000000000000000000000000000000000000
f00000fff00000fffff6ffffffffffffffffffffffffffffffffffff060060077777777706006007000006070000000000000000000000000000000000000000
fffffffffffffffffffffffffff66fffffffffffffffffffffffffffffffffffffffffff000000ffffffffff0000000000000000000000000000000000000000
ffffffffffffffffffffffffff6ff6ffeeeeeeee00000fffffffffffffffffff000000ff077770ffffffffff0000000000000000000000000000000000000000
fffffffffffffffffffffffffff66fffeffffffe07070ffff0000fffffffffff077770ff007070ff000000ff0000000000000000000000000000000000000000
f66ff66fffffffffff6666ffffffffffefeeeefe070700ff077770fff0000fff007070ff077770ff077770ff0000000000000000000000000000000000000000
f6ffff6fff6666fff666666fffffffffefeffefe077770ff077770ff077770ff0777700f0077700f007070ff0000000000000000000000000000000000000000
fffffffff666666ff666666fffffffffefeeeefe007070ff0070700f007070ff0077770ff077770f0777770f0000000000000000000000000000000000000000
f6ffff6ff666666ff566665fffffffffeffffffe077770ff0777770f077770fff070700ff070700f0707070f0000000000000000000000000000000000000000
f66ff66fff6666ffff5555ffffffffffeeeeeeee000000ff0000000f000000fff00000fff00000ff0000000f0000000000000000000000000000000000000000
00000000bbbb00000000000000b00000000000000000000000000000000000099990000000000000000000000000000000000000000000000000000000000000
0070000bbbbbb0000000000000b00000000000000000000000000000000000999999000000000000000000000000000000000000000000000000000000000000
7777700bbbbbb00007770000bbbbb000770707007700770777000000777700999999000077700007770077070007700000000000000000000000000000000000
00700003bbbb30000000000000b00007000707070707070070000000070700499994000000000007000707070007070000000000000000000000000000000000
0707000333333000077700000b0b0000070777070707070070000000777700444444000077700007070707070007070000000000000000000000000000000000
0000000033330000000000000b0b0007700707077007700070000000077000044440000000000007770770077707700000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0000fffff0000fff000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
077770fff077770ff077770f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070700f0007070ff007070f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777770f0777770ff077770f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0707070f0707070f0070070f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0707070f0707070f0770770f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000f0000000f0000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

