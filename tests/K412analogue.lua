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
local K412 = rinApp.addK412()--"172.17.1.132", 2222)
local system = rinApp.system
local dbg = rinApp.dbg
--local str = string  -- TODO testing

-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console
--[[local function handleWeightStream(data, err)
	dbg.printVar(data)
end
local wgt = K412.addStream(K412.REG_GROSSNET, handleWeightStream, 'change')
]]--

-------------------------------------------------------------------------------
local FAST_VOLTS = 7.5
local MED_VOLTS = 6
local SLOW_VOLTS = 5
local OFF_VOLTS = 0
local LAST_VOLTS
local RUNNING

-------------------------------------------------------------------------------
-- Do the actual analogue voltage setting  
local function setAnalogVolts (volts)
   if volts ~= LAST_VOLTS then
      K412.setAnalogVolt(volts)
      LAST_VOLTS = volts
      dbg.printVar("volts", volts)
   end
end

-------------------------------------------------------------------------------
-- Callback to capture changes to batch info status  
local function statusChanged(status, active)
   local ANALOGUE_VOLTS = OFF_VOLTS
   -- set analogue back to 0V on pause or abort
   --[[if status == K412.RUN then 
      RUNNING = active
      if active == false then
        setAnalogVolts (ANALOGUE_VOLTS)
      end
   end]]--
   -- set required voltage if the batch is running
   if (active == true) then --and (RUNNING == true) then 
      if status == K412.STAT_FAST then ANALOGUE_VOLTS = FAST_VOLTS end
      if status == K412.STAT_MED then ANALOGUE_VOLTS = MED_VOLTS end
      if status == K412.STAT_SLOW then ANALOGUE_VOLTS = SLOW_VOLTS end
      -- OFF_VOLTS for all other states
      setAnalogVolts (ANALOGUE_VOLTS)
   end
end
K412.setStatusCallback(K412.STAT_FAST, statusChanged)
K412.setStatusCallback(K412.STAT_MED, statusChanged)
K412.setStatusCallback(K412.STAT_SLOW, statusChanged)
K412.setStatusCallback(K412.STAT_TIME, statusChanged)
K412.setStatusCallback(K412.STAT_INPUT, statusChanged)
K412.setStatusCallback(K412.STAT_NO_INFO, statusChanged)
--K412.setStatusCallback(K412.STAT_RUN, statusChanged)
-- statusChanged() called whenever batch info status 
-- changes on the instrument


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
-- Setup the LCD screen and initialise the application
--K412.writeBotLeft("CLICKER")
--K412.enableOutput(CLICKER_OUTPUT)  -- CLICKER_OUTPUT can now be controlled directly from LUA
K412.delay(500)                    -- delay for 500 msec
dbg.printVar(K412.readRegWait(K412.REG_SERIALNO))  -- example of how to use debug and read instument registers

-- Main Application Loop
while rinApp.running do
   system.handleEvents()           -- handleEvents runs the event handlers 
end  

-- cleanup and exit
--K412.turnOff(CLICKER_OUTPUT)       -- make sure CLICKER_OUTPUT is turned off before ending
--K412.releaseOutput(CLICKER_OUTPUT) -- release CLICKER_OUTPUT from LUA control
rinApp.cleanup()				   -- shutdown application resources

