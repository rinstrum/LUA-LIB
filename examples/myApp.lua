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
-------------------------------------------------------------------------------
local rinApp = require "rinApp"     --  load in the application framework


--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local dwi = rinApp.addK400("K401")  --  make a connection to the instrument


--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

-------------------------------------------------------------------------------
--  Callback to capture changes to current weight
local curWeight = 0
local function handleNewWeight(data, err)
-- insert code here to handle changes in weight
   curWeight = data
   print('Weight = ',curWeight)  
end
dwi.addStream(dwi.REG_GROSSNET, handleNewWeight, 'change')
-- choose a different register if you want to track other than GROSSNET weight
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to monitor motion status  
local function handleMotion(status, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then 
     print ('motion')
  else 
     print('stable')  
   end   
end
dwi.setStatusCallback(dwi.STAT_MOTION, handleMotion)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status  
local function handleIO1(IO, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then 
     print ('IO 1 is on ')
  else
     print ('IO 1 is off ')
  end   
end
dwi.setIOCallback(1, handleIO1)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 100    -- time in millisec until timer events start triggering
local tickerRepeat = 2000  -- time in millisec that the timer repeats
local tick = 0

local function ticker()
-- insert code here that you want to run on each timer event
    tick = tick + 1
    print('Ticks: ', tick)    
end
rinApp.system.timers.addTimer(tickerRepeat,tickerStart,ticker)
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Callback to handle F1 key event 
local function F1Pressed(key, state)
    
    if state == 'long' then
        print('Long F1 Pressed')
    else    
        print('F1 Pressed')
    end  
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
local function pwrCancelPressed(key, state)
    if state == 'long' then
      rinApp.running = false
      return true
    end 
    return false
end
dwi.setKeyCallback(dwi.KEY_PWR_CANCEL, pwrCancelPressed)
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation 
--=============================================================================
--  This is a good place to put your initialisation code 
-- (eg, setup outputs or put a message on the LCD etc)

dwi.writeBotLeft('  MY APP')
dwi.writeBotRight(' .LUA')
dwi.enableOutput(1)

--=============================================================================
-- Main Application Loop
--=============================================================================
-- mainLoop gets continually called by the framework
-- Main Application logic goes here
function mainLoop()
     print(dwi.getKey())
     dwi.turnOnTimed(1,500)
end
rinApp.setMainLoop(mainLoop)       -- register mainLoop with the framework
rinApp.run()                       -- run the application framework
rinApp.cleanup()                   -- shutdown application resources


