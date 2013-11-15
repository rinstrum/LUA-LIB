-------------------------------------------------------------------------------
-- clicker
-- 
-- example of using keys, timers and streams to control instrument display 
-- and outputs   
-- 
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"
local rinApp = require "rinApp"
local K401 = rinApp.addK400("K401")
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console
local function handleWeightStream(data, err)
    dbg.printVar(data)
end
local wgt = K401.addStream(K401.REG_GROSSNET, handleWeightStream, 'change')


-------------------------------------------------------------------------------
-- Timer to rotate activity annunciator on LCD screen
local function twiddle()
       K401.rotWAIT(1) 
end
local twiddler = rinApp.system.timers.addTimer(500,100,twiddle)

-------------------------------------------------------------------------------
local CLICKER_OUTPUT = 3   -- configure which physical Output to drive

-------------------------------------------------------------------------------
-- toggle CLICKER_OUTPUT using a timer callback
local lastClick = false
local function click()
    if lastClick then
        K401.turnOn(CLICKER_OUTPUT)
    else 
        K401.turnOff(CLICKER_OUTPUT)
    end
    lastClick = not lastClick  
end
local clicker = rinApp.system.timers.addTimer(1000,50,click)  -- run click() every 500 msecs after an initial 50msec delay



-------------------------------------------------------------------------------
-- Callback to capture changes to Motion,Net and Zero status  
local function statusChanged(status, active)
   local s = ''
   if active then s = 'Active ' else s = 'Inactive ' end
   dbg.printVar(status, s)
end
K401.setStatusCallback(K401.STAT_MOTION, statusChanged)
K401.setStatusCallback(K401.STAT_NET, statusChanged)
K401.setStatusCallback(K401.STAT_ZERO, statusChanged)
-- statusChanged() called whenever Motion, Gross/Net or Zero status 
-- changes on the instrument
--------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Key Handler for F1 
local function F1Pressed(key, state)
    if state == 'short' then
        dbg.printVar ('F1 pressed')
        K401.buzz(3)  -- sound buzzer 3 times to acknowledge keypress
    else
        K401.setAnalogVolt(10)
    end 
    return true    -- F1 handled here so don't send back to instrument for handling
end
K401.setKeyCallback(K401.KEY_F1, F1Pressed)

-------------------------------------------------------------------------------
-- F2 handler, reads instrument Serial Number
local function F2Pressed(key, state)
    dbg.printVar (K401.readReg(K401.REG_SERIALNO))
    K401.setAnalogVolt(0)
    return true
end
K401.setKeyCallback(K401.KEY_F2, F2Pressed)


-------------------------------------------------------------------------------
-- F3 handler : toggles date format from mm-dd-yy to dd-mm-yy      
local function F3Pressed(key, state)
    if K401.RTC.first == 'day' then
              K401.RTCdateFormat('month','day','year')
              K401.sendDateFormat(K401.TM_MMDDYYYY)
    else      
              K401.RTCdateFormat('day','month','year')
              K401.sendDateFormat(K401.TM_DDMMYYYY)
    end 
    return true
end
K401.setKeyCallback(K401.KEY_F3, F3Pressed)


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

-------------------------------------------------------------------------------
-- Key Handler to demonstrate use of Handling Key Groups
-- note that the KEY_ZERO key is handled locally hence the return true
-- other keys are passed back to other handlers and ultimately to the 
-- instrument to process
local function primary(key, state)
  if key == K401.KEY_ZERO then
     print(key, "block Zero key")
     return true
  end
  dbg.printVar('Key:',key)
  return false  
end
K401.setKeyGroupCallback(K401.keyGroup.primary, primary)

-------------------------------------------------------------------------------
-- Handler to capture changes to hardware Real Time CLock and maintain 
-- a local awareness of time/date 
local function RTCHandler(stat, change)
   K401.RTCtick()
   dbg.printVar(K401.RTCtostring())
end
K401.RTCread();
K401.setStatusCallback(K401.STAT_RTC, RTCHandler)

-------------------------------------------------------------------------------
-- Setup the LCD screen and initialise the application
K401.writeBotLeft("CLICKER")
K401.enableOutput(CLICKER_OUTPUT)  -- CLICKER_OUTPUT can now be controlled directly from LUA
K401.delay(500)                    -- delay for 500 msec
dbg.printVar(K401.readReg(K401.REG_SERIALNO))  -- example of how to use debug and read instument registers

-- Main Application Loop
while rinApp.running do
   rinApp.system.handleEvents()           -- handleEvents runs the event handlers 
end  

-- cleanup and exit
K401.turnOff(CLICKER_OUTPUT)       -- make sure CLICKER_OUTPUT is turned off before ending
K401.releaseOutput(CLICKER_OUTPUT) -- release CLICKER_OUTPUT from LUA control
rinApp.cleanup()                   -- shutdown application resources

