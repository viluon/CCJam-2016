
-- Gravity Gal, a Gravity Guy clone by @viluon

-- Built with [BLittle](http://www.computercraft.info/forums2/index.php?/topic/25354-cc-176-blittle-api/) by Bomb Bloke
if not fs.exists "blittle" then shell.run "pastebin get ujchRSnU blittle" end
if not blittle then os.loadAPI "blittle" end

-- The following disclaimer applies to the easeInOutQuad function, defined further down the file, which has been taken (with slight modifications)
-- from Robert Penner's Easing Equations library for Lua (https://github.com/EmmanuelOga/easing)
--[[
Disclaimer for Robert Penner's Easing Equations license:
TERMS OF USE - EASING EQUATIONS
Open source under the BSD License.
Copyright © 2001 Robert Penner
All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
		* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
		* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
		* Neither the name of the author nor the names of contributors may be used to endorse or promote products derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

local MENU_ANIM_TIME = 0.8

local math = math
local term = term

local actual_term = term.current()

local capture
local old_term

old_term = {
	cursor_pos = { actual_term.getCursorPos() };
	data = {};

	write = actual_term.write;
	setBackgroundColour = actual_term.setBackgroundColour;
	getBackgroundColour = actual_term.getBackgroundColour;
	setTextColour = actual_term.setTextColour;
	getTextColour = actual_term.getTextColour;
	setBackgroundColor = actual_term.setBackgroundColor;
	getBackgroundColor = actual_term.getBackgroundColor;
	setTextColor = actual_term.setTextColor;
	getTextColor = actual_term.getTextColor;

	blit = function( text, tc, bc )
		if capture then
			old_term.data[ old_term.cursor_pos[ 2 ] ] = { text, tc, bc }
		end

		return actual_term.blit( text, tc, bc )
	end;

	setCursorPos = function( x, y )
		old_term.cursor_pos[ 1 ] = x
		old_term.cursor_pos[ 2 ] = y

		return actual_term.setCursorPos( x, y )
	end;
	
	getCursorPos = actual_term.getCursorPos;
	getSize = actual_term.getSize;
	setCursorBlink = actual_term.setCursorBlink;
	getCursorBlink = actual_term.getCursorBlink;
	isColor = actual_term.isColor;
	isColour = actual_term.isColour;
}
local parent_window = window.create( old_term, 1, 1, old_term.getSize() )
local main_window = blittle.createWindow( parent_window )

term.redirect( main_window )
local w, h = term.getSize()
local width, height = parent_window.getSize()

local	random_fill, draw_menu, play, easeInOutQuad

local clicks_enabled = true
local state = "main_menu"

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
		position = 0;
		name = "Play";

		fn = function()
			if state == "main_menu" then
				return play()
			elseif state == "play_menu" then
				return launch()
			end
		end;
	};

	{
		position = 0;
		name = "Exit";

		fn = function()
			if state == "main_menu" then
				--[[
					capture = true

					main_window.setVisible( true )
					background_window.setVisible( true )

					-- Overlay stuff
					update_menu( now )
					draw_menu()

					parent_window.setVisible( true )

					term.redirect( actual_term )

					local f = io.open( "screencap", "w" )
					f:write( textutils.serialise( old_term.data ) )
					f:close()

					local start = os.clock()
					local total_time = 4
					while os.clock() - start < total_time do
						term.clear()
						-- Iterate over the captured image and render it
						local y = 1
						while y < #old_term.data do
							local deltay = easeInOutQuad( os.clock() - start, 1, 3, total_time )
							local row = old_term.data[ y ]
							local x = 1

							while x < #row[ 1 ] do
								local deltax = easeInOutQuad( os.clock() - start, 1, 3, total_time )

								term.setCursorPos( ( ( deltax - 1 ) / 4 ) * width / 2 + x / deltax, ( ( deltay - 1 ) / 4 ) * height / 2 + y / deltay )
								term.blit( row[ 1 ]:sub( x, x ), row[ 2 ]:sub( x, x ), row[ 3 ]:sub( x, x ) )

								x = x + 1
							end

							y = y + 1
						end
					end

					read()
				--]]
				return error()
			elseif state == "play_menu" then
				return back_from_play()
			end
		end;
	};
}

-- t = elapsed time
-- b = begin
-- c = change == ending - beginning
-- d = duration (total time)
function easeInOutQuad( t, b, c, d )
	if t > d then
		return b + c
	end

	t = t / d * 2
	if t < 1 then
		return c / 2 * math.pow( t, 2 ) + b
	else
		return -c / 2 * ( ( t - 1 ) * ( t - 3 ) - 1 ) + b
	end
end

local last_pass = -1
--- Fill the background with random crap
-- @return nil
function random_fill()
	local dt = os.clock() - last_pass

	if dt > 0.001 then
		term.setBackgroundColour( colours.black )
		term.scroll( -1 * dt )

		for y = 1, 1 do
			for x = 1, w * 0.05 do
				term.setCursorPos( math.random( 3, w - 1 ), y )
				term.setBackgroundColour( colours.grey )
				term.write( " " )
			end
		end
		
		last_pass = os.clock()
	end
end

--- Draw the menu elements
-- @return nil
function draw_menu()
	parent_window.setBackgroundColour( colours.black )
	parent_window.setTextColour( colours.white )

	for i, element in ipairs( menu ) do
		parent_window.setCursorPos( element.position, height / 2 - #menu + i * 2 )
		parent_window.write( element.name )
	end
end

--- Update menu elements (for animations)
-- @return nil
function update_menu( now )
	for i, element in ipairs( menu ) do
		if element.position ~= element.target_position then
			element.position = easeInOutQuad( now - element.start_anim_time, element.original_position, element.target_position - element.original_position, MENU_ANIM_TIME )
		end
	end
end

--- Prepare the before-launch screen
-- @return nil
function play()
	local now = os.clock()
	state = "play_menu"

	-- Move all the menu elements except Play to the right, and move Play to the left
	for i, element in ipairs( menu ) do
		if element.name == "Play" then
			element.target_position = 1
		else
			element.target_position = width - #element.name + 1
		end

		element.original_position = element.position
		element.start_anim_time = now
	end
end

--- Return from the before-launch screen
-- @return nil
function back_from_play()
	local now = os.clock()
	state = "main_menu"

	-- Move the elements back to the centre
	for i, element in ipairs( menu ) do
		element.target_position = width / 2 - #element.name / 2

		element.original_position = element.position
		element.start_anim_time = now
	end
end

--- Launch the game
-- @return nil
function launch()
	local f = io.open( "main.lua", "r" )
	local contents = f:read( "*a" )
	f:close()

	local fn, err = loadstring( contents, "main.lua" )
	if not fn then
		error( err, 0 )
	end

	setfenv( fn, getfenv() )

	term.redirect( old_term )
	local ok, err = pcall( fn, launch_settings )

	if not ok then
		term.redirect( old_term )
		term.setCursorPos( 1, 1 )
		error( err, 0 )
	end

	term.redirect( main_window )
end

-- Cook initial menu element positions
for i, element in ipairs( menu ) do
	local x = width / 2 - #element.name / 2

	if not element.target_position then
		element.target_position = x
		element.position = x
	end
end

-- Draw to the background window
background_window.setBackgroundColour( colours.grey )

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

		if clicks_enabled and menu[ i ] and ev[ 3 ] >= math.floor( menu[ i ].position ) and ev[ 3 ] < math.floor( menu[ i ].position + #menu[ i ].name ) then
			menu[ i ].fn()
		end
	end

	random_fill()

	main_window.setVisible( true )
	background_window.setVisible( true )

	-- Overlay stuff
	update_menu( now )
	draw_menu()

	parent_window.setVisible( true )

	last_time = now
end

term.redirect( old_term )
term.setCursorPos( 1, 1 )

