-------------------------------------------------------------------------------
-- K412 analogue
-- 
-- example of using the analogue module to perform a batch
-- 
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local rinApp = require "rinApp"
local K412 = rinApp.addK412()--"172.17.1.132", 2222)
local system = rinApp.system
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- variables
local FAST_VOLTS = 7.5
local MED_VOLTS = 6
local SLOW_VOLTS = 5
local OFF_VOLTS = 0
local LAST_VOLTS

local SPEED_NONE = 0
local SPEED_SLOW = 1
local SPEED_MED = 2
local SPEED_FAST = 3
local SPEED = SPEED_NONE

local NOT_RUNNING = 0
local RUNNING = 1
local BATCH_RUN = NOT_RUNNING

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
   -- keep local variables up to date
   if (active == true) then
      if status == K412.STAT_RUN then BATCH_RUN = RUNNING
      elseif status == K412.STAT_FAST then SPEED = SPEED_FAST
      elseif status == K412.STAT_MED then SPEED = SPEED_MED
      elseif status == K412.STAT_SLOW then SPEED = SPEED_SLOW
      else SPEED = SPEED_NONE end
   else
      if status == K412.STAT_RUN then BATCH_RUN = NOT_RUNNING end
   end
   
   -- set required voltage if the batch is running
   if (BATCH_RUN == RUNNING) then 
      if SPEED == SPEED_FAST then ANALOGUE_VOLTS = FAST_VOLTS end
      if SPEED == SPEED_MED then ANALOGUE_VOLTS = MED_VOLTS end
      if SPEED == SPEED_SLOW then ANALOGUE_VOLTS = SLOW_VOLTS end
   end
   -- OFF_VOLTS for all other states
   setAnalogVolts (ANALOGUE_VOLTS)
end
K412.setStatusCallback(K412.STAT_FAST, statusChanged)
K412.setStatusCallback(K412.STAT_MED, statusChanged)
K412.setStatusCallback(K412.STAT_SLOW, statusChanged)
K412.setStatusCallback(K412.STAT_TIME, statusChanged)
K412.setStatusCallback(K412.STAT_INPUT, statusChanged)
K412.setStatusCallback(K412.STAT_NO_INFO, statusChanged)
K412.setStatusCallback(K412.STAT_RUN, statusChanged)
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
K412.delay(500)                    -- delay for 500 msec
dbg.printVar(K412.readRegWait(K412.REG_SERIALNO))  -- example of how to use debug and read instument registers

-- Main Application Loop
while rinApp.running do
   system.handleEvents()           -- handleEvents runs the event handlers 
end  

-- cleanup and exit
setAnalogVolts (OFF_VOLTS)
rinApp.cleanup()				   -- shutdown application resources

