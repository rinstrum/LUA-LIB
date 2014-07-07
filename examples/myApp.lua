-------------------------------------------------------------------------------
-- myApp
-- 
-- Application template
--    
-- Copy this file to your project directory and insert the specific code of 
-- your application
-------------------------------------------------------------------------------
-- Include the src directory
package.path = "/home/src/?.lua;" .. package.path 
-------------------------------------------------------------------------------
local rinApp = require "rinApp"     --  load in the application framework

--=============================================================================
-- Connect to the instruments you want to control
-- Define any Application variables you wish to use 
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument
dwi.loadRIS("myApp.RIS")               -- load default instrument settings

local mode = 'idle'

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

-------------------------------------------------------------------------------
--  Callback to capture changes to current weight
local curWeight = 0
local function handleNewWeight(data, err)
   curWeight = data
   print('Weight = ',curWeight)  
end
dwi.addStream('grossnet', handleNewWeight, 'change')
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

local function handleIO(data)
   rinApp.dbg.info(' IO: ', string.format('%08X',data))
end
dwi.setAllIOCallback(handleIO)

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status  
local function handleSETP1(SETP, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then 
     print ('SETP 1 is on ')
  else
     print ('SETP 1 is off ')
  end   
end
dwi.setSETPCallback(1, handleSETP1)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status  
local function handleSETP(data)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
   rinApp.dbg.info('SETP: ',string.format('%04X',data))   
end
dwi.setAllSETPCallback(handleSETP)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F1 key event 
local function F1Pressed(key, state)
    if state == 'long' then
        print('Long F1 Pressed')
    else    
        if mode == 'idle' then
            mode = 'run'
        end    
    end
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F2 key event 
local function F2Pressed(key, state)
    if state == 'long' then
        print('Long F1 Pressed')
    else    
        mode = 'idle'
    end
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F2, F2Pressed)
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

-------------------------------------------------------------------------------
-- Callback to handle changes in instrument settings
local function settingsChanged(status, active)
end
dwi.setEStatusCallback(dwi.ESTAT_INIT, settingsChanged)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 0.100    -- time in millisec until timer events start triggering
local tickerRepeat = 0.200  -- time in millisec that the timer repeats
local function ticker()
-- insert code here that you want to run on each timer event
    dwi.rotWAIT(1)
end
rinApp.system.timers.addTimer(tickerRepeat,tickerStart,ticker)
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation 
--=============================================================================
--  This is a good place to put your initialisation code 
-- (eg, setup outputs or put a message on the LCD etc)

-------------------------------------------------------------------------------

--=============================================================================
-- Main Application Loop
--=============================================================================
-- Define your application loop
-- mainLoop() gets called by the framework after any event has been processed
-- Main Application logic goes here
local function mainLoop()
   if mode == 'idle' then
      dwi.writeTopLeft('MY APP')
      dwi.writeBotLeft('F1-START F2-FINISH',1.5)
      dwi.writeBotRight('')
   elseif mode == 'run' then
      dwi.writeTopLeft()
      dwi.writeBotLeft('')
      dwi.writeBotRight('PLACE')
      if dwi.allStatusSet(dwi.STAT_NOTZERO, dwi.STAT_NOTMOTION) then
         dwi.writeReg('usernum3', dwi.toPrimary(curWeight))
         dwi.setAutoBotLeft('usernum3')         
         dwi.writeBotRight('CAPTURED')
         dwi.buzz(2)
         dwi.delay(1)
         dwi.writeBotRight('...')
         mode = 'wait'
      end
    elseif mode == 'wait' then      
       if dwi.anyStatusSet(dwi.STAT_MOTION) then
           dwi.writeBotRight('')
           dwi.buzz(1)
           dwi.delay(0.5)
           mode = 'run'
       end
    end       
end

--=============================================================================
-- Clean Up 
--=============================================================================
-- Define anything for the Application to do when it exits
-- cleanup() gets called by framework when the application finishes
local function cleanup()
     
end

--=============================================================================
-- run the application 
rinApp.setMainLoop(mainLoop)
rinApp.setCleanup(cleanup)
rinApp.run()                       
--=============================================================================
