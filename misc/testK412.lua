-------------------------------------------------------------------------------
-- clicker
-- 
-- example of using keys, timers and streams to control instrument display 
-- and outputs   
-- 
-------------------------------------------------------------------------------

local rinApp = require "rinApp"
local K412 = rinApp.addK412("172.17.1.134", 2222)
local system = rinApp.system
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console
local function handleWeightStream(data, err)
	dbg.printVar(data)
end
local wgt = K412.addStream(K412.REG_GROSSNET, handleWeightStream, 'change')


-------------------------------------------------------------------------------
-- Timer to rotate activity annunciator on LCD screen
local function twiddle()
       K412.rotWAIT(1) 
end
local twiddler = system.timers.addTimer(500,100,twiddle)

-------------------------------------------------------------------------------
local CLICKER_OUTPUT = 3   -- configure which physical Output to drive

-------------------------------------------------------------------------------
-- toggle CLICKER_OUTPUT using a timer callback
local lastClick = false
local function click()
	if lastClick then
		K412.turnOn(CLICKER_OUTPUT)
	else 
		K412.turnOff(CLICKER_OUTPUT)
	end
	lastClick = not lastClick  
end
local clicker = system.timers.addTimer(1000,50,click)  -- run click() every 500 msecs after an initial 50msec delay



-------------------------------------------------------------------------------
-- Callback to capture changes to Motion,Net and Zero status  
local function statusChanged(status, active)
   local s = ''
   if active then s = 'Active ' else s = 'Inactive ' end
   dbg.printVar(status, s)
end
K412.setStatusCallback(K412.STAT_MOTION, statusChanged)
K412.setStatusCallback(K412.STAT_NET, statusChanged)
K412.setStatusCallback(K412.STAT_ZERO, statusChanged)
-- statusChanged() called whenever Motion, Gross/Net or Zero status 
-- changes on the instrument
--------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Key Handler for F1 
local function F1Pressed(key, state)
	if state == 'short' then
        dbg.printVar ('F1 pressed')
		K412.buzz(3)  -- sound buzzer 3 times to acknowledge keypress
	end	
	return true    -- F1 handled here so don't send back to instrument for handling
end
K412.setKeyCallback(K412.KEY_F1, F1Pressed)

-------------------------------------------------------------------------------
-- F2 handler, reads instrument Serial Number
local function F2Pressed(key, state)
	dbg.printVar (K412.readRegWait(K412.REG_SERIALNO))
    return true
end
K412.setKeyCallback(K412.KEY_F2, F2Pressed)


-------------------------------------------------------------------------------
-- F3 handler : toggles date format from mm-dd-yy to dd-mm-yy      
local function F3Pressed(key, state)
	if K412.RTC.first == 'day' then
		      K412.RTCdateFormat('month','day','year')
			  K412.sendDateFormat(K412.TM_MMDDYYYY)
	else 	  
              K412.RTCdateFormat('day','month','year')
			  K412.sendDateFormat(K412.TM_DDMMYYYY)
	end	
    return true
end
K412.setKeyCallback(K412.KEY_F3, F3Pressed)


-------------------------------------------------------------------------------
-- Handler to capture ABORT key and end program
local function cancelPressed(key, state)
	if state == 'long' then
      rinApp.running = false
      return true
	end	
	return false
end
K412.setKeyCallback(K412.KEY_CANCEL, cancelPressed)

-------------------------------------------------------------------------------
-- Key Handler to demonstrate use of Handling Key Groups
-- note that the KEY_ZERO key is handled locally hence the return true
-- other keys are passed back to other handlers and ultimately to the 
-- instrument to process
local function primary(key, state)
  if key == K412.KEY_ZERO then
     print(key, "block Zero key")
	 return true
  end
  print (key, "ok")
  return false  
end
K412.setKeyGroupCallback(K412.keyGroup.primary, primary)

-------------------------------------------------------------------------------
-- Handler to capture changes to hardware Real Time CLock and maintain 
-- a local awareness of time/date 
--[[local function RTCHandler(stat, change)
   K412.RTCtick()
   dbg.printVar(K412.RTCtostring())
end
K412.RTCread();
K412.setStatusCallback(K412.STAT_RTC, RTCHandler)]]--

-------------------------------------------------------------------------------
-- Setup the LCD screen and initialise the application
K412.writeBotLeft("CLICKER")
K412.enableOutput(CLICKER_OUTPUT)  -- CLICKER_OUTPUT can now be controlled directly from LUA
K412.delay(500)                    -- delay for 500 msec
dbg.printVar(K412.readRegWait(K412.REG_SERIALNO))  -- example of how to use debug and read instument registers

-- Main Application Loop
while rinApp.running do
   system.handleEvents()           -- handleEvents runs the event handlers 
end  

-- cleanup and exit
K412.turnOff(CLICKER_OUTPUT)       -- make sure CLICKER_OUTPUT is turned off before ending
K412.releaseOutput(CLICKER_OUTPUT) -- release CLICKER_OUTPUT from LUA control
rinApp.cleanup()				   -- shutdown application resources

