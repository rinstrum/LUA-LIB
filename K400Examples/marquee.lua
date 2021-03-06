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
local device = rinApp.addK400()        --  make a connection to the instrument
device.loadRIS("myApp.RIS")            -- load default instrument settings

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
        device.write('bottomLeft', '')
        msg = false

    -- If there's something left to write, write a substring of 9 characters
    -- to the device and remove a character from the message
    else
        device.write('bottomLeft', string.format('%-9s',string.upper(string.sub(msg,1,9))))
        msg = string.sub(msg,2)
    end
end

timers.addTimer(slideRepeat,slideStart,slide)
-------------------------------------------------------------------------------

-- Format the string for slide
local function showMarquee (s)
   msg = '        ' ..  s
end

-------------------------------------------------------------------------------
-- Callback to handle F1 key event
local function handleKey(key, state)
    showMarquee(string.format("%s Pressed ", key))
    return true     -- key handled so don't send back to instrument
end
device.setKeyGroupCallback('all', handleKey)

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
device.setKeyCallback('pwr_cancel', rinApp.finish, 'long')
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

showMarquee("This is a very long message for a small LCD screen")

rinApp.run()                       -- run the application framework
