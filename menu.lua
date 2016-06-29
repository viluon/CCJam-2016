
-- Gravity Gal, a Gravity Guy clone by @viluon

-- Built with [BLittle](http://www.computercraft.info/forums2/index.php?/topic/25354-cc-176-blittle-api/) by Bomb Bloke
if not fs.exists "blittle" then shell.run "pastebin get ujchRSnU blittle" end
if not blittle then os.loadAPI "blittle" end

local math = math
local term = term

local old_term = term.current()
local parent_window = window.create( old_term, 1, 1, old_term.getSize() )
local main_window = blittle.createWindow( parent_window )

term.redirect( main_window )
local w, h = term.getSize()
local width, height = parent_window.getSize()

local	random_fill, draw_menu, play

local logo = {
	"   xxxx                      x    x               xxxx         x  ";
	"  x                               x              x             x  ";
	"  x  xx  x xx   xxx   x   x  x   xxx   x    x    x  xx   xxx   x  ";
	"  x   x  xx  x     x  x   x  x    x    x    x    x   x      x  x  ";
	"  x   x  x      xxxx  x   x  x    x    x    x    x   x   xxxx  x  ";
	"  x   x  x     x   x   x x   x    x     xxxxx    x   x  x   x  x  ";
	"   xxx   x      xxxx    x    x     x        x     xxx    xxxx   x ";
	"                                       xxxxx                      ";
	"                                                                  ";
	"                                                                  ";
	"                                                                  ";
}

local background_window = blittle.createWindow( parent_window, 1, 3, #logo[ 1 ] / 2, #logo / 3 )

local menu = {
	{
		relative_position = 0;
		target_position = 0;
		name = "Play";
		
		fn = function()
			return play()
		end;
	};

	{
		relative_position = 0;
		target_position = 0;
		name = "Exit";
		
		fn = function()
			error()
		end;
	};
}

local last_pass = -1
--- Fills the background with random crap
-- @return nil
function random_fill()
	local dt = os.clock() - last_pass

	if dt > 0.001 then
		term.setBackgroundColor( colours.black )
		term.scroll( -1 * dt )

		for y = 1, 1 do
			--term.clearLine()

			for x = 1, w * 0.05 do
				--if math.random() > 0.95 then
					term.setCursorPos( math.random( 3, w - 1 ), y )
					term.setBackgroundColor( colours.grey )
					term.write( " " )
				--end
			end
		end
		
		last_pass = os.clock()
	end
end

--- Draws the menu elements
-- @return nil
function draw_menu()
	parent_window.setBackgroundColor( colours.black )
	parent_window.setTextColor( colours.white )

	for i, element in ipairs( menu ) do
		parent_window.setCursorPos( width / 2 - #element.name / 2, height / 2 - #menu + i * 2 )
		parent_window.write( element.name )
	end
end

--- Starts the game
-- @param  description
-- @return nil
function play()
	local f = io.open( "menu.lua", "r" )
	local contents = f:read( "*a" )
	f:close()

	local fn, err = loadstring( contents, "menu.lua" )
	if not fn then
		error( err, 0 )
	end

	setfenv( fn, getfenv() )

	local ok, err = pcall( fn )

	if not ok then
		term.redirect( old_term )
		term.setCursorPos( 1, 1 )
		error( err, 0 )
	end
end

-- Draw to the background window
background_window.setBackgroundColor( colours.grey )

for y, row in ipairs( logo ) do
	for i = 1, #row do
		if row:sub( i, i ) == "x" then
			background_window.setCursorPos( i, y )
			background_window.write( " " )
		end
	end
end

local last_time = os.clock()
local end_queued = false

while true do
	parent_window.setVisible( false )
	main_window.setVisible( false )
	background_window.setVisible( false )

	if not end_queued then
		os.queueEvent( "end" )
		end_queued = true
	end

	local ev = { coroutine.yield() }
	local now = os.clock()
	local dt = now - last_time

	if ev[ 1 ] == "terminate" then
		break
	elseif ev[ 1 ] == "end" then
		end_queued = false
	elseif ev[ 1 ] == "mouse_click" then
		local i = ( ev[ 4 ] - math.floor( height / 2 ) + #menu ) / 2

		if menu[ i ] and ev[ 3 ] >= math.floor( width / 2 - #menu[ i ].name / 2 ) and ev[ 3 ] < math.floor( width / 2 + #menu[ i ].name / 2 ) then
			menu[ i ].fn()
		end
	end

	random_fill()

	main_window.setVisible( true )
	background_window.setVisible( true )

	-- Overlay stuff
	draw_menu()

	parent_window.setVisible( true )

	last_time = now
end

term.redirect( old_term )
term.setCursorPos( 1, 1 )

