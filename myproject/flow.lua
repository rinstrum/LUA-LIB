-------------------------------------------------------------------------------
-- myApp
-- 
-- Application template
--    
-- Copy this file to your project directory and insert the specific code of 
-- your application
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"
local rinApp = require "rinApp"

local dwi = rinApp.addK400("K401")  -- replace this with the instrument application name if other than K401



local function calcMassInc(fRate, tm)       -- calculate the Mass which has passed the instrument in the given timeDiff
    local tm = tm or 0 
    local unitConversionFactor = 1/3600000      -- the number to convert raw Flow Rate (eg. T/hr) to Mass over millisecond time periods
   
    return fRate * tm * unitConversionFactor    -- return the result
end

local PULSE_OUTPUT = 4



-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console
-------------------------------------------------------------------------------
local curWeight = 0

local function handleWeightStream(data, err)
-- insert code here to handle changes in weight
   curWeight = data    
end
dwi.addStream(dwi.REG_GROSSNET, handleWeightStream, 'change')
-- choose a different register if you want to track other than GROSSNET weight


local conversionFactor = 0.8  -- relationship between measured force and flow rate
local flowRate = 0
local massInc = 0
local mass = 0
local pulseMass = 0
local pulseTick = 0.5
local function handleTimeStamp(data, err)
    if lastTimeStamp then 
        deltaTime = data - lastTimeStamp
    end
    lastTimeStamp = data    
    flowRate = curWeight * conversionFactor
    massInc = calcMassInc(flowRate,deltaTime)
    mass = mass + massInc
    pulseMass = pulseMass + massInc
    if pulseMass > pulseTick then
       pulseMass = pulseMass - pulseTick
       dwi.turnOnTimed(PULSE_OUTPUT,500)
    end   
end
dwi.addStream(dwi.REG_MSECLAST , handleTimeStamp,'change')


-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status  
-------------------------------------------------------------------------------
local function statusChanged(status, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then 
     state = ' On'
  else 
     state = ' Off'  
   end  
--  print ('New Status = ', status, state) 
end
dwi.setStatusCallback(dwi.STAT_MOTION, statusChanged)
dwi.setStatusCallback(dwi.STAT_NET, statusChanged)
dwi.setStatusCallback(dwi.STAT_ZERO, statusChanged)
-- statusChanged() called whenever Motion, Gross/Net or Zero status 
-- changes on the instrument
--------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- local timer function runs at the rate set below
-------------------------------------------------------------------------------
local tickerStart = 100    -- time in millisec until timer events start triggering
local tickerRepeat = 500  -- time in millisec that the timer repeats


local maxFlowRate = 500

local function ticker()
-- insert code here that you want to run on each timer event
   
   if not dwi.isEditing() then 
       dwi.writeBotLeft(string.format("%9.0f",flowRate))
    end   
 
   dwi.writeTopLeft(string.format("%6.2f",mass))
   dwi.rotWAIT(-1)
   dwi.setAnalogVal(flowRate/maxFlowRate)
 
end
rinApp.system.timers.addTimer(tickerRepeat,tickerStart,ticker)




local getMaterial = false
-------------------------------------------------------------------------------
-- Key Handler for F1 
-------------------------------------------------------------------------------
local function F1Pressed(key, state)
    
    getMaterial = true
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)

-------------------------------------------------------------------------------
-- Key Handler for F2 
-------------------------------------------------------------------------------
local function F2Pressed(key, state)
    if state == 'long' then
        print('Long F2 Pressed')
    else    
        print('F2 Pressed')
    end  
    return true -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F2, F2Pressed)

-------------------------------------------------------------------------------
-- Key Handler for F3 
-------------------------------------------------------------------------------
local function F3Pressed(key, state)
    if state == 'long' then
        print('Long F3 Pressed')
    else    
        print('F3 Pressed')
    end  
    return true -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F3, F3Pressed)

-------------------------------------------------------------------------------
-- Handler to capture PWR+ABORT key and end program
-------------------------------------------------------------------------------
local function pwrCancelPressed(key, state)
    if state == 'long' then
      rinApp.running = false
      return true
    end 
    return false
end
dwi.setKeyCallback(dwi.KEY_PWR_CANCEL, pwrCancelPressed)




-------------------------------------------------------------------------------
-- Initialisation 
-------------------------------------------------------------------------------
--  This is a good place to put your initialisation code 
-- (eg, setup outputs or put a message on the LCD etc)

dwi.setAutoTopLeft(0)
dwi.setAutoTopAnnun(0)

dwi.writeBotUnits(dwi.UNITS_KG, dwi.UNITS_OTHER_PER_H)
dwi.writeTopUnits(dwi.UNITS_KG)

dwi.enableOutput(PULSE_OUTPUT)





-------------------------------------------------------------------------------
-- Main Application Loop
-------------------------------------------------------------------------------
while rinApp.running do
  if getMaterial then
    print (dwi.selectOption('MATERIAL',{'SEED','WHEAT','BARLEY','CORN'},'WHEAT',true),'  ','Selected.')
    getMaterial = false
  end  
  rinApp.system.handleEvents()           -- handleEvents runs the event handlers 
end  

-------------------------------------------------------------------------------
-- cleanup and exit
-------------------------------------------------------------------------------

rinApp.cleanup()                   -- shutdown application resources
dwi.releaseOutput(PULSE_OUTPUT)

