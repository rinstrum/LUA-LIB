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

-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console
-------------------------------------------------------------------------------
local function handleWeightStream(data, err)
-- insert code here to handle changes in weight
   print('Weight = ',data)    
end
dwi.addStream(dwi.REG_GROSSNET, handleWeightStream, 'change')
-- choose a different register if you want to track other than GROSSNET weight



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
  print ('New Status = ', status, state) 
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
local tickerStart = 500    -- time in millisec until timer events start triggering
local tickerRepeat = 100  -- time in millisec that the timer repeats
local tick = 0

local zero_sim = 5000
local full_sim = 40000
local inc_sim = 100
local sim = zero_sim
local sim_dir = 1
sim_start = true
local function ticker()
-- insert code here that you want to run on each timer event
   dwi.writeAnalogRaw(sim)
   if sim_start then
      sim = sim + (sim_dir * inc_sim)
      if (sim > full_sim) then
         sim_dir = -1
      end
      if (sim < zero_sim) then
         sim_dir = 1  
      end
    end      
  
   
end
rinApp.system.timers.addTimer(tickerRepeat,tickerStart,ticker)




-------------------------------------------------------------------------------
-- Key Handler for F1 
-------------------------------------------------------------------------------
local function F1Pressed(key, state)
    print('F1 Pressed')
    if state == 'long' then
        sim = zero_sim
    else    
      inc_sim = inc_sim * 2
      if inc_sim > 1000 then inc_sim = 1000 end
    end  
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)

-------------------------------------------------------------------------------
-- Key Handler for F2 
-------------------------------------------------------------------------------
local function F2Pressed(key, state)
     print('F2 Pressed')
     if state == 'long' then
        sim = full_sim
     else
        inc_sim = inc_sim / 2
        if (inc_sim < 100) then inc_sim = 100 end
     end   
    return true -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F2, F2Pressed)

-------------------------------------------------------------------------------
-- Key Handler for F3 
-------------------------------------------------------------------------------
local function F3Pressed(key, state)
    sim_start = not sim_start
    print('\27[HF3 Pressed')
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

dwi.writeBotLeft('  MY APP')
dwi.writeBotRight(' .LUA')


-------------------------------------------------------------------------------
-- Main Application Loop
-------------------------------------------------------------------------------
while rinApp.running do
 -- dwi.delay(500)
 -- dwi.buzz(2)
  rinApp.system.handleEvents()           -- handleEvents runs the event handlers 
end  

-------------------------------------------------------------------------------
-- cleanup and exit
-------------------------------------------------------------------------------

rinApp.cleanup()                   -- shutdown application resources


