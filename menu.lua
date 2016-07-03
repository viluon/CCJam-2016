
-- Gravity Girl, a Gravity Guy clone by @viluon

if not ( term.isColour and term.isColour() ) then
	error( "Gravity Girl needs an advanced computer!", 0 )
end

local directory = fs.getDir( shell.getRunningProgram() )

-- Built with [BLittle](http://www.computercraft.info/forums2/index.php?/topic/25354-cc-176-blittle-api/) by Bomb Bloke
if not fs.exists "/blittle" then shell.run "pastebin get ujchRSnU /blittle" end
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
local ENABLE_LOGGING = true
local ELEMENT_TIMEOUT = 3
local JOIN_BUTTON_ANIM_LENGTH = 0.3

local math = math
local term = term

local actual_term = term.current()
local logfile = io.open( directory .. "/menu_log.txt", "a" )

local capture
local old_term = actual_term

--[[
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
	clear = actual_term.clear;
}
]]

local	random_fill, draw_menu, launch, play, back_from_play, easeInOutQuad, update_elements, draw_settings, search, redraw_logo,
		randomize_logo_colour, draw_search_results, back_from_search, hide_secrets, scan_for_games, log, save_settings, load_settings,
		animate_join_button, ease_linear, show_message, validate_player_name

local parent_window = window.create( old_term, 1, 1, old_term.getSize() )
local main_window = blittle.createWindow( parent_window )

term.redirect( main_window )
local w, h = term.getSize()
local width, height = parent_window.getSize()

local fall_direction = -1

local modem = peripheral.find( "modem", function( name, object )
	return object.isWireless()
end )

if modem then
	modem.open( GAME_CHANNEL )
end

local state = "main_menu"
local running = true
local secret_menu
local selected_game

local last_scan = -1

local logo_colour = colours.grey
local logo_coloured = false
local logo_start_redraw_time = os.clock()

local logo_colours = { colours.lightBlue, colours.yellow, colours.cyan, colours.green, colours.pink, colours.magenta }

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

local selected_settings_element
local selected_secret_settings_element
local selected_search_result

local search_results = {}
local clash_found = false

local messages = {}

local menu = {
	{
		name = "Play";
		fn = function()
			if state == "main_menu" then
				return play()
			elseif state == "play_menu" then
				local ok, msg = validate_player_name()

				if not ok then
					return show_message( msg )
				else
					return launch()
				end
			elseif state == "search_menu" then
				back_from_search()
				return play()
			end
		end;
	};

	{
		name = "Join";
		fn = function()
			if state == "search_menu" and modem and not clash_found then
				local selection_exists = false

				-- Check that the search result actually exists
				for i, element in ipairs( search_results ) do
					if element == selected_search_result then
						selection_exists = true
						break
					end
				end

				if selection_exists then
					launch()
					selected_game = nil
				end

			elseif state == "search_menu" and clash_found then
				return show_message( clash_found )

			elseif state == "main_menu" then
				return search()
			elseif state == "play_menu" then
				back_from_play()
				return search()
			end
		end;
		animation = {
			colour_a = colours.white;
			start_time = -1;
			pos = 4;
		};
	};

	{
		name = "Help";
		fn = function()
			if state == "main_menu" then
				return show_message [[
Press spacebar to switch
direction of gravity. Set
your name and colour in
the Play menu and then
either start a game or
join one!
]]
			elseif state == "play_menu" then
				return show_message [[
Set your player name
and colour to whatever
you like, then click the
Play button at the left
again. Remember, spacebar
switches gravity!
]]
			elseif state == "search_menu" then
				return show_message [[
This is the search menu.
Here you can see a list
of nearby games waiting
for players. To join a
game, click it in the list
and then click "Join"
at the left of the screen.
]]
			end
		end;
	};

	{
		name = "Exit";
		fn = function()
			if state == "main_menu" then
				running = false
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
			colours.pink, colours.green, colours.blue, colours.yellow, colours.cyan, colours.magenta
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

if not modem then
	search_results[ 1 ] = {
		name = "No wireless modem found :(";
		not_clickable = true;
	}
else
	search_results[ 1 ] = {
		name = "Host| Players";
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

function ease_linear( time, begin, change, duration )
	if time > duration then
		return begin + change
	end

	return ( time / duration ) * change + begin
end

local last_pass = -1
--- Fill the background with random crap
-- @return nil
function random_fill()
	local dt = os.clock() - last_pass

	if dt > 0.001 then
		term.setBackgroundColour( colours.black )
		term.scroll( fall_direction )

		for x = 1, w * 0.05 do
			term.setCursorPos( math.random( 3, w - 1 ), fall_direction > 0 and h or 1 )
			term.setBackgroundColour( colours.grey )
			term.write( " " )
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

--- Write to the log file
-- @param ... The data to write
-- @return nil
function log( ... )
	if not ENABLE_LOGGING then return end

	logfile:write( table.concat( { ... } ) .. "\n" )
	logfile:flush()
end

--- Load settings from file (if exists)
-- @return nil
function load_settings()
	if not fs.exists( directory .. "/.Gravity_Girl_settings" ) then return end

	local f = io.open( directory .. "/.Gravity_Girl_settings", "r" )
	local contents = f:read( "*a" )
	f:close()

	local setting_values = textutils.unserialise( contents )

	for i, val in ipairs( setting_values ) do
		for _, setting in ipairs( launch_settings ) do
			if setting.name == val.name then
				setting.value = val.value
				break
			end
		end
	end
end

--- Save settings to file
-- @return nil
function save_settings()
	local setting_values = {}

	for i, setting in ipairs( launch_settings ) do
		setting_values[ #setting_values + 1 ] = { name = setting.name, value = setting.value }
	end

	local contents = textutils.serialise( setting_values )

	local f = io.open( directory .. "/.Gravity_Girl_settings", "w" )
	f:write( contents )
	f:close()
end

--- Animate the Join button text colour
-- @param now Current time
-- @return nil
function animate_join_button( now )
	local new_colour = colours.white

	if selected_game then
		new_colour = colours.green

		-- Check that no other player has our name or colour
		clash_found = false

		local ok, msg = validate_player_name()

		if not ok then
			clash_found = msg
			new_colour = colours.red

		else
			for ID, player in pairs( selected_game.players or {} ) do
				if player.name == launch_settings[ 2 ].value or player.colour == launch_settings[ 3 ].options[ launch_settings[ 3 ].value ] then
					new_colour = colours.red
					
					if player.name == launch_settings[ 2 ].value then
						clash_found = "A player with your name\nhas already connected\nto the game."
					else
						local colour_name
						for name, colour in pairs( colours ) do
							if colour == player.colour then
								colour_name = name
								break
							end
						end

						clash_found = "A " .. colour_name .. " player\nhas already connected\nto the game."
					end

					break
				end
			end
		end
	end

	for i, button in ipairs( menu ) do
		if button.name:lower() == "join" then
			if button.animation.colour_a ~= new_colour then
				button.animation.colour_b = button.animation.colour_a
				button.animation.start_time = now
				button.animation.colour_a = new_colour
			end

			button.animation.pos = ease_linear( now - button.animation.start_time, 1, 3, JOIN_BUTTON_ANIM_LENGTH )

			break
		end
	end
end

--- Display a message box
-- @param text description
-- @return nil
function show_message( text )
	messages[ #messages + 1 ] = text
end

--- Update and draw active messages
-- @return nil
function draw_messages()
	for i, message in ipairs( messages ) do
		message = message .. "\n"

		local lines = {}
		local longest_line = -1

		for line in string.gmatch( message, "[^\n]+\n" ) do
			lines[ #lines + 1 ] = line
			longest_line = math.max( longest_line, #line )
		end

		parent_window.setTextColour( colours.lightGrey )
		parent_window.setCursorPos( width / 2 - longest_line / 2 - 2, height / 2 - #lines / 2 )
		parent_window.write( string.rep( "\7", longest_line + 4 ) )

		for i = 1, #lines do
			parent_window.setCursorPos( width / 2 - longest_line / 2 - 2, height / 2 - #lines / 2 + i )
			parent_window.write( "\7 " )

			parent_window.setTextColour( colours.white )
			parent_window.write( lines[ i ] .. string.rep( " ", longest_line - #lines[ i ] ) )

			parent_window.setTextColour( colours.lightGrey )
			parent_window.write( " \7" )
		end

		parent_window.setCursorPos( width / 2 - longest_line / 2 - 2, height / 2 + #lines / 2 + 1 )
		parent_window.write( string.rep( "\7", longest_line + 4 ) )
	end
end

--- Draw the menu elements
-- @return nil
function draw_menu()
	parent_window.setBackgroundColour( colours.black )

	for i, element in ipairs( menu ) do
		parent_window.setTextColour( colours.white )
		parent_window.setCursorPos( element.position, height / 2 - #menu + i * 2 )

		if element.name:lower() == "exit" then
			if state == "main_menu" then
				parent_window.write( "Exit" )
			else
				parent_window.write( "Back" )
			end
		elseif element.animation then
			parent_window.setTextColour( element.animation.colour_a )
			for i = 1, element.animation.pos do
				parent_window.write( element.name:sub( i, i ) )
			end

			parent_window.setTextColour( element.animation.colour_b )
			for i = math.floor( element.animation.pos + 1 ), #element.name do
				parent_window.write( element.name:sub( i, i ) )
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

		parent_window.setBackgroundColour( selected and colours.white or colours.black )
		parent_window.setTextColour( selected and colours.grey or colours.white )

		if not element.not_clickable then
			parent_window.setCursorPos( width / 2 - #element.name, element.position )
			parent_window.write( element.name .. " |" )

			parent_window.setCursorPos( width / 2 + 3, element.position )
			parent_window.write( element.game_details.connected .. "/" .. element.game_details.max )

		elseif #search_results == 1 then
			local text = modem and "Searching for games..." or element.name

			parent_window.setCursorPos( width / 2 - #text / 2, element.position )
			parent_window.write( text )

		else
			local pos = element.name:find( "|" )

			if pos then
				local a = element.name:sub( 1, pos - 1 )
				local b = element.name:sub( pos, -1 )

				parent_window.setCursorPos( width / 2 - #a, element.position )
				parent_window.write( a )

				parent_window.setCursorPos( width / 2 + 1, element.position )
				parent_window.write( b )
			else
				parent_window.setCursorPos( width / 2 - #element.name / 2, element.position )
				parent_window.write( element.name )
			end
		end
	end
end

--- Scan for existing games nearby
-- @param now The current time
-- @return nil
function scan_for_games( now )
	if modem and ( now - last_scan > SCAN_INTERVAL ) then
		modem.transmit( GAME_CHANNEL, GAME_CHANNEL, {
			Gravity_Girl = "best game ever";
			type = "game_lookup";

			sender = local_player;
		} )

		last_scan = now
	end
end

--- Check that the current player name doesn't contain invalid characters
-- @return True if the player name is okay, nil and an error message otherwise
function validate_player_name()
	if #launch_settings[ 2 ].value == 0 then
		return nil, "Your player name\ncannot be empty."
	elseif #launch_settings[ 2 ].value:gsub( "[%w_]+", "" ) ~= 0 then
		return nil, "Your player name can\nonly contain letters, numbers,\nand underscores."
	else
		return true
	end
end

--- Update elements of tbl
-- @param now The current time
-- @param tbl Table to update
-- @return nil
function update_elements( now, tbl )
	local to_remove = {}

	for i, element in ipairs( tbl ) do
		if element.position ~= element.target_position then
			element.position = easeInOutQuad( now - element.start_anim_time, element.original_position, element.target_position - element.original_position, ELEMENT_ANIM_TIME )
		end

		if element.last_seen and os.clock() - element.last_seen > ELEMENT_TIMEOUT then
			to_remove[ #to_remove + 1 ] = element
		end
	end

	for _, el in ipairs( to_remove ) do
		for i, el2 in ipairs( tbl ) do
			if el == el2 then
				table.remove( tbl, i )
				break
			end
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
		ENABLE_LOGGING = ENABLE_LOGGING;
		logfile = logfile;
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

		local enter_to_continue = "Press Enter to continue"
		term.setCursorPos( width / 2 - #enter_to_continue / 2, height - 1 )
		term.write( enter_to_continue )

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

-- Load settings
load_settings()

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

while running do
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
		if #messages > 0 then
			messages[ #messages ] = nil

		else
			local i = ( ev[ 4 ] - math.floor( height / 2 ) + #menu ) / 2

			-- Check for a menu element hit
			if menu[ i ] and ev[ 3 ] >= math.floor( menu[ i ].position ) and ev[ 3 ] < math.floor( menu[ i ].position + #menu[ i ].name ) then
				hide_secrets( now )
				menu[ i ].fn()

				if state ~= "search_menu" then
					selected_game = nil
				end

				save_settings()

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

			elseif state == "search_menu" then
				-- Check whether we hit a search result entry
				for i, element in ipairs( search_results ) do
					if math.floor( element.position ) == ev[ 4 ] and not element.not_clickable then
						selected_search_result = element
						selected_game = element.game_details

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

				save_settings()

			elseif state == "main_menu" then
				play()

			elseif state == "search_menu" then
				local selection_exists = false

				-- Check that the search result actually exists
				for i, element in ipairs( search_results ) do
					if element == selected_search_result then
						selection_exists = true
						break
					end
				end

				if selection_exists then
					return launch()
				end
			end
		end

	elseif ev[ 1 ] == "char" then
		if selected_settings_element and state == "play_menu" and type( selected_settings_element.value ) == "string" then
			selected_settings_element.value = selected_settings_element.value .. ev[ 2 ]

			save_settings()

		elseif ev[ 2 ] == "q" then
			--WARN: Hard link!
			hide_secrets( now )
			menu[ #menu ].fn()

			if state ~= "search_menu" then
				selected_game = nil
			end

			save_settings()

		elseif ev[ 2 ] == " " then
			fall_direction = -fall_direction
		end

	elseif ev[ 1 ] == "modem_message" then
		--log( "menu received message:", textutils.serialise( ev ) )

		if ev[ 3 ] == GAME_CHANNEL then
			local message = ev[ 5 ]

			if type( message ) == "table" and message.Gravity_Girl == "best game ever" and message.sender and message.sender.ID ~= os.getComputerID() then
				if message.type == "game_lookup_response" then
					if message.game_ID then
						local found = false
						-- Check if we should only update an existing entry
						for i, entry in ipairs( search_results ) do
							if entry.game_details and entry.game_details.game_ID == message.game_ID then
								found = true

								search_results[ i ] = {
									name = message.sender.name;

									game_details = {
										name = message.sender.name;
										connected = message.data.connected;
										max = message.data.max;
										game_ID = message.game_ID;
										players = message.data.players;
									};

									position = height + #search_results;
									target_position = entry.target_position;
									original_position = entry.original_position;
									start_anim_time = entry.start_anim_time;

									last_seen = now;
								}

								if selected_search_result == entry then
									selected_search_result = search_results[ i ]
								end

								break
							end
						end

						if not found then
							search_results[ #search_results + 1 ] = {
								name = message.sender.name;

								game_details = {
									name = message.sender.name;
									connected = message.data.connected;
									max = message.data.max;
									game_ID = message.game_ID;
								};

								position = height + #search_results;

								last_seen = now;
							}

							-- Recalculate search results element positions
							for i, element in ipairs( search_results ) do
								element.target_position = state == "search_menu" and height / 2 - #search_results + i * 2 or height + i * 2
								element.original_position = element.position
								element.start_anim_time = now
							end
						end
					end
				end
			end
		end
	end

	scan_for_games( now )

	random_fill()
	redraw_logo( now )
	animate_join_button( now )

	main_window.setVisible( true )
	background_window.setVisible( true )

	-- Overlay stuff
	update_elements( now, launch_settings )
	update_elements( now, secret_settings )
	update_elements( now, menu )

	local last_n = #search_results
	update_elements( now, search_results )

	if #search_results ~= last_n then
		-- Recalculate search results element positions
		for i, element in ipairs( search_results ) do
			element.target_position = state == "search_menu" and height / 2 - #search_results + i * 2 or height + i * 2
			element.original_position = element.position
			element.start_anim_time = now
		end
	end

	draw_settings()
	draw_search_results()
	draw_secret_settings()
	draw_menu()

	draw_messages()

	if state == "play_menu" then
		parent_window.setCursorPos( width, 1 )
		parent_window.setBackgroundColour( colours.black )
		parent_window.setTextColour( colours.lightGrey )
		parent_window.write( secret_menu and "*" or "\7" )
	end

	parent_window.setVisible( true )

	last_time = now
end

logfile:close()

term.redirect( old_term )
term.setCursorPos( 1, 1 )

shell.run( "yellowave.lua", 1 )
