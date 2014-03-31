-------------------------------------------------------------------------------
-- Offer functions for timers that are compatible with the app framework
-- @module rinSystem.rinTimers
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local socket = require "socket"

local unpack = unpack
local floor = math.floor
local max = math.max

local _M = {}
local timers = {}

-------------------------------------------------------------------------------
-- Return monotonically increasing time.
-- @return a monotonic seconds based counter
local monotonictime = socket.gettime

-- Attempt to automatically detect if we're running on a posix based system
-- and if we are, we ditch socket.gettime() and use posix.clock_gettime.
-- The latter is preferable because it is guaranteed monotonic and not impacted
-- by system clock changes.  The socket.gettime() call returns a value that
-- is suspiciously like that returned by time(2).  The time(2) call is coarse
-- and not guaranteed to be monotonic.
if pcall(function() require "posix" end) then
	local clock_gettime = posix.clock_gettime
    monotonictime = function ()
	    local s, n = clock_gettime("monotonic")
	    return s + n * 0.000000001
    end
end

-------------------------------------------------------------------------------
-- Put an event into the timer table.
-- @return The event
local function push(event)
	local when = event.when
    local n = #timers + 1
    local p = floor(0.5 * n)

    timers[n] = event
    while n > 1 and timers[p].when > when do
    	timers[p], timers[n] = timers[n], timers[p]
        n, p = p, floor(0.5 * p)
    end
    return event
end

-------------------------------------------------------------------------------
-- Grab the next event from the timer table.
-- @return The next event
local function pop()
	local s = #timers
    if s == 0 then return nil end
    local event = timers[1]

    timers[1] = timers[s]
    timers[s] = nil
    s = s - 1
	if s > 0 then
        local when = timers[1].when

	    local n, p = 1, 2
        if s > p and timers[p].when > timers[p+1].when then
    	    p = p + 1
        end
        while s >= p and timers[p].when < when do
    	    timers[p], timers[n] = timers[n], timers[p]
            n, p = p, 2 * p
            if s > p and timers[p].when > timers[p+1].when then
        	    p = p + 1
            end
        end
    end
    return event
end

-------------------------------------------------------------------------------
-- Helper routine to add a timer to the list
-- @param time Time until the timer will go off (milliseconds)
-- @param delay Initial delay for timer
-- @param drift Is the timer permitted to drift
-- @param callback Function to run when timer is complete
-- @param ... Function variables
-- @return Timer key which should be considered a read only object
local function internalAddTimer(time, delay, reg, callback, extraargs)
	if callback == nil then
    	return nil
    end
    local evt = {
    	when = monotonictime() + max(0, delay),
    	rept = time,
        regular = reg,
        cb   = callback,
        args = extraargs
    }
    return push(evt)
end

-------------------------------------------------------------------------------
-- Add a timer to the timer list
-- @param time Time until the timer will go off (milliseconds)
-- @param delay Initial delay for timer
-- @param callback Function to run when timer is complete
-- @param ... Function variables
-- @return Timer key which should be considered a read only object
function _M.addTimer(time, delay, callback, ...)
    return internalAddTimer(time, delay, false, callback, {...})
end

-------------------------------------------------------------------------------
-- Add a timer to the timer list
-- @param time Time until the timer will go off (milliseconds)
-- @param delay Initial delay for timer
-- @param callback Function to run when timer is complete
-- @param ... Function variables
-- @return Timer key which should be considered a read only object
function _M.addRegularTimer(time, delay, callback, ...)
    return internalAddTimer(time, delay, true, callback, {...})
end

-------------------------------------------------------------------------------
-- Add an event to the timer list
-- @param callback Function to run when timer is complete
-- @param ... Function variables
-- @return Timer key which should be considered a read only object
local lastEventTimer = nil
function _M.addEvent(callback, ...)
	-- We schedule the first such event timer now and any future ones
    -- a hundred microseconds in the future to preserve order of execution.
	local delay = 0
	if lastEventTimer ~= nil then
    	delay = max(0, _M.delayUntilTimer(lastEventTimer) + .0001)
    end
	lastEventTimer = _M.addTimer(0, delay, callback, ...)
    return lastEventTimer
end

-------------------------------------------------------------------------------
-- Remove a timer from the timer list
-- @param key Key for a timer
function _M.removeTimer(key)
	if key ~= nil then
		key.cb = nil
    	key.args = nil
    	key.rept = nil
        key.regular = nil
    end
end

-------------------------------------------------------------------------------
-- Get the time until the next timer expires
-- @return Delay in seconds
function _M.delayUntilNext()
	if timers[1] ~= nil then
    	return max(0, timers[1].when - monotonictime())
    end
	return nil
end

-------------------------------------------------------------------------------
-- Get the time until the specified timer expires.
-- A cancelled or non-existent timer will never trigger of course.
-- @return Delay in seconds
function _M.delayUntilTimer(event)
    if event ~= nil and event.cb ~= nil then
    	return event.when - monotonictime()
    end
    return math.huge
end

-------------------------------------------------------------------------------
-- Attempt to run any timers that have expired.
function _M.processTimeouts()
	local now = monotonictime()
    while timers[1] ~= nil and timers[1].when <= now do
    	local event = pop()
        -- callback
        if event and event.cb then
        	event.cb(unpack(event.args))
            -- reschedule
            if event.rept and event.rept > 0 then
                if event.regular then
                    event.when = event.when + (1 + floor((now - event.when) / event.rept)) * event.rept
                else
        	        event.when = monotonictime() + event.rept
                end
        	    push(event)
            end
        end
    end
end

return _M
