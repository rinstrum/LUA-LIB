-------------------------------------------------------------------------------
-- myCalApp
--
-- Application template
--
-- Copy this file to your project directory and insert the specific code of
-- your application
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers.Pack'
local dbg = require 'rinLibrary.rinDebug'

--=============================================================================
-- Connect to the instruments you want to control
-- Define any Application variables you wish to use
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument
dwi.loadRIS("myCalApp.RIS")               -- load default instrument settings

local mode = 'idle'

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

-------------------------------------------------------------------------------
-- Callback to handle F1 key event
local function F1Pressed(key, state)
    mode = 'menu'
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback('f1', F1Pressed)
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Callback to handle F2 key event
dwi.enableOutput(3)
local function F2Pressed(key, state)
    dwi.turnOnTimed(3,5.0)
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback('f2', F2Pressed)
-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
dwi.setKeyCallback('pwr_cancel', rinApp.finish, 'long')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle changes in instrument settings
local function settingsChanged(status, active)
end
dwi.setStatusCallback('init', settingsChanged)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 0.100    -- time in millisec until timer events start triggering
local tickerRepeat = 0.200  -- time in millisec that the timer repeats
local function ticker()
-- insert code here that you want to run on each timer event
    dwi.rotWAIT(1)
end
timers.addTimer(tickerRepeat, tickerStart, ticker)
-------------------------------------------------------------------------------



--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)
-------------------------------------------------------------------------------
dwi.setIdleCallback(dwi.abortDialog, 30)

local function prompt(msg)
    msg = msg or '        '
    dwi.write('bottomLeft', msg)
    rinApp.delay(1.5)
end

--=============================================================================
-- Main Application Loop
--=============================================================================
-- Define your application loop
-- mainLoop() gets called by the framework after any event has been processed
-- Main Application logic goes here

local sel = 'ZERO'
local function mainLoop()

   if mode == 'idle' then
      dwi.write('topLeft', 'CAL.APP')
      dwi.write('bottomLeft', 'F1-MENU',1.5)
      dwi.write('bottomRight', '')
   elseif mode == 'menu' then
      dwi.write('topLeft', )
      dwi.write('bottomLeft', '')
      sel = dwi.selectOption('MENU',{'ZERO','SPAN','MVV ZERO','MVV SPAN','SET LIN', 'CLR LIN','PASSCODE','EXIT'},sel,true)
      if not sel or sel == 'EXIT' then
         mode = 'idle'
         dwi.lockPasscode('full')
      elseif sel == 'PASSCODE' then
          local pc = dwi.selectOption('ENTER PASSCODE',{'full','safe','oper'},'full',true)
          if pc then
               dwi.changePasscode(pc)
          end
      elseif dwi.checkPasscode('full', nil, 5) then
          if sel == 'ZERO' then
              msg, err = dwi.calibrateZero()
              if err == nil then
                  dbg.info('Zero MVV: ',dwi.readZeroMVV())
              end
              prompt(msg)

          elseif sel == 'SPAN' then
              msg, err = dwi.calibrateSpan(dwi.editReg('calibwgt'))
              if err == nil then
                  dbg.info('Span Calibration Weight: ',dwi.readSpanWeight())
                  dbg.info('Span MVV: ',dwi.readSpanMVV())
              end
              prompt(msg)

          elseif sel == 'MVV SPAN' then
              MVV = dwi.edit('MVV SPAN','2.0','number')
              msg, err = dwi.calibrateSpanMVV(MVV)
              prompt(msg)

          elseif sel == 'MVV ZERO' then
              MVV = dwi.edit('MVV ZERO','0','number')
              msg, err = dwi.calibrateZeroMVV(MVV)
              prompt(msg)

          elseif sel == 'SET LIN' then
              pt = dwi.selectOption('LIN PT',{'1','2','3','4','5','6','7','8','9','10'},'1',true)
              if (pt) then
                  msg, err = dwi.calibrateLin(pt, dwi.editReg('calibwgt'))
                  if not err then
                      dbg.info('Linearisation Calibration: ', dwi.readLinCal())
                  end
                  prompt(msg)
              end
          elseif sel == 'CLR LIN' then
              pt = dwi.selectOption('LIN PT',{'1','2','3','4','5','6','7','8','9','10'},'1',true)
              if (pt) then
                 msg, err = dwi.clearLin(pt)
                 if not err then
                      dbg.info('Linearisation Calibration: ', dwi.readLinCal())
                 end
                 prompt(msg)
              end
          end
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
