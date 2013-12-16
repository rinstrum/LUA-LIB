
-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"

-- Add control of an L401 at the given IP and port
local K401 = rinApp.addK400("K401")



------------------------------------------------------------------------------
-- Key Handler for F1 
local function F1Pressed(key, state)
    if state == 'short' then
        rinApp.dbg.printVar ('F1 pressed')
        K401.buzz(3)  -- sound buzzer 3 times to acknowledge keypress
        rinApp.dbg.configureDebug(rinApp.dbg.DEBUG)
        s = K401.reqCustomTransmit('Testing 1..2..3')
        rinApp.dbg.printVar(s)
        rinApp.dbg.configureDebug('info')
       end 
    return true    -- F1 handled here so don't send back to instrument for handling
end
K401.setKeyCallback(K401.KEY_F1, F1Pressed)



-------------------------------------------------------------------------------
-- Handler to capture ABORT key and end program
local function cancelPressed(key, state)
    if state == 'long' then
      rinApp.running = false
      return true
    end 
    return false
end
K401.setKeyCallback(K401.KEY_CANCEL, cancelPressed)

-- Main Application Loop
while rinApp.running do
   rinApp.system.handleEvents()           -- handleEvents runs the event handlers 
end  