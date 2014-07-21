-------------------------------------------------------------------------------
-- Framework for interfacing with the K400 for advanced applications
-- @module rinSystem
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
--
local socket = require "socket"
local posix = require "posix"
local io = require "io"

local timers = require "rinSystem.rinTimers.Pack"
local sockets = require "rinSystem.rinSockets.Pack"
local dbg = require "rinLibrary.rinDebug"

local pairs = pairs

local deprecatedFields, warned = {
    timers = timers,
    sockets = sockets
}, {}

local _M = {}

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
-- Hard sleep for a specified period of time.  This will completely block
-- your application and shouldn't be called.  Use the device.delay() call
-- instead.
-- @param s Seconds to sleep for, can be fractional
-- @see delay
-- @local
function _M.sleep(s)
    if math.floor(s) == s then
        posix.sleep(s)
    else
        socket.select(nil, nil, s)
    end
end

-------------------------------------------------------------------------------
-- Close down everything read for a restart at some later point.
-- Calling this yourself is likely to cause portions of the rinApp application
-- framework to cease correctly functioning.
-- @usage
-- local system = require 'rinSystem.Pack'
--
-- system.reset()
function _M.reset()
    timers.reset()
    sockets.reset()
end

setmetatable(_M, {
    __index =
        function(t, k)
            if deprecatedFields[k] ~= nil then
                if not warned[k] then
                    dbg.warn('rinSystem:', 'attempt to access deprecated field: '..k)
                    warned[k] = true
                end
                return deprecatedFields[k]
            end
            return nil
        end,
    __newindex = function(t, k, v)
            if deprecatedFields[k] ~= nil then
                dbg.error("rinSystem:", 'attempt to overwrite deprecated field: '..k)
            else
                rawset(t, k, v)
            end
        end
})

return _M
