
local old_term = term.current()

local f = io.open( "main.lua", "r" )
local contents = f:read( "*a" )
f:close()

local fn = loadstring( contents, "main.lua" )
local ok, err = pcall( fn, ... )

if not ok then
	term.redirect( old_term )
	error( err, 0 )
end
