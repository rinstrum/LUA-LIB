-------------------------------------------------------------------------------
-- Marquee
-- 
-- Allows for marquee messages to be displayed across the screen
-- 
-- POSSIBLE EXERCISE: 
-- Write a keyboard callback that allows dynamic editing of the scrolling speed
-- when the up and down keys are pressed
-- 
-- Hint: you will have to stop and start the slide timer
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local rinApp = require "rinApp"
local dwi = rinApp.addK400("K401")

local msg = ''
-------------------------------------------------------------------------------
-- This is a timer callback that moves a message across the screen
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

-- Start a time that will call slide
-- The timer has a 400ms delay between iterations, which can be easily altered
-- The timer has a 100ms delay before it starts for the first time
local slider = rinApp.system.timers.addTimer(400, 100, slide)


-- Format the string for slide
local function showMarquee (s)
   msg = '        ' ..  s
end

-------------------------------------------------------------------------------
-- Key handler
local function handleKey(key, state)
    showMarquee(string.format("%s Pressed ", key))
    if key == dwi.KEY_PWR_CANCEL and state == 'long' then 
        rinApp.running = false
    end
    return true     -- key handled so don't send back to instrument
end

dwi.setKeyGroupCallback(dwi.keyGroup.all, handleKey)

-- Print a message
showMarquee("This is a very long message for a small LCD screen")

-- Loop and print key presses to the screen
-- If abort is pressed, break the loop
while rinApp.running do
   rinApp.system.handleEvents()
end

-- Clean up and exit
rinApp.system.timers.removeTimer(slider)
rinApp.cleanup()