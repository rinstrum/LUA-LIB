-------------------------------------------------------------------------------
-- Offer functions for timers that are compatible with the app framework
-- @module rinSystem.rinTimers
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local socket = require "socket"
--local posix = require "posix"

local unpack = unpack
local floor = math.floor
local max = math.max

local _M = {}
local timers = {}

-------------------------------------------------------------------------------
-- Return monotonically increasing time.
-- @return a monotonic seconds based counter
--
-- We use socket.gettime() here, although posix.clock_gettime would be
-- preferable but we can't guarantee posix compatibility.  The socket.gettime()
-- call returns a value that is suspiciously like that returned by time(2).
-- The time(2) call is coarse and not guaranteed to be monotonic.
local function monotonictime()
	return socket.gettime()
	--local s, n = posix.clock_gettime("monotonic")
	--return s + n * 0.000000001
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
        n, p = p, floor(0.5 * n)
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
-- Add a timer to the timer list
-- @param time Time until the timer will go off (milliseconds)
-- @param delay Initial delay for timer
-- @param callback Function to run when timer is complete
-- @param ... Function variables
-- @return Timer key which should be considered a read only object
function _M.addTimer(time, delay, callback, ...)
	if callback == nil then
    	return nil
    end
    local evt = {
    	when = monotonictime() + max(0, delay),
    	rept = time,
        cb   = callback,
        args = {...}
    }
    return push(evt)
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
-- Get the time until the specified timer expires
-- @return Delay in seconds
function _M.delayUntilTimer(event)
	return event.when - monotonictime()
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
        	    event.when = monotonictime() + event.rept
        	    push(event)
            end
        end
    end
end

return _M
