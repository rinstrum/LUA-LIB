-------------------------------------------------------------------------------
-- myApp
-- 
-- Application template
--    
-- Copy this file to your project directory and insert the specific code of 
-- your application
-------------------------------------------------------------------------------
-- Include the src directory
package.path = "/home/src/?.lua;" .. package.path 
-------------------------------------------------------------------------------
local rinApp = require "rinApp"     --  load in the application framework
local timers = requre 'rinSystem.rinTimers.Pack'

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument
dwi.loadRIS("myApp.RIS")               -- load default instrument settings

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

local msg = ''
-------------------------------------------------------------------------------
-- Callback for local timer
local slideStart = 0.100    -- time in seconds until timer events start triggering
local slideRepeat = 0.400  -- time in seconds that the timer repeats

local function slide()

    -- Check if message is finished
    if msg == false then 
        return 
    end

    -- If there's nothing left to move, clear the screen
    -- and write the msg to false so we know we're done
    if msg == '' then
        dwi.writeBotLeft('')
        msg = false
        
    -- If there's something left to write, write a substring of 9 characters
    -- to the device and remove a character from the message
    else   
        dwi.writeBotLeft(string.format('%-9s',string.upper(string.sub(msg,1,9))))
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
    if key == dwi.KEY_PWR_CANCEL and state == 'long' then 
        rinApp.running = false
    end
    return true     -- key handled so don't send back to instrument
end
dwi.setKeyGroupCallback(dwi.keyGroup.all, handleKey)

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
local function pwrCancelPressed(key, state)
    if state == 'long' then
      rinApp.running = false
      return true
    end 
    return false
end
dwi.setKeyCallback(dwi.KEY_PWR_CANCEL, pwrCancelPressed)
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation 
--=============================================================================
--  This is a good place to put your initialisation code 
-- (eg, setup outputs or put a message on the LCD etc)

showMarquee("This is a very long message for a small LCD screen")

--=============================================================================
-- Main Application Loop
--=============================================================================
-- mainLoop gets continually called by the framework
-- Main Application logic goes here
function mainLoop()
     
end
rinApp.setMainLoop(mainLoop)       -- register mainLoop with the framework
rinApp.run()                       -- run the application framework

--=============================================================================
-- Clean Up 
--=============================================================================
-- Put any application clean up here

rinApp.cleanup()                   -- shutdown application resources
