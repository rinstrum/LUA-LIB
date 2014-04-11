-------------------------------------------------------------------------------
-- Creates a connection to the M4223 
-- @module rinLibrary.rinRIS
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
------------------------------------------------------------------------------

local _M = {}

local str = string
local tonum = tonumber
local ccitt = require "rinLibrary.rinCCITT"

local socket = require "socket"

-------------------------------------------------------------------------------
-- Read a RIS file and send valid commands to the device
-- @param filename Name of the RIS file
-- @param ip IP Address to transmit file contents to
-- @param port Port to transmit file contents to
function _M.load(filename, ip, port)
	local file = assert(io.open(filename, "r"))
	
	local s = assert(require "socket".tcp())
	s:connect(ip, port)
	s:settimeout(0.1)
	
	for line in file:lines() do
		 if (str.find(line, ':') and tonum(str.sub(line, 1, 8), 16)) then
		 	s:send('\01' .. line .. str.format("%04X", ccitt(line)) .. '\04')
		 	socket.sleep(0.05)
		 end
	end

	file:close()
end

return _M
