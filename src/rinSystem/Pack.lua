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

-- Accessible members.  The timers field is the only one you'll typically use
-- and this is better accessed by creating a local: local timers = require 'rinSystem.rinTimers.Pack'
--@table rinSystem
-- @field timers    A reference to the global rinTimers helpers.  Use this to create delayed events and timeouts.
-- @field sockets   A refernce to the global rinSYstem helpers.  You almost certainly don't need to access this.
_M.timers = timers
_M.sockets = sockets

-------------------------------------------------------------------------------
-- Main function for handling events.  Receives all incoming events and
-- dispatches appropriately.
-- Issues a callback to any connection or timer that has an event on it.
-- The rinApp application framework calls this as required and there is
-- no need to ever call it yourself.
-- @usage
-- local system = require 'rinSystem.Pack'
--
-- system.handleEvents()
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


-------------------------------------------------------------------------------
-- Close down everything read for a restart at some later point.
-- Calling this yourself is likely to cause portions of the runApp application
-- framework to cease correctly functioning.
-- @usage
-- local system = require 'rinSystem.Pack'
--
-- system.reset()
function _M.reset()
    timers.reset()
    sockets.reset()
end

return _M
