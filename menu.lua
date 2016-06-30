
-- Gravity Girl, a Gravity Guy clone by @viluon

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

--TODO: Mod/powerup system, (Buck's Shotgun (shoot a fellow girlfriend out of the sky), Corvo's Rune (blink to a near location), Stardust (disable visibility for other players))

local MENU_ANIM_TIME = 0.8
local ELEMENT_ANIM_TIME = 0.8
local LOGO_REDRAW_TIME = 0.8
local SCAN_INTERVAL = 1
local GAME_CHANNEL = 72

local math = math
local term = term

local actual_term = term.current()
local directory = fs.getDir( shell.getRunningProgram() )

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

local	random_fill, draw_menu, launch, play, back_from_play, easeInOutQuad, update_elements, draw_settings, search, redraw_logo,
		randomize_logo_colour, draw_search_results, back_from_search, hide_secrets, scan_for_games

local parent_window = window.create( old_term, 1, 1, old_term.getSize() )
local main_window = blittle.createWindow( parent_window )

term.redirect( main_window )
local w, h = term.getSize()
local width, height = parent_window.getSize()

local modem = peripheral.find( "modem", function( name, object )
	return object.isWireless()
end )

local state = "main_menu"
local secret_menu
local selected_game

local last_scan = -1

local logo_colour = colours.grey
local logo_coloured = false
local logo_start_redraw_time = os.clock()

local logo_colours = { colours.lightBlue, colours.cyan, colours.green, colours.white, colours.red, colours.magenta }

local logo = {
	"   xxxx                      x    x              xxxx  x         x  ";
	"  x                               x             x                x  ";
	"  x      x xx   xxx   x   x  x   xxx   x   x    x      x  x xx   x  ";
	"  x  xx  xx  x     x  x   x  x    x    x   x    x  xx  x  xx  x  x  ";
	"  x   x  x      xxxx  x   x  x    x    x   x    x   x  x  x      x  ";
	"  x   x  x     x   x   x x   x    x     xxxx    x   x  x  x      x  ";
	"   xxx   x      xxxx    x    x     x       x     xxx   x  x       x ";
	"                                       xxxx                         ";
	"                                                                    ";
	"                                                                    ";
	"                                                                    ";
}

local background_window = blittle.createWindow( parent_window, 1, 3, #logo[ 1 ] / 2, #logo / 3 )

local menu = {
	{
		name = "Play";
		fn = function()
			if state == "main_menu" then
				return play()
			elseif state == "play_menu" then
				return launch()
			elseif state == "search_menu" then
				back_from_search()
				return play()
			end
		end;
	};

	{
		name = "Join";
		fn = function()
			if state == "search_menu" and modem then
				return launch()
			elseif state == "main_menu" then
				return search()
			elseif state == "play_menu" then
				back_from_play()
				return search()
			end
		end;
	};

	{
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
			elseif state == "search_menu" then
				return back_from_search()
			end
		end;
	};
}

local launch_settings = {
	{
		name = "Number of Players";
		value = 1;
		options = {
			1, 2, 3, 4
		};
	};
	{
		name = "Player Name";
		value = "Player";
	};
	{
		name = "Player Colour";
		value = 1;
		options = {
			colours.red, colours.green, colours.blue, colours.lightBlue, colours.cyan, colours.magenta
		};

		type = "colour";
	};
}

local secret_settings = {
	{
		name = "Multishell Support";
		value = 1;
		options = {
			"On", "Off"
		};
	};

	{
		name = "Explicit Content";
		value = 2;
		options = {
			"On", "Off"
		};
	};

	{
		name = "Detailed Background";
		value = 1;
		options = {
			"On", "Off"
		};
	};
}

local selected_settings_element
local selected_secret_settings_element
local selected_search_result

local search_results = {}

if not modem then
	search_results[ 1 ] = {
		name = "No wireless modem found :(";
		not_clickable = true;
	}
else
	search_results[ 1 ] = {
		name = "Searching for games...";
		not_clickable = true;
	}
end

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
		term.scroll( -1 )

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

--- Randomize the logo colour
-- @return nil
function randomize_logo_colour()
	local old_colour = logo_colour
	local c = 1

	logo_coloured = true

	while logo_colour == old_colour and c < 10 do
		logo_colour = logo_colours[ math.random( 1, #logo_colours ) ]
		c = c + 1
	end
end

--- Draw the menu elements
-- @return nil
function draw_menu()
	parent_window.setBackgroundColour( colours.black )
	parent_window.setTextColour( colours.white )

	for i, element in ipairs( menu ) do
		parent_window.setCursorPos( element.position, height / 2 - #menu + i * 2 )

		if element.name == "Exit" then
			if state == "main_menu" then
				parent_window.write( "Exit" )
			else
				parent_window.write( "Back" )
			end
		else
			parent_window.write( element.name )
		end
	end
end

--- Draw the secret settings overlay
-- @return nil
function draw_secret_settings()
	for i, element in ipairs( secret_settings ) do
		local selected = element == selected_secret_settings_element

		parent_window.setBackgroundColour( colours.black )
		parent_window.setTextColour( selected and colours.white or colours.lightGrey )

		parent_window.setCursorPos( width / 2 - #element.name, element.position )
		parent_window.write( element.name .. "\7: " )

		if element.options then
			parent_window.setTextColour( element.value == 1 and colours.grey or colours.lightGrey )
			parent_window.write( selected and "\171 " or "< " )
		end

		parent_window.setBackgroundColour( element.type == "colour" and element.options[ element.value ] or ( element.options and colours.black or ( selected and colours.white or colours.black ) ) )
		parent_window.setTextColour( element.options and colours.white or ( selected and colours.grey or colours.white ) )

		local text = element.options and tostring( element.type == "colour" and "  " or element.options[ element.value ] ) or tostring( element.value )
		
		if #text > width / 3 then
			text = "..." .. text:sub( 4 + #text - width / 3, -1 )
		end

		parent_window.write( text )

		if element.options then
			parent_window.setBackgroundColour( colours.black )
			parent_window.setTextColour( element.value == #element.options and colours.grey or colours.lightGrey )
			parent_window.write( selected and " \187" or " >" )
		end
	end
end

--- Draw the settings
-- @return nil
function draw_settings()
	parent_window.setBackgroundColour( colours.black )
	parent_window.setTextColour( colours.white )

	for i, element in ipairs( launch_settings ) do
		local selected = element == selected_settings_element

		parent_window.setBackgroundColour( colours.black )
		parent_window.setTextColour( selected and colours.white or colours.lightGrey )

		parent_window.setCursorPos( width / 2 - #element.name, element.position )
		parent_window.write( element.name .. ": " )

		if element.options then
			parent_window.setTextColour( element.value == 1 and colours.grey or colours.lightGrey )
			parent_window.write( selected and "\171 " or "< " )
		end

		parent_window.setBackgroundColour( element.type == "colour" and element.options[ element.value ] or ( element.options and colours.black or ( selected and colours.white or colours.black ) ) )
		parent_window.setTextColour( element.options and colours.white or ( selected and colours.grey or colours.white ) )

		local text = element.options and tostring( element.type == "colour" and "  " or element.options[ element.value ] ) or tostring( element.value )
		
		if #text > width / 3 then
			text = "..." .. text:sub( 4 + #text - width / 3, -1 )
		end

		parent_window.write( text )

		if element.options then
			parent_window.setBackgroundColour( colours.black )
			parent_window.setTextColour( element.value == #element.options and colours.grey or colours.lightGrey )
			parent_window.write( selected and " \187" or " >" )
		end
	end
end

--- Draw the search results
-- @return nil
function draw_search_results()
	for i, element in ipairs( search_results ) do
		local selected = element == selected_search_result

		parent_window.setBackgroundColour( colours.black )
		parent_window.setTextColour( colours.white )

		parent_window.setCursorPos( width / 2 - #element.name / 2, element.position )
		parent_window.write( element.name )
	end
end

--- Scan for existing games nearby
-- @param now The current time
-- @return nil
function scan_for_games( now )
	if modem and now - last_scan > SCAN_INTERVAL then
		modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
			Gravity_Girl = "best game ever";
			type = "game_lookup";

			sender = local_player;
			} )

		last_scan = now
	end
end

--- Update elements of tbl
-- @param now The current time
-- @param tbl Table to update
-- @return nil
function update_elements( now, tbl )
	for i, element in ipairs( tbl ) do
		if element.position ~= element.target_position then
			element.position = easeInOutQuad( now - element.start_anim_time, element.original_position, element.target_position - element.original_position, ELEMENT_ANIM_TIME )
		end
	end
end

--- Hide the secret settings
-- @param now The current time
-- @return nil
function hide_secrets( now )
	secret_menu = false

	-- Return the elements back off-screen
	for i, element in ipairs( secret_settings ) do
		element.target_position = -#secret_settings * 2 + i * 2 - 1

		element.original_position = element.position
		element.start_anim_time = now
	end
end

--- Prepare the before-launch screen
-- @return nil
function play()
	local now = os.clock()
	state = "play_menu"
	
	randomize_logo_colour()
	logo_start_redraw_time = now

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

	-- Let the setting elements slide in
	for i, element in ipairs( launch_settings ) do
		element.target_position = height / 2 - #launch_settings + i * 2

		element.original_position = element.position
		element.start_anim_time = now
	end
end

--- Search for an existing game
-- @return nil
function search()
	local now = os.clock()
	state = "search_menu"

	randomize_logo_colour()
	logo_start_redraw_time = now

	-- Move all the menu elements except Join to the right, and move Join to the left
	for i, element in ipairs( menu ) do
		if element.name == "Join" then
			element.target_position = 1
		else
			element.target_position = width - #element.name + 1
		end

		element.original_position = element.position
		element.start_anim_time = now
	end

	-- Let the search results slide in
	for i, element in ipairs( search_results ) do
		element.target_position = height / 2 - #search_results + i * 2

		element.original_position = element.position
		element.start_anim_time = now
	end
end

--- Return from the search screen
-- @return nil
function back_from_search()
	local now = os.clock()
	state = "main_menu"

	logo_coloured = false
	logo_start_redraw_time = now

	-- Move the menu elements back to the centre
	for i, element in ipairs( menu ) do
		element.target_position = width / 2 - #element.name / 2

		element.original_position = element.position
		element.start_anim_time = now
	end

	-- Move the search results back down (out of the screen)
	for i, element in ipairs( search_results ) do
		element.target_position = height + i * 2

		element.original_position = element.position
		element.start_anim_time = now
	end

	selected_search_result = nil
end

--- Return from the before-launch screen
-- @return nil
function back_from_play()
	local now = os.clock()
	state = "main_menu"
	
	logo_coloured = false
	logo_start_redraw_time = now

	-- Move the menu elements back to the centre
	for i, element in ipairs( menu ) do
		element.target_position = width / 2 - #element.name / 2

		element.original_position = element.position
		element.start_anim_time = now
	end

	-- Move the setting elements back down (out of the screen)
	for i, element in ipairs( launch_settings ) do
		element.target_position = height + i * 2

		element.original_position = element.position
		element.start_anim_time = now
	end

	selected_settings_element = nil
end

--- Pass execution to wait for players script
-- @return nil
function launch()
	local f = io.open( directory .. "/wait_for_players.lua", "r" )
	local contents = f:read( "*a" )
	f:close()

	local fn, err = loadstring( contents, "wait_for_players.lua" )
	if not fn then
		error( err, 0 )
	end

	setfenv( fn, getfenv() )

	term.redirect( old_term )
	local ok, err = pcall( fn, {
		launch_settings = launch_settings;
		secret_settings = secret_settings;
		modem = modem;
		selected_game = selected_game;
		GAME_CHANNEL = GAME_CHANNEL;
	} )

	if not ok then
		term.redirect( actual_term )
		term.setBackgroundColour( colours.grey )
		term.clear()
		term.setTextColour( colours.white )

		local y = math.floor( height / 2 )

		local text = "Oh crap! Gravity Girl has crashed."
		term.setCursorPos( width / 2 - #text / 2, y - 4 )
		term.write( text )

		local text2 = "Sorry for the inconvenience :("
		term.setCursorPos( width / 2 - #text2 / 2, y - 3 )
		term.write( text2 )

		local text3 = "Wanna get it up and running in no time?"
		term.setCursorPos( width / 2 - #text3 / 2, y - 1 )
		term.write( text3 )

		local text4 = "Send @viluon this secret code:"
		term.setCursorPos( width / 2 - #text4 / 2, y - 0 )
		term.write( text4 )

		term.setBackgroundColour( colours.white )
		term.setTextColour( colours.black )
		term.setCursorPos( 1, y + 2 )
		print( err )

		read()

		error()
	end

	term.redirect( main_window )
end

--- Redraw the Gravity Girl logo
-- @return nil
function redraw_logo( now )
	-- Draw to the background window
	background_window.setBackgroundColour( logo_coloured and logo_colour or colours.grey )

	for y, row in ipairs( logo ) do
		for i = 1, #row * easeInOutQuad( now - logo_start_redraw_time, 0, 1, LOGO_REDRAW_TIME ) do
			if row:sub( i, i ) == "x" then
				background_window.setCursorPos( i, y )
				background_window.write( " " )
			end
		end
	end
end

-- Cook initial menu element positions
for i, element in ipairs( menu ) do
	local x = width / 2 - #element.name / 2

	if not element.target_position then
		element.target_position = x
		element.position = x
	end
end

-- Cook initial launch settings element positions
for i, element in ipairs( launch_settings ) do
	if not element.target_position then
		element.target_position = height + i * 2
		element.position = height + i * 2
	end
end

-- Cook initial search results element positions
for i, element in ipairs( search_results ) do
	if not element.target_position then
		element.target_position = height + i * 2
		element.position = height + i * 2
	end
end

-- Cook initial secret settings element positions
for i, element in ipairs( secret_settings ) do
	if not element.target_position then
		element.target_position = -#secret_settings * 2 + i * 2 - 1
		element.position = -#secret_settings * 2 + i * 2 - 1
	end
end

local last_time = os.clock()
local end_queued = false

-- Render the logo
redraw_logo( last_time )

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

		if menu[ i ] and ev[ 3 ] >= math.floor( menu[ i ].position ) and ev[ 3 ] < math.floor( menu[ i ].position + #menu[ i ].name ) then
			hide_secrets( now )
			menu[ i ].fn()

		elseif state == "play_menu" then
			if ev[ 3 ] == width and ev[ 4 ] == 1 then
				-- Secret advanced settings menu!
				if secret_menu then
					hide_secrets( now )

				else
					-- Let the secrets slide in (from top)
					for i, element in ipairs( secret_settings ) do
						element.target_position = height / 2 - #secret_settings / 2 + i * 2

						element.original_position = element.position
						element.start_anim_time = now
					end

					secret_menu = true

				end

			elseif secret_menu then
				-- Check whether we hit a *secret* setting element
				for i, element in ipairs( secret_settings ) do
					if math.floor( element.position ) == ev[ 4 ] then
						selected_secret_settings_element = element

						if element.options then
							if ev[ 3 ] >= width / 2 and ev[ 3 ] <= width / 2 + 3 then
								element.value = math.max( 1, element.value - 1 )
							elseif ev[ 3 ] >= width / 2 then
								element.value = math.min( #element.options, element.value + 1 )
							end
						end

						break
					end
				end

			else
				-- Check whether we hit a setting element
				for i, element in ipairs( launch_settings ) do
					if math.floor( element.position ) == ev[ 4 ] then
						selected_settings_element = element

						if element.options then
							if ev[ 3 ] >= width / 2 and ev[ 3 ] <= width / 2 + 3 then
								element.value = math.max( 1, element.value - 1 )
							elseif ev[ 3 ] >= width / 2 then
								element.value = math.min( #element.options, element.value + 1 )
							end
						end

						break
					end
				end
			end
		end

	elseif ev[ 1 ] == "key" then
		if selected_settings_element and state == "play_menu" then
			if ev[ 2 ] == keys.backspace then
				if type( selected_settings_element.value ) == "string" and #selected_settings_element.value > 0 then
					selected_settings_element.value = selected_settings_element.value:sub( 1, -2 )
				end
			
			elseif ev[ 2 ] == keys.left then
				if selected_settings_element.options then
					selected_settings_element.value = math.max( 1, math.min( selected_settings_element.value - 1, #selected_settings_element.options ) )
				end

			elseif ev[ 2 ] == keys.right then
				if selected_settings_element.options then
					selected_settings_element.value = math.max( 1, math.min( selected_settings_element.value + 1, #selected_settings_element.options ) )
				end

			elseif ev[ 2 ] == keys.up then
				-- Find the index of the selected_settings_element and select the one before that
				for i, element in ipairs( launch_settings ) do
					if element == selected_settings_element then
						selected_settings_element = launch_settings[ math.max( i - 1, 1 ) ]
						break
					end
				end
			
			elseif ev[ 2 ] == keys.down then
				-- Find the index of the selected_settings_element and select the one after that
				for i, element in ipairs( launch_settings ) do
					if element == selected_settings_element then
						selected_settings_element = launch_settings[ math.min( i + 1, #launch_settings ) ]
						break
					end
				end
			end
		end
		
		if ev[ 2 ] == keys.enter then
			if secret_menu then
				selected_secret_settings_element = nil

			elseif state == "play_menu" then
				if selected_settings_element then
					selected_settings_element = nil
				else
					launch()
				end

			elseif state == "main_menu" then
				play()
			end
		end

	elseif ev[ 1 ] == "char" then
		if selected_settings_element and state == "play_menu" and type( selected_settings_element.value ) == "string" then
			selected_settings_element.value = selected_settings_element.value .. ev[ 2 ]

		elseif ev[ 2 ] == "q" then
			--WARN: Hard link!
			hide_secrets( now )
			menu[ #menu ].fn()
		end

	elseif ev[ 1 ] == "modem_message" then
		if ev[ 3 ] == GAME_CHANNEL then
			local message = ev[ 4 ]

			if type( message ) == "table" and message.Gravity_Girl == "best game ever" and message.sender ~= myself then
				if message.type == "game_lookup_response" then
					if not search_results[ message.game_ID ] then
						search_results[ message.game_ID ] = true

						search_results[ #search_results + 1 ] = {
							name = message.sender.name;

							target_position = height / 2 - #search_results + 1 + i * 2;
							original_position = height;
							start_anim_time = now;
						}
					end
				end
			end
		end
	end

	scan_for_games( now )

	random_fill()
	redraw_logo( now )

	main_window.setVisible( true )
	background_window.setVisible( true )

	-- Overlay stuff
	update_elements( now, launch_settings )
	update_elements( now, search_results )
	update_elements( now, secret_settings )
	update_elements( now, menu )

	draw_settings()
	draw_search_results()
	draw_secret_settings()
	draw_menu()

	if state == "play_menu" then
		parent_window.setCursorPos( width, 1 )
		parent_window.setBackgroundColour( colours.black )
		parent_window.setTextColour( colours.lightGrey )
		parent_window.write( secret_menu and "*" or "\7" )
	end

	parent_window.setVisible( true )

	last_time = now
end

term.redirect( old_term )
term.setCursorPos( 1, 1 )

