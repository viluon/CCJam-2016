
-- Gravity Girl, a Gravity Guy clone by @viluon

local arguments = ( { ... } )[ 1 ]

local GAME_CHANNEL = arguments.GAME_CHANNEL
local ENABLE_LOGGING = arguments.ENABLE_LOGGING
local PARTICLE_SPACING_VERTICAL = 9
local PARTICLE_SPACING_HORIZONTAL = 5.9
local LOADING_HINT_SHOW_TIME = 6
local GAME_INFO_REQUEST_INTERVAL = 2
local PLAYER_PING_INTERVAL = 2
local PLAYER_TIMEOUT = 4
local SPEED = -30

arguments.SPEED = SPEED

local directory = fs.getDir( shell.getRunningProgram() )
local logfile = arguments.logfile

local launch_settings = arguments.launch_settings
local secret_settings = arguments.secret_settings
local modem = arguments.modem
local selected_game = arguments.selected_game

local	launch, setting, randomize_loading_hint, draw_background, update_particles, draw_loading_hint, log, request_game_info,
		ping_players, list_players

local old_term = term.current()
local parent_window = window.create( old_term, 1, 1, old_term.getSize() )

local width, height = parent_window.getSize()

local hint_start_y = math.floor( ( 2 / 3 ) * height ) + 2
local hint_window = window.create( parent_window, 2, hint_start_y, width - 2, math.ceil( height / 3 ) )
local main_window = blittle.createWindow( parent_window )

term.redirect( main_window )
local w, h = term.getSize()

local particles = {}

local local_player = {
	ID = os.getComputerID();

	height = 3;
	width = 2;

	name = launch_settings[ 2 ].value;
	colour = launch_settings[ 3 ].options[ launch_settings[ 3 ].value ] or colours.blue;

	velocity = {
		x = 0;
		y = 0;
	};
	
	position = {
		x = 12;
		y = h / 2;
	};

	speed = SPEED;
}

local players = { local_player }
local n_players = selected_game and selected_game.connected + 1 or 1
local total_players

arguments.local_player = local_player
arguments.players = players

local local_game

if not arguments.selected_game then
	local_game = tostring( {} ) .. math.random( 1, 2 ^ 10 )
	arguments.local_game = local_game
else
	local_game = arguments.selected_game.game_ID
	modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
		Gravity_Girl = "best game ever";
		type = "game_join";

		game_ID = local_game;
		sender = local_player;
		data = local_player;
	} )
end

local f = io.open( directory .. "/loading_hints.tbl", "r" )
local contents = f:read( "*a" )
f:close()
local loading_hints = textutils.unserialise( contents )
local current_loading_hint = 1

--- Switch to a random (different) loading hint
-- @return nil
function randomize_loading_hint()
	local old_hint = current_loading_hint
	local c = 0

	while old_hint == current_loading_hint and c < 10 do
		current_loading_hint = math.random( 1, #loading_hints )
		c = c + 1
	end
end

--- Write to the log file
-- @param ... The data to write
-- @return nil
function log( ... )
	if not ENABLE_LOGGING then return end

	logfile:write( table.concat( { ... } ) .. "\n" )
	logfile:flush()
end

local last_game_info_request = -1
--- Ask for an update on the pre-game state
-- @param now Current clock time
-- @return nil
function request_game_info( now )
	if selected_game and now - last_game_info_request > GAME_INFO_REQUEST_INTERVAL then
		last_game_info_request = now
		modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
			Gravity_Girl = "best game ever";
			type = "game_info_request";

			game_ID = local_game;
			sender = local_player;
		} )
	end
end

local last_players_ping = -1
--- Ping connected players to see whether they are still online
-- @param now Current clock time
-- @return nil
function ping_players( now )
	if not selected_game and now - last_players_ping > PLAYER_PING_INTERVAL then
		last_players_ping = now
		modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
			Gravity_Girl = "best game ever";
			type = "ping";

			game_ID = local_game;
			sender = local_player;
		} )
	end
end

--- List connected players
-- @return nil
function list_players()
	-- List connected players
	local c = 0
	for id, player in pairs( players ) do
		term.setBackgroundColour( colours.black )
		term.setCursorPos( 0.15 * width, 5 + c )
		term.write( player.name )

		term.setCursorPos( 0.85 * width, 5 + c )
		term.setBackgroundColour( player.colour )
		term.write( "  " )
		c = c + 1
	end

	-- Fill the rest of the player list with empty slots
	for i = n_players, total_players - 1 do
		term.setBackgroundColour( colours.black )
		term.setTextColour( colours.grey )
		term.setCursorPos( 0.15 * width, 5 + i )
		term.write( "Empty slot" )

		term.setCursorPos( 0.85 * width, 5 + i )
		term.write( "\127\127" )
	end
end

--- Render the background
-- @return nil
function draw_background()
	term.setBackgroundColour( colours.black )
	term.clear()

	for i, particle in ipairs( particles ) do
		term.setCursorPos( particle.x, 4 * ( math.sin( particle.x + 2 * os.clock() ) + 0.8 ) + particle.y )
		term.setBackgroundColour( colours.grey )
		term.write( " " )
	end
end

--- Print the current loading hint to the screen
-- @return nil
function draw_loading_hint()
	term.setBackgroundColour( colours.grey )

	for y = hint_start_y, height do
		term.setCursorPos( 1, y )
		term.write( " " )
		term.setCursorPos( width, y )
		term.write( " " )
	end

	term.setCursorPos( 1, height )
	term.clearLine()

	term.redirect( hint_window )

	term.setBackgroundColour( colours.grey )
	term.setTextColour( colours.white )
	term.clear()
	term.setCursorPos( 1, 2 )

	print( loading_hints[ current_loading_hint ] )
end

--- Launch the actual game
-- @return nil
function launch()
	local f = io.open( directory .. "/main.lua", "r" )
	local contents = f:read( "*a" )
	f:close()

	local fn, err = loadstring( contents, "main.lua" )
	if not fn then
		error( err, 0 )
	end

	setfenv( fn, getfenv() )

	term.redirect( old_term )

	return fn( arguments )
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

-- Prepare particles
for y = 1, hint_start_y * 3, PARTICLE_SPACING_VERTICAL do
	for x = 1, w, PARTICLE_SPACING_HORIZONTAL do
		particles[ #particles + 1 ] = { x = x; y = y; }
	end
end

local heading = "Waiting for Players"

local loading_hint_changed = -1
local last_time = os.clock()
local end_queued = false
local running = true
local time_left = 5
local last_seen_server = last_time

total_players = selected_game and selected_game.max or setting "Number of Players"

while n_players < total_players do
	parent_window.setVisible( false )
	hint_window.setVisible( true )
	main_window.setVisible( false )

	if not end_queued then
		os.queueEvent( "end" )
		end_queued = true
	end

	local ev = { coroutine.yield() }
	local now = os.clock()
	local dt = now - last_time

	if ev[ 1 ] == "end" then
		end_queued = false

	elseif ev[ 1 ] == "modem_message" then
		--log( "wait for players received message:", textutils.serialise( ev ) )

		local message = ev[ 5 ]

		if not selected_game and n_players < total_players then
			if message.type == "game_lookup" then
				modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
					Gravity_Girl = "best game ever";
					type = "game_lookup_response";

					game_ID = local_game;
					sender = local_player;
					data = {
						connected = n_players;
						max = total_players;
					};
				} )

			elseif message.type == "game_join" then
				message.data.last_seen = now
				players[ message.data.ID ] = message.data
				n_players = n_players + 1
			end
		end

		if selected_game and message.type == "game_info" then
			last_seen_server = now

			if message.game_ID == selected_game.game_ID then
				players = message.data.players
				n_players = message.data.n_players
			end

		elseif selected_game and message.type == "ping" then
			last_seen_server = now

			if message.game_ID == selected_game.game_ID then
				modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
					Gravity_Girl = "best game ever";
					type = "pong";

					sender = local_player;
					game_ID = local_game;
				} )
			end

		elseif not selected_game and message.type == "game_info_request" then
			if message.game_ID == local_game then
				modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
					Gravity_Girl = "best game ever";
					type = "game_info";

					game_ID = local_game;

					data = {
						players = players;
						n_players = n_players;
					};
				} )
			end

		elseif not selected_game and message.type == "pong" then
			if message.game_ID == local_game then
				-- Find the sender among the players
				for _, player in pairs( players ) do
					if player.ID == message.sender.ID then
						player.last_seen = now
						break
					end
				end
			end
		end

	elseif ev[ 1 ] == "char" then
		if ev[ 2 ] == "q" then
			error()
		end
	end

	-- Update loading hint
	if now - loading_hint_changed > LOADING_HINT_SHOW_TIME then
		randomize_loading_hint()
		loading_hint_changed = now
	end

	-- Ask for game_info
	request_game_info( now )

	-- Check that connected players are still online
	ping_players( now )

	if not selected_game then
		-- Remove players that weren't seen for a long time
		local to_remove = {}

		for _, player in pairs( players ) do
			if player.ID ~= local_player.ID and now - player.last_seen > PLAYER_TIMEOUT then
				to_remove[ #to_remove + 1 ] = player
			end
		end

		for _, p in ipairs( to_remove ) do
			for i, player in pairs( players ) do
				if player.ID == p.ID then
					players[ i ] = nil
					n_players = n_players - 1
					break
				end
			end
		end
	end

	draw_background()

	main_window.setVisible( true )

	-- Overlay stuff
	term.redirect( parent_window )

	local text = "(" .. n_players .. "/" .. total_players .. ")"

	term.setBackgroundColour( colours.black )
	term.setTextColour( colours.lightGrey )
	term.setCursorPos( width / 2 - #text / 2, 3 )
	term.write( text )

	term.setTextColour( colours.white )
	term.setCursorPos( width / 2 - #heading / 2, 2 )
	term.write( heading )

	list_players()
	draw_loading_hint()

	hint_window.setVisible( true )
	parent_window.setVisible( true )
	term.redirect( main_window )

	last_time = now
end

while time_left > 0 do
	parent_window.setVisible( false )
	hint_window.setVisible( true )
	main_window.setVisible( false )

	if not end_queued then
		os.queueEvent( "end" )
		end_queued = true
	end

	local ev = { coroutine.yield() }
	local now = os.clock()
	local dt = now - last_time

	if ev[ 1 ] == "end" then
		end_queued = false

	elseif ev[ 1 ] == "modem_message" then
		--log( "wait for players received message:", textutils.serialise( ev ) )

		local message = ev[ 5 ]

		if selected_game and message.type == "game_info" then
			if message.game_ID == selected_game.game_ID then
				players = message.data.players
				n_players = message.data.n_players
			end

		elseif not selected_game and message.type == "game_info_request" then
			if message.game_ID == local_game then
				modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
					Gravity_Girl = "best game ever";
					type = "game_info";

					game_ID = local_game;

					data = {
						players = players;
						n_players = n_players;
					};
				} )
			end
		end
	end

	-- Update loading hint
	if now - loading_hint_changed > LOADING_HINT_SHOW_TIME then
		randomize_loading_hint()
		loading_hint_changed = now
	end

	-- Ask for game_info
	request_game_info( now )

	draw_background()

	main_window.setVisible( true )

	-- Overlay stuff
	term.redirect( parent_window )

	time_left = time_left - dt
	local counter = "Game will start in " .. math.ceil( time_left )

	term.setBackgroundColour( colours.black )
	term.setTextColour( colours.white )
	term.setCursorPos( width / 2 - #counter / 2, 2 )
	term.write( counter )

	list_players()
	draw_loading_hint()

	hint_window.setVisible( true )
	parent_window.setVisible( true )
	term.redirect( main_window )

	last_time = now
end

pcall( logfile.close, logfile )
return launch()
