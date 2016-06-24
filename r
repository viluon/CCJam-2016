
local old_term = term.current()

local f = io.open( "main.lua", "r" )
local contents = f:read( "*a" )
f:close()

local fn, err = loadstring( contents, "main.lua" )
if not fn then
	error( err, 0 )
end

local ok, err = pcall( fn, ... )

if not ok then
	term.redirect( old_term )
	term.setCursorPos( 1, 1 )
	error( err, 0 )
end
