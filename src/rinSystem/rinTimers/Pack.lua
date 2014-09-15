-------------------------------------------------------------------------------
-- Offer functions for timers that are compatible with the app framework
-- @module rinSystem.rinTimers
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local socket = require "socket"
local utils = require 'rinSystem.utilities'

local unpack = unpack
local floor = math.floor
local max = math.max

local _M = {}
local timers = {}
local lastEventTimer = nil

-------------------------------------------------------------------------------
-- Return monotonically increasing time.
-- @function monotonictime
-- @return a monotonic seconds based counter
-- @local
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
-- @local
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
-- @local
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

------------------------------------------------------------------------------
-- Utility routine to determine if a timer is still active
-- @param timer The timer being investigated
-- @return true iff the timer is still active
-- @local
local function active(timer)
    return timer ~= nil and utils.callable(timer.cb)
end

-------------------------------------------------------------------------------
-- Helper routine to add a timer to the list
-- @param time Time until the timer will go off (milliseconds)
-- @param delay Initial delay for timer
-- @param reg Is the timer permitted to drift
-- @param callback Function to run when timer is complete
-- @param extraargs Function variables
-- @return Timer key which should be considered a read only object
-- @local
local function internalAddTimer(time, delay, reg, callback, extraargs)
	if not utils.callable(callback) then
        if callback ~= nil then
            error('rinTimers: callback specified is not a function')
        end
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
-- @param time Time between timer events in seconds, 0 means no repetition
-- @param delay Initial delay for timer in seconds
-- @param callback Function to run when timer is complete
-- @param ... Function arguments
-- @return Timer key which should be considered a read only object
-- @see addRegularTimer
-- @see removeTimer
-- @see addEvent
-- @usage
-- local timers = require 'rinSystem.rinTimers.Pack'
--
-- timers.addTimer(0, 10, print, 'hello, ten seconds have elapsed')
-- local t1 = timers.addTimer(1, 0, print, 'tick')
-- local t2 = timers.addTimer(1, 0.5, print, 'tock')
-- timers.addTimer(0, 20, timers.removeTimer, t1)
-- timers.addTimer(0, 21, timers.removeTimer, t2)
-- timers.addTimer(0, 22, print, 'goodbye)
function _M.addTimer(time, delay, callback, ...)
    return internalAddTimer(time, delay, false, callback, {...})
end

-------------------------------------------------------------------------------
-- Add a timer to the timer list, when repeating this timer won't drift
-- due to delays etc.  It is still possible for timing events to be missed
-- or skipped but they won't drift.  Unless timing is critical, you won't
-- need to use this flavour.
-- @param time Time between timer events in seconds, 0 means no repetition
-- @param delay Initial delay for timer in seconds
-- @param callback Function to run when timer is complete
-- @param ... Function arguments
-- @return Timer key which should be considered a read only object
-- @see addTimer
-- @see removeTimer
-- @see addEvent
-- @usage
-- local timers = require 'rinSystem.rinTimers.Pack'
--
-- local t1 = timers.addRegularTimer(1, 0, print, 'tick')
-- local t2 = timers.addRegularTimer(1, 0.5, print, 'tock')
-- timers.addTimer(0, 20, timers.removeTimer, t1)
-- timers.addTimer(0, 21, timers.removeTimer, t2)
-- timers.addTimer(0, 22, print, 'goodbye)
function _M.addRegularTimer(time, delay, callback, ...)
    return internalAddTimer(time, delay, true, callback, {...})
end

-------------------------------------------------------------------------------
-- Add an event to the timer list.  Events occur immediately but are triggered
-- from the application's main event loop.  They should be used when you want
-- something to occur now, but don't want to wait around for it and don't want
-- other application functions to wait either.  The ordering of events is
-- preserved.
-- @param callback Function to run when timer is complete
-- @param ... Function arguments
-- @return Timer key which should be considered a read only object
-- @see addTimer
-- @see addRegularTimer
-- @see removeTimer
-- @usage
-- local timers = require 'rinSystem.rinTimers.Pack'
--
-- timers.addEvent(print, "first event")
-- timers.addEvent(print, 'second event')
-- timers.addEvent(print, 'third event')
function _M.addEvent(callback, ...)
	-- We schedule the first such event timer now and any future ones
    -- a hundred microseconds in the future to preserve order of execution.
	local delay = 0
	if active(lastEventTimer) then
    	delay = max(0, _M.delayUntilTimer(lastEventTimer) + .0001)
    end
	lastEventTimer = internalAddTimer(0, delay, false, callback, {...})
    return lastEventTimer
end

-------------------------------------------------------------------------------
-- Remove a timer from the timer list
-- @param key Key for a timer
-- @see addTimer
-- @see addRegularTimer
-- @see addEvent
-- @usage
-- local timers = require 'rinSystem.rinTimers.Pack'
--
-- local t1 = timers.addTimer(1, 0, print, 'tick')
-- local t2 = timers.addTimer(1, 0.5, print, 'tock')
-- device.delay(10)
-- timers.removeTimer(t1)
-- timers.removeTimer(t2)
function _M.removeTimer(key)
	if key ~= nil then
		key.cb = nil
    	key.args = nil
    	key.rept = nil
        key.regular = nil
    end
end

-------------------------------------------------------------------------------
-- Get the time until the next timer expires.  This routine does not do any
-- waiting, it simply returns how long until the next scheduled timer event.
-- Generally, you won't need to call this ever.  The rinApp application
-- framework takes care of this for you.
-- @return Delay in seconds
-- @see delayUntilTimer
-- @see processTimeouts
-- @usage
-- local timers = require 'rinSystem.rinTimers.Pack'
--
-- local timeTillNext = timers.delayUnitNext()
-- print('snoozing for ' .. timeTillNext .. ' seconds')
function _M.delayUntilNext()
	if timers[1] ~= nil then
    	return max(0, timers[1].when - monotonictime())
    end
	return nil
end

-------------------------------------------------------------------------------
-- Get the time until the specified timer expires.
-- A cancelled or non-existent timer will never trigger of course and return
-- a huge number.
-- @return Delay in seconds
-- @see delayUntilNext
-- @usage
-- local timers = require 'rinSystem.rinTimers.Pack'
--
-- local t = timers.addTimer(0, 10, print, 'bye')
--
-- local function status()
--     print('timer in ' .. timers.delayUntilTimer(t) .. ' seconds')
-- end
-- timers.addTimer(1.123, 2.345, status)
function _M.delayUntilTimer(event)
    if active(event) then
    	return event.when - monotonictime()
    end
    return math.huge
end

-------------------------------------------------------------------------------
-- Attempt to run any timers that have expired at this moment.
-- Events that fall due during the processing of the current events will not
-- be triggered.  Rather they will be processed on the next call.
-- The rinApp application framework takes care of calling this for you.
-- @see delayUntilNext
-- @usage
-- local timers = require 'rinSystem.rinTimers.Pack'
--
-- timers.processTimeouts()
function _M.processTimeouts()
	local now = monotonictime()

    while timers[1] ~= nil and timers[1].when <= now do
        local delete = true
    	local event = pop()
        -- callback
        if active(event) then
        	event.cb(unpack(event.args))
            -- reschedule
            if event.rept and event.rept > 0 then
                if event.regular then
                    event.when = event.when + (1 + floor((now - event.when) / event.rept)) * event.rept
                else
        	        event.when = monotonictime() + event.rept
                end
        	    push(event)
                delete = false
            end
        end
        if event == lastEventTimer then
            lastEventTimer = nil
        end
        if delete then
            _M.removeTimer(event)
        end
    end
end

-------------------------------------------------------------------------------
-- Close down and stop all timers.
-- The rinApp application framework takes care of calling this for you.
-- Calling this yourself is likely to cause portions of the runApp application
-- framework to cease correctly functioning.
-- @usage
-- local timers = require 'rinSystem.rinTimers.Pack'
--
-- timers.reset()
function _M.reset()
    lastEventTimer = nil
    timers = {}
end

return _M
