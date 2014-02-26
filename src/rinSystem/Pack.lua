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
   
    local time = timers.delayUntilNext()
    local writers = sockets.getWriterSockets()
    local readers = sockets.getReaderSockets()
	local read, write, err = socket.select(readers, writers, time)
	
	if err == "timeout" then
		timers.processTimeouts()
	end

	for i = 1, #write do
    	sockets.processWriteSocket(write[i])
    end

	for i = 1, #read do
    	sockets.processReadSocket(read[i])
	end
		
end

return _M
