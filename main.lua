
-- Gravity Girl, a Gravity Guy clone by @viluon

-- Built with [BLittle](http://www.computercraft.info/forums2/index.php?/topic/25354-cc-176-blittle-api/) by Bomb Bloke
if not fs.exists "blittle" then shell.run "pastebin get ujchRSnU blittle" end
if not blittle then os.loadAPI "blittle" end
-- and [bump.lua](https://github.com/kikito/bump.lua) by kikito
local bump = dofile "bump.lua"
local logfile = io.open( "/log.txt", "a" )

local arguments = ( { ... } )[ 1 ]

local GAME_CHANNEL = arguments.GAME_CHANNEL
local SPEED = arguments.SPEED
local ENABLE_LOGGING = true
local INITIAL_SCROLL_SPEED = 2
local PLAYER_BASIC_H_SPEED = 10
local PLAYER_H_SPEED = 5
local PLAYER_REFRESH_INTERVAL = 0.2

local old_term = term.current()
local parent_window = window.create( old_term, 1, 1, old_term.getSize() )
local main_window = blittle.createWindow( parent_window, nil, nil, nil, nil, false )

local	draw, draw_player, update_player, round, log, deepcopy, draw_background, setting, refresh_players

local condition

term.redirect( main_window )
local w, h = term.getSize()

local world = bump.newWorld()

local launch_settings = arguments.launch_settings
local secret_settings = arguments.secret_settings
local modem = arguments.modem
local selected_game = arguments.selected_game
local local_player = arguments.local_player
local local_game = arguments.local_game

local broadcast = not selected_game

local furthest_block_generated = -1

local camera_offset = {
	x = 0;
	y = 0;
}

local level = {}
local segments = {}
local backgrounds = {}

local directory = fs.getDir( shell.getRunningProgram() )
local segments_dir = directory .. "/level_segments/"
local backgrounds_dir = directory .. "/backgrounds/"

for i, name in ipairs( fs.list( segments_dir ) ) do
	local f = io.open( segments_dir .. name, "r" )
	local contents = f:read( "*a" )
	f:close()

	segments[ i ] = textutils.unserialise( contents )
	
	local max_width = -1

	for _, block in ipairs( segments[ i ] ) do
		max_width = math.max( max_width, block.x + block.width )
	end

	segments[ i ].total_width = max_width
end

local starters = {}
local starter

if broadcast then
	for i, segment in ipairs( segments ) do
		if segment.starter then
			starters[ #starters + 1 ] = segment
		end
	end

	if #starters == 0 then
		error( "No starter segment found", 0 )
	end

	starter = starters[ math.random( 1, #starters ) ]

	modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
		Gravity_Girl = "best game ever";
		type = "starter";

		game_ID = local_game;
		sender = local_player;
		data = starter;
	} )
else
	local received

	while not received do
		local ev = { coroutine.yield( "modem_message" ) }

		local message = ev[ 5 ]

		if ev[ 3 ] == GAME_CHANNEL and type( message ) == "table" and message.Gravity_Girl == "best game ever" and message.game_ID == local_game then
			received = true
			starter = message.data
		end
	end
end

furthest_block_generated = starter.total_width

for i, obj in ipairs( starter ) do
	world:add( obj, obj.x, obj.y, obj.width, obj.height )
	level[ #level + 1 ] = obj
end

local last_segment = starter

local players = arguments.players
local n_players = arguments.n_players

--- Write to the log file
-- @param ... The data to write
-- @return nil
function log( ... )
	if not ENABLE_LOGGING then return end

	logfile:write( table.concat( { ... } ) .. "\n" )
	logfile:flush()
end

function deepcopy( orig )
	local orig_type = type( orig )
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[ deepcopy( orig_key ) ] = deepcopy( orig_value )
		end
		setmetatable( copy, deepcopy( getmetatable( orig ) ) )
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

--- Rounds a number to a set amount of decimal places
-- @param n The number to round
-- @param places The number of decimal places to keep
-- @return The result
function round( n, places )
	local mult = 10 ^ ( places or 0 )
	return math.floor( n * mult + 0.5 ) / mult
end

--- Get the value of a setting by name
-- @param name	The name of the setting to search for
-- @return any	The value of the setting, either a string when it's a string setting,
--				or the value of the setting's options table at the index of setting.value.
--				Errors when the setting wasn't found.
function setting( name )
	for i, setting in ipairs( launch_settings ) do
		if setting.name:lower() == name:lower() then
			if setting.options then
				return setting.options[ setting.value ]
			else
				return setting.value
			end
		end
	end

	error( "No setting of name '" .. name .. "' was found.", 2 )
end

local last_player_refresh = -1
--- Send updated player data to connected clients
-- @param now The current time
-- @return nil
function refresh_players( now )
	if broadcast and now - last_player_refresh > PLAYER_REFRESH_INTERVAL then
		last_player_refresh = now
		modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
			Gravity_Girl = "best game ever";
			type = "player_refresh";

			game_ID = local_game;
			sender = local_player;
			data = players;
		} )
	end
end

--- Draw a player
-- @param player The player to draw
-- @return nil
function draw_player( player )
	term.setBackgroundColor( player.colour )

	for y = -player.height, 0 do
		term.setCursorPos( round( player.position.x + camera_offset.x ), round( h - player.position.y + y + camera_offset.y ) )
		term.write( ( " " ):rep( player.width ) )
	end
end

--- Render an object
-- @param obj The object to render
-- @return nil
function draw_object( obj )
	term.setBackgroundColor( obj.colour )

	for y = -obj.height, 0 do
		term.setCursorPos( round( obj.x + camera_offset.x ), round( h - obj.y + y + camera_offset.y ) )
		term.write( ( " " ):rep( obj.width ) )
	end
end

--- Update a player
-- @param player The player to update
-- @tparam number dt Delta time, time passed since last update
-- @return nil
function update_player( player, dt )
	if player.dead then
		return
	end

	if player.position.y > h or player.position.y + player.height + 1 < 0 or player.position.x + camera_offset.x < 0 then
		player.dead = true
		world:remove( player.ID )

		return
	end

	-- Actually update the player
	player.velocity.x = PLAYER_BASIC_H_SPEED + ( 1 - ( player.position.x + camera_offset.x ) / w ) * PLAYER_H_SPEED
	player.velocity.y = player.speed

	player.position.x, player.position.y = world:move( player.ID, player.position.x + player.velocity.x * dt, player.position.y + player.velocity.y * dt )

	local x, y, collisions, n_collisions = world:check( player.ID, player.position.x, player.position.y + player.velocity.y * 0.01 )

	if n_collisions > 0 then
		player.can_switch = true
	else
		player.can_switch = false
	end
end

--- Render the backgrounds
-- @return nil
function draw_background()
	local x = 0
	for i, bg in ipairs( backgrounds ) do
		paintutils.drawImage( bg.data, camera_offset.x + x, 1 )
		x = x + bg.width
	end
end

--- Render the view
-- @return nil
function draw()
	-- Draw the background
	term.setBackgroundColor( colours.lightBlue )
	term.clear()

	draw_background()

	-- Draw the level
	for i, obj in ipairs( level ) do
		draw_object( obj )
	end

	-- Draw the players
	for i, player in pairs( players ) do
		draw_player( player )
	end
end

-- Place players at their appropriate spawn locations
local index
for i, position in ipairs( starter.player_positions ) do
	index = next( players, index )

	if i > n_players or not index then break end

	players[ index ].position = position
	players[ index ].speed = players[ index ].speed * position.direction
end

-- Register the players for collision detection
for i, player in pairs( players ) do
	world:add( player.ID, player.position.x, player.position.y, player.width, player.height )
end

local last_time = os.clock()
local end_queued = false
local running = true

while running do
	parent_window.setVisible( false )
	main_window.setVisible( false )

	if not end_queued then
		os.queueEvent( "end" )
		end_queued = true
	end

	local ev = { coroutine.yield() }
	local now = os.clock()
	local dt = now - last_time

	if ev[ 1 ] == "key" then
		if ev[ 2 ] == keys.space and local_player.can_switch then
			local_player.speed = -local_player.speed

			modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
				Gravity_Girl = "best game ever";
				type = "player_update";

				game_ID = local_game;
				sender = local_player;
				data = local_player;
			} )
		end

	elseif ev[ 1 ] == "char" then
		if ev[ 2 ] == "q" then
			running = false
		elseif ev[ 2 ] == "f" then
			log( now )
			log( textutils.serialise( players ) )
		end

	elseif ev[ 1 ] == "terminate" then
		running = false

	elseif ev[ 1 ] == "end" then
		end_queued = false

	elseif ev[ 1 ] == "modem_message" then
		if ev[ 3 ] == GAME_CHANNEL then
			local message = ev[ 5 ]

			if type( message ) == "table" and message.Gravity_Girl == "best game ever" and message.sender and message.sender.ID ~= local_player.ID then
				if message.game_ID == local_game then
					if message.type == "player_update" then
						if not world:hasItem( message.data.ID ) then
							world:add( message.data.ID, message.data.position.x, message.data.position.y, message.data.width, message.data.height )
						else
							world:update( message.data.ID, message.data.position.x, message.data.position.y )
						end

						players[ message.data.ID ] = message.data

					--[[
						elseif message.type == "player_refresh" then
							players = message.data

							for i, player in pairs( message.data ) do
								if player.ID ~= local_player.ID then
									if world:hasItem( player.ID ) then
										--world:update( player.ID, player.position.x, player.position.y )
									else
										world:add( player.ID, player.position.x, player.position.y, player.width, player.height )
									end

									players[ i ] = player
								else
									players[ local_player.ID ] = local_player
								end
							end
					--]]

					elseif message.type == "world_update_add" then
						world:add( message.data, message.data.x, message.data.y, message.data.width, message.data.height )
						level[ #level + 1 ] = message.data
					end
				end
			end
		end
	end

	if broadcast then
		--refresh_players( now )

		-- Generate environment
		while furthest_block_generated < w - camera_offset.x do
			local possible_follow_ups = {}

			for _, segment_type in ipairs( last_segment.follow_up ) do
				for i, segment in ipairs( segments ) do
					if segment.type == segment_type and not possible_follow_ups[ segment ] then
						possible_follow_ups[ segment ] = true
						possible_follow_ups[ #possible_follow_ups + 1 ] = segment
					end
				end
			end

			local follow_up = possible_follow_ups[ math.random( 1, #possible_follow_ups ) ]

			for i, obj in ipairs( follow_up ) do
				local obj = deepcopy( obj )
				obj.x = obj.x + furthest_block_generated

				if broadcast then
					modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
						Gravity_Girl = "best game ever";
						type = "world_update_add";

						game_ID = local_game;
						sender = local_player;
						data = obj;
					} )
				end

				world:add( obj, obj.x, obj.y, obj.width, obj.height )
				level[ #level + 1 ] = obj
			end

			furthest_block_generated = furthest_block_generated + follow_up.total_width
			last_segment = follow_up
		end
	end

	-- Update players
	local furthest_right = -1
	local alive = 0

	for i, player in pairs( players ) do
		update_player( player, dt )
		furthest_right = math.max( furthest_right, player.position.x )

		if not player.dead then
			alive = alive + 1
		end
	end

	if furthest_right + camera_offset.x > ( 2 / 3 ) * w then
		camera_offset.x = ( 2 / 3 ) * w - furthest_right
	end

	draw()

	main_window.setVisible( true )

	-- Do overlay stuff here
	parent_window.setCursorPos( 1, 1 )
	parent_window.write( local_player.velocity.y )

	parent_window.setCursorPos( 1, 2 )
	parent_window.write( local_player.dead and "dead" or "alive" )

	parent_window.setCursorPos( 1, 3 )
	parent_window.write( condition )

	parent_window.setVisible( true )

	last_time = now
end

term.redirect( old_term )
term.setCursorPos( 1, 1 )

logfile:close()
