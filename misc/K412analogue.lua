-------------------------------------------------------------------------------
-- K412 analogue
-- 
-- example of using the analogue module to perform a batch
-- 
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local rinApp = require "rinApp"
local K412 = rinApp.addK412()--"172.17.1.75", 2222)
local system = rinApp.system
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- variables
local FAST_VOLTS = 7.5
local MED_VOLTS = 6
local SLOW_VOLTS = 5
local OFF_VOLTS = 0
local lastVolts

local SPEED_NONE = 0
local SPEED_SLOW = 1
local SPEED_MED = 2
local SPEED_FAST = 3
local speed = SPEED_NONE

local NOT_RUNNING = 0
local RUNNING = 1
local batchRun = NOT_RUNNING

-------------------------------------------------------------------------------
-- Do the actual analogue voltage setting
local function setAnalogVolts (volts)
   if volts ~= lastVolts then
      K412.setAnalogVolt(volts)
      lastVolts = volts
      dbg.printVar("volts", volts)
   end
end

-------------------------------------------------------------------------------
-- Callback to capture changes to batch info status
local function statusChanged(status, active)
  local analogueVolts = OFF_VOLTS
  -- keep local variables up to date
  if (active == true) then
    if status == K412.STAT_RUN then
      batchRun = RUNNING
    elseif status == K412.STAT_FAST then
      speed = SPEED_FAST
    elseif status == K412.STAT_MED then
      speed = SPEED_MED
    elseif status == K412.STAT_SLOW then
      speed = SPEED_SLOW
    else
      speed = SPEED_NONE
    end
  else
    if status == K412.STAT_RUN then
      batchRun = NOT_RUNNING
    end
  end
   
  -- set required voltage if the batch is running
  if (batchRun == RUNNING) then
    if speed == SPEED_FAST then
      analogueVolts = FAST_VOLTS
    end
    if speed == SPEED_MED then
      analogueVolts = MED_VOLTS
    end
    if speed == SPEED_SLOW then
      analogueVolts = SLOW_VOLTS
    end
  end
  -- OFF_VOLTS for all other states
  setAnalogVolts (analogueVolts)
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
--[[
local function cancelPressed(key, state)
  if state == 'long' then
    rinApp.running = false
    return true
  end
    return false
end
K412.setKeyCallback(K412.KEY_CANCEL, cancelPressed)
]]--

-------------------------------------------------------------------------------
-- Initialise the application
K412.delay(500)                    -- delay for 500 msec
dbg.printVar(K412.readRegWait(K412.REG_SERIALNO))  -- example of how to use debug and read instrument registers

-- Main Application Loop
while rinApp.running do
  system.handleEvents()           -- handleEvents runs the event handlers
end

-- cleanup and exit
setAnalogVolts (OFF_VOLTS)
rinApp.cleanup()				   -- shutdown application resources

