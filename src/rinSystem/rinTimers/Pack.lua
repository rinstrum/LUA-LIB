-------------------------------------------------------------------------------
-- Offer functions for timers that are compatible with the app framework
-- @module rinlib
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local socket = require "socket"

local _M = {}
_M.timers = {}

local tonumber = tonumber
local string = string
local tostring = tostring
local table = table
local pairs = pairs
local unpack = unpack

-------------------------------------------------------------------------------
-- Add a timer to the timer list
-- @param time Time until the timer will go off (milliseconds)
-- @param repeating boolean, sets whether timer will repeat until cancelled
-- @param callback Function to run when timer is complete
-- @param ... Function variables
-- @return Timer key
function _M.addTimer(time, delay, callback, ...)
	local refTime = socket.gettime() + delay/1000
	
	local value = {refTime, time, callback, {...}}
	local key = tonumber(string.gsub(tostring(value), "table: 0x", ""), 16)
	
	_M.timers[key] = value

	return key
end

-------------------------------------------------------------------------------
-- Remove a timer from the timer list
-- @param key Key for a timer
-- @return key if success, nil and error if otherwise
function _M.removeTimer(key)
	_M.timers[key] = nil
end

-------------------------------------------------------------------------------
-- Get the time until the next timer expires
-- @return Timer key
function _M.getSoonest()
	local soonest = nil
	local timeout = nil
	
	for timer in pairs(_M.timers) do
		local time = _M.timers[timer][1]
		
		if soonest == nil or time < timeout then
			soonest = timer
			timeout = time
		end	
	end
	
	if timeout then
		timeout = timeout - socket.gettime()
		
		if timeout < 0 then
			timeout = 0
		end
	end

	
	return soonest, timeout
end

-------------------------------------------------------------------------------
-- Attempt to run a timer designated by the key.
-- @param key Timer key given by add timer
-- @return true is timer callback ran, false if it did not
function _M.runKey(key)
	local timer = _M.timers[key]
	if timer then
		local refTime, time, callback, args = unpack(timer)
		
		if socket.gettime() >= refTime then
			callback(unpack(args))
			_M.timers[key] = nil
			
			if time and time > 0 then
				local refTime = socket.gettime() + time/1000
				local value = {refTime, time, callback, args}
				_M.timers[key] = value
			end
			
			return true
		end
	end
	
	return false
end

return _M