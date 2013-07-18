-------------------------------------------------------------------------------
-- clicker
-- 
-- example of using keys, timers and streams to control instrument display 
-- and outputs   
-- 
-------------------------------------------------------------------------------

local rinApp = require "rinApp"
local L401 = rinApp.addL401("172.17.1.95", 2222)
local system = rinApp.system
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console
local function handleWeightStream(data, err)
	dbg.printVar(data)
end
local wgt = L401.addStream(L401.REG_GROSSNET, handleWeightStream, 'change')


-------------------------------------------------------------------------------
-- Timer to rotate activity annunciator on LCD screen
local function twiddle()
       L401.rotWAIT(1) 
end
local twiddler = system.timers.addTimer(250,100,twiddle)

-------------------------------------------------------------------------------
local CLICKER_OUTPUT = 3   -- configure which physical Output to drive

-------------------------------------------------------------------------------
-- toggle CLICKER_OUTPUT using a timer callback
local lastClick = false
local function click()
	if lastClick then
		L401.turnOn(11)
	else 
		L401.turnOff(11)
	end
	lastClick = not lastClick  
end
local clicker = system.timers.addTimer(500,50,click)  -- run click() every 500 msecs after an initial 50msec delay



-------------------------------------------------------------------------------
-- Callback to capture changes to Motion,Net and Zero status  
local function statusChanged(status, active)
   local s = ''
   if active then s = 'Active ' else s = 'Inactive ' end
   dbg.printVar(status, s)
end
L401.setStatusCallback(L401.STAT_MOTION, statusChanged)
L401.setStatusCallback(L401.STAT_NET, statusChanged)
L401.setStatusCallback(L401.STAT_ZERO, statusChanged)
-- statusChanged() called whenever Motion, Gross/Net or Zero status 
-- changes on the instrument
--------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Key Handler for F1 
local function F1Pressed(key, state)
	if state == 'short' then
        dbg.printVar ('F1 pressed')
		L401.buzz(3)  -- sound buzzer 3 times to acknowledge keypress
	end	
	return true    -- F1 handled here so don't send back to instrument for handling
end
L401.setKeyCallback(L401.KEY_F1, F1Pressed)

-------------------------------------------------------------------------------
-- F2 handler, reads instrument Serial Number
local function F2Pressed(key, state)
	dbg.printVar (L401.readRegWait(L401.REG_SERIALNO))
    return true
end
L401.setKeyCallback(L401.KEY_F2, F2Pressed)


-------------------------------------------------------------------------------
-- F3 handler : toggles date format from mm-dd-yy to dd-mm-yy      
local function F3Pressed(key, state)
	if L401.RTC.first == 'day' then
		      L401.RTCdateFormat('month','day','year')
			  L401.sendDateFormat(L401.TM_MMDDYYYY)
	else 	  
              L401.RTCdateFormat('day','month','year')
			  L401.sendDateFormat(L401.TM_DDMMYYYY)
	end	
    return true
end
L401.setKeyCallback(L401.KEY_F3, F3Pressed)


-------------------------------------------------------------------------------
-- Handler to capture ABORT key and end program
local function cancelPressed(key, state)
	if state == 'long' then
      rinApp.running = false
	end	
	return true
end
L401.setKeyCallback(L401.KEY_CANCEL, cancelPressed)

-------------------------------------------------------------------------------
-- Key Handler to demonstrate use of Handling Key Groups
-- note that the KEY_ZERO key is handled locally hence the return true
-- other keys are passed back to other handlers and ultimately to the 
-- instrument to process
local function primary(key, state)
  if key == L401.KEY_ZERO then
     print(key, "block Zero key")
	 return true
  end
  print (key, "ok")
  return false  
end
L401.setKeyGroupCallback(L401.keyGroup.primary, primary)

-------------------------------------------------------------------------------
-- Handler to capture changes to hardware Real Time CLock and maintain 
-- a local awareness of time/date 
local function RTCHandler(stat, change)
   L401.RTCtick()
   dbg.printVar(L401.RTCtostring())
end
L401.RTCread();
L401.setStatusCallback(L401.STAT_RTC, RTCHandler)

-------------------------------------------------------------------------------
-- Setup the LCD screen and initialise the application
L401.writeBotLeft("CLICKER")
L401.enableOutput(CLICKER_OUTPUT)  -- CLICKER_OUTPUT can now be controlled directly from LUA
L401.delay(500)                    -- delay for 500 msec
dbg.printVar(L401.readRegWait(L401.REG_SERIALNO))  -- example of how to use debug and read instument registers

-- Main Application Loop
while rinApp.running do
   system.handleEvents()           -- handleEvents runs the event handlers 
end  

-- cleanup and exit
L401.turnOff(CLICKER_OUTPUT)       -- make sure CLICKER_OUTPUT is turned off before ending
L401.releaseOutput(CLICKER_OUTPUT) -- release CLICKER_OUTPUT from LUA control
rinApp.cleanup()				   -- shutdown application resources

