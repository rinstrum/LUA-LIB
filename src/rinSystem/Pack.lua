-------------------------------------------------------------------------------
-- Framework for interfacing with the L401 for advanced applications
-- @module rinSystem
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
--
local socket = require "socket"
local io = require "io"

local timers = require "rinSystem.rinTimers.Pack"
local sockets = require "rinSystem.rinSockets.Pack"

local pairs = pairs

local _M = {}
_M.timers = timers
_M.sockets = sockets

-------------------------------------------------------------------------------
-- Main function for handling events
-- Issues a callback to any connection or timer that has an event on it.
function _M.handleEvents()

	local key, time = timers.getSoonest()
	local waiting, rec, err = socket.select(sockets.sockets, nil, time)
	
	if err == "timeout" then
		timers.runKey(key)
	end
	
	for i = 1,#waiting do
		local con = waiting[i]
		
		sockets.socketCallback(con)
	end
		
end

return _M