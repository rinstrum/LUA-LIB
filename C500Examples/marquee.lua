#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- myApp
--
-- Application template
--
-- Copy this file to your project directory and insert the specific code of
-- your application
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers'

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local device = rinApp.addC500()        --  make a connection to the instrument

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

local msg = ''
-------------------------------------------------------------------------------
-- Callback for local timer
local slideStart = 0.10   -- time in seconds until timer events start triggering
local slideRepeat = 0.40  -- time in seconds that the timer repeats

local function slide()

    -- Check if message is finished
    if msg == false then
        return
    end

    -- If there's nothing left to move, clear the screen
    -- and write the msg to false so we know we're done
    if msg == '' then
        device.write('topLeft', '')
        msg = false

    -- If there's something left to write, write a substring of 6 characters
    -- to the device and remove a character from the message
    else
        device.write('topLeft', string.format('%-6s',string.upper(string.sub(msg,1,6))))
        msg = string.sub(msg,2)
    end
end

timers.addTimer(slideRepeat,slideStart,slide)
-------------------------------------------------------------------------------

-- Format the string for slide
local function showMarquee (s)
   msg = '     ' ..  s .. ' '
end

-------------------------------------------------------------------------------
-- Callback to handle 'all' keygroup event
local function handleKey(key, state)
    showMarquee(string.format("%s Pressed", key))
    return true     -- key handled so don't send back to instrument
end
device.setKeyGroupCallback('all', handleKey)

-------------------------------------------------------------------------------
-- Callback to handle f1 key and end application
device.setKeyCallback('f1', rinApp.finish, 'long')
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

showMarquee("This is a very long message for a small LCD screen")

rinApp.run()                       -- run the application framework