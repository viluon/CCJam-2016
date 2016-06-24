
-- Gravity Gal, a Gravity Guy clone by @viluon

-- Built with [BLittle](http://www.computercraft.info/forums2/index.php?/topic/25354-cc-176-blittle-api/)
if not fs.exists "blittle" then shell.run "pastebin get ujchRSnU blittle" end
os.loadAPI "blittle"

local logfile = io.open( "/log.txt", "a" )

local GRAVITY = -10

local old_term = term.current()
local parent_window = window.create( old_term, 1, 1, old_term.getSize() )
local main_window = blittle.createWindow( parent_window )

term.redirect( main_window )
local w, h = term.getSize()

local local_player = {
	mass = 40;
	height = 3;
	width = 2;

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

--- Render the view
-- @return nil
local function draw()
	-- Draw the background
	term.setBackgroundColor( colours.lightBlue )

	-- Draw the level
	for i, obj in ipairs( level ) do
		obj:draw()
	end

	-- Draw the players
	for i, player in ipairs( players ) do
		player:draw()
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

	draw()

	main_window.setVisible( true )
	-- Do overlay stuff here
	parent_window.setVisible( true )
end

term.redirect( old_term )
logfile:close()
