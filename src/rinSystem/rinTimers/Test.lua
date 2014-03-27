-------------------------------------------------------------------------------
-- Basic test framework for the timer infrastructure
-- @module rinSystem.rinTimers
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local timers = require "Pack"

-- Get us an accurate clock, socket.gettime would be a substitute here for
-- non-posix systems.
require "posix"
local clock = function ()
                local s,n = posix.clock_gettime()
                return s + n * 0.000000001
              end

-- Grab a local reference to the random number generator
local random = math.random

--some state variables
local oldClock              -- the previous timer's execution time
local beginClock            -- our start time
local deadTimerList = {}    -- list of timers to be deleted

-------------------------------------------------------------------------------
-- Timer callback that removes all the timers in the dead timer list.
local function killTimers()
    print("Killing")
    for i = 1, #deadTimerList do
        timers.removeTimer(deadTimerList[i])
    end
    deadTimerList = {}
end

-------------------------------------------------------------------------------
-- Standard timer callback that logs how long since the beginning and the
-- previous timer.
local function timer(type, n)
    local now = clock()
    print(string.format("% 4d  %.6f  %3s  %.6f", n, now - beginClock, type, now-oldClock))
    oldClock = now
end

-- Define the different kinds of timer we have
local funcs
funcs = {
    -- A standard timer, just runs forever at a specific interval
    function (dt, nt, n)
        print(string.format("% 4d  %.6f  %3s  %.6f", n, dt, "STD", nt))
        timers.addTimer(nt, dt, function () timer("std", n) end)
    end,

    -- A dying timer, just like the above but this gets put into the die list
    -- so it will stop when the kill timer runs.
    function (dt, nt, n)
        print(string.format("% 4d  %.6f  %3s  %.6f", n, dt, "DIE", nt))
        table.insert(deadTimerList, timers.addTimer(nt, dt, function () timer("die", n) end))
    end,

    -- The kill timer.  This timer kills off all the dying timers.
    -- There can be only one.
    function (dt, nt, n)
        print(string.format("% 4d  %.6f  KILL", n, dt))
        timers.addTimer(0, dt, killTimers)
        funcs[3] = nil
    end
}

-- Initialise times and seed the random number generator
beginClock = clock()
oldClock = clock()
math.randomseed(oldClock)

-- Create a random selection of timers
for i=1, 10 do
    local dt = math.random() * 3.33
    local nt = math.random() * 2.54
    local type = math.random(#funcs)
    
    funcs[type](dt, nt, i)
end

-- Add a visual break to the output
print ""

-- For the next ten seconds, busy wait until the next timer event and trigger
-- the timers.
while clock() - beginClock < 10 do
    while timers.delayUntilNext() and timers.delayUntilNext() > 0 do
    end
    timers.processTimeouts()
end

