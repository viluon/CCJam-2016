
-- Gravity Gal, a Gravity Guy clone by @viluon

-- Built with [BLittle](http://www.computercraft.info/forums2/index.php?/topic/25354-cc-176-blittle-api/)
if not fs.exists "blittle" then shell.run "pastebin get ujchRSnU blittle" end
os.loadAPI "blittle"

local logfile = io.open( "/log.txt", "a" )

local SPEED = -20
local AIR_DENSITY = 1.225
local DRAG_COEFFICIENT = 1.05

local old_term = term.current()
local parent_window = window.create( old_term, 1, 1, old_term.getSize() )
local main_window = blittle.createWindow( parent_window )

local	draw, draw_player, update_player, round

term.redirect( main_window )
local w, h = term.getSize()

local camera_offset = {
	x = 0;
	y = 0;
}

local local_player = {
	mass = 40;
	height = 3;
	width = 2;

	colour = colours.blue;

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

local level = {}
local players = { local_player }

--- Rounds a number to a set amount of decimal places
-- @param n The number to round
-- @param places The number of decimal places to keep
-- @return The result
function round( n, places )
	local mult = 10 ^ ( places or 0 )
	return math.floor( n * mult + 0.5 ) / mult
end

--- Draw a player
-- @param player The player to draw
-- @return nil
function draw_player( player )
	term.setBackgroundColor( player.colour )

	for y = -player.height, 0 do
		term.setCursorPos( player.position.x + camera_offset.x, h - player.position.y + y + camera_offset.y )
		term.write( ( " " ):rep( player.width ) )
	end
end

--- Update a player
-- @param player The player to update
-- @return nil
function update_player( player, dt )
	if player.dead then
		return
	end

	if player.position.y > h or player.position.y + player.height + 1 < 0 then
		player.dead = true
		return
	end

	-- Check for a collision
	for i, obj in ipairs( level ) do
		if ( player.position.x > obj.x and player.position.x < obj.x + obj.width ) or ( player.position.x + player.width > obj.x and player.position.x + player.width < obj.x + obj.width ) or ( player.position.x < obj.x and player.position.x + player.width > obj.x + obj.width ) then
			if ( player.position.y > obj.y and player.position.y < obj.y + obj.height ) or ( player.position.y - player.height < obj.y and player.position.y - player.height > obj.y - obj.height ) or ( player.position.y < obj.y and player.position.y + player.height > obj.y + obj.height ) then
				-- Resolve the collision
				player.velocity.y = 0
				player.position.y = math[ player.speed < 0 and "max" or "min" ]( player.position.y, obj.y + player.height )

			end
		end
	end

	-- Actually update the player
	player.velocity.x = player.velocity.x

	player.velocity.y = player.speed

	player.position.x = player.position.x + player.velocity.x * dt
	player.position.y = player.position.y + player.velocity.y * dt
end

--- Render the view
-- @return nil
function draw()
	-- Draw the background
	term.setBackgroundColor( colours.lightBlue )
	term.clear()

	-- Draw the level
	for i, obj in ipairs( level ) do
		obj:draw()
	end

	-- Draw the players
	for i, player in ipairs( players ) do
		draw_player( player )
	end
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
		if ev[ 2 ] == keys.space then
			players[ 1 ].speed = -players[ 1 ].speed
		end

	elseif ev[ 1 ] == "char" then
		if ev[ 2 ] == "q" then
			running = false
		end

	elseif ev[ 1 ] == "terminate" then
		running = false

	elseif ev[ 1 ] == "end" then
		end_queued = false
	end

	-- Update players
	for i, player in ipairs( players ) do
		update_player( player, dt )
	end

	draw()

	main_window.setVisible( true )

	-- Do overlay stuff here
	parent_window.setCursorPos( 1, 1 )
	parent_window.write( players[ 1 ].velocity.y )

	parent_window.setCursorPos( 1, 2 )
	parent_window.write( players[ 1 ].dead )

	parent_window.setVisible( true )

	last_time = now
end

term.redirect( old_term )
term.setCursorPos( 1, 1 )

logfile:close()
