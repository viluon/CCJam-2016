
-- Gravity Gal, a Gravity Guy clone by @viluon

-- Built with [BLittle](http://www.computercraft.info/forums2/index.php?/topic/25354-cc-176-blittle-api/)
if not fs.exists "blittle" then shell.run "pastebin get ujchRSnU blittle" end
os.loadAPI "blittle"

local logfile = io.open( "/log.txt", "a" )

local GRAVITY = -10

local old_term = term.current()
local parent_window = window.create( old_term, 1, 1, old_term.getSize() )
local main_window = blittle.createWindow( parent_window )

local	draw, draw_player

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
		x = 6;
		y = h / 2;
	};

	gravity = GRAVITY;
}

local level = {}
local players = { local_player }

--- Draw a player
-- @param player The player to draw
-- @return nil
function draw_player( player )
	term.setBackgroundColor( player.colour )

	for y = -player.height, 0 do
		term.setCursorPos( player.position.x + camera_offset.x, player.position.y + y + camera_offset.y )
		term.write( ( " " ):rep( player.width ) )
	end
end

--- Update a player
-- @param player The player to update
-- @return nil
function update_player( player )
	if player.dead then
		return
	end

	
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
		
	elseif ev[ 1 ] == "char" then
		if ev[ 2 ] == "q" then
			running = false
		end

	elseif ev[ 1 ] == "terminate" then
		running = false
	end

	-- Update players
	for i, player in ipairs( players ) do
		update_player( player )
	end

	draw()

	main_window.setVisible( true )
	-- Do overlay stuff here
	parent_window.setVisible( true )
end

term.redirect( old_term )
term.setCursorPos( 1, 1 )

logfile:close()
