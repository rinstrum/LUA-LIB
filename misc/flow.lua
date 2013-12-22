-------------------------------------------------------------------------------
-- Flow Force
-- 
-- example of using keys, timers and streams to control instrument display 
-- and outputs   
-- 
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"


-------------------------------------------------------------------------------
local rinApp = require "rinApp"     -- load the main API
local dwi = rinApp.addK400("K401")  -- Connect the R420-K401 Digital Weighing Indicator


-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console


local curWeight = 0 -- Current Weight reading

local function handleWeightStream(data, err)
    curWeight = data  -- Update local copy of current weight
    rinApp.dbg.printVar('Current Weight: ',curWeight)  -- debug log of current weight at INFO level
end
dwi.addStream(dwi.REG_GROSSNET, handleWeightStream, 'change')   -- run callback whenever weight changes on dwi

local lastTimeStamp = 0
local deltaTime = 0



-------------------------------------------------------------------------------
-- Timer to sample weight every 100 msecs

local lastWeight = 0
local deltaWeight = 0
local avDelta = 0
local avLength = 5
local accWeight = 0
local flowRate = 0
local maxFlowRate = 1000  -- kg/hr
local batchTarget = 10000 -- kg
local BATCH_TOTAL_OUTPUT = 4   -- configure which physical Output to drive


local function sample()
   deltaWeight = curWeight - lastWeight
   avDelta = ((avDelta * (avLength-1))+deltaWeight)/avLength
   flowRate = avDelta * 3600000 / deltaTime   -- raw flow rate in kg/hour
   accWeight = accWeight + deltaWeight   
   lastWeight = curWeight     
   dwi.writeBotLeft(string.format("%9.0f",flowRate))
   dwi.writeBotUnits(dwi.UNITS_KG, dwi.UNITS_OTHER_PER_H)
   dwi.setAnalogVal(flowRate/maxFlowRate)               -- set analogue output 4..20mA
   if accWeight > batchTarget then
      dwi.turnOnTimed(BATCH_TOTAL_OUTPUT,1000)   -- pulse output for 1 sec
   end       
end
-- rinApp.system.timers.addTimer(100,50,sample)  -- run sample at 10 Hz

local function handleTimeStamp(data, err)
    deltaTime = data - lastTimeStamp
--    rinApp.dbg.printVar('Delta Time: ',deltaTime)  
    lastTimeStamp = data
    sample()
end
dwi.addStream(dwi.REG_MSECLAST , handleTimeStamp,'change')



-------------------------------------------------------------------------------
-- Key Handler for F1 
local function F1Pressed(key, state)
    if state == 'short' then
        rinApp.dbg.printVar ('F1 pressed')
        dwi.buzz(3)  -- sound buzzer 3 times to acknowledge keypress
    end 
    return true    -- F1 handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)


-------------------------------------------------------------------------------
-- Handler to capture ABORT key and end program
local function cancelPressed(key, state)
      rinApp.running = false
      return true
end
dwi.setKeyCallback(dwi.KEY_PWR_CANCEL, cancelPressed)


-------------------------------------------------------------------------------
-- Initialise
-------------------------------------------------------------------------------
dwi.setAnalogType(dwi.CUR)  -- set analogue output to 4-20mA
dwi.enableOutput(BATCH_TOTAL_OUTPUT)  -- BATCH_TOTAL_OUTPUT can now be controlled directly from LUA



-- Main Application Loop
while rinApp.running do
   rinApp.system.handleEvents()           -- handleEvents runs the event handlers 
end  

-- cleanup and exit
dwi.turnOff(BATCH_TOTAL_OUTPUT)       -- make sure BATCH_TOTAL_OUTPUT is turned off before ending
dwi.releaseOutput(BATCH_TOTAL_OUTPUT) -- release BATCH_TOTAL_OUTPUT from LUA control
rinApp.cleanup()                   -- shutdown application resources

