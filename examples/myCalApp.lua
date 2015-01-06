#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- myCalApp
--
-- Application template
--
-- Copy this file to your project directory and insert the specific code of
-- your application
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers'
local dbg = require 'rinLibrary.rinDebug'

--=============================================================================
-- Connect to the instruments you want to control
-- Define any Application variables you wish to use
--=============================================================================
local device = rinApp.addK400()        --  make a connection to the instrument
device.loadRIS("myCalApp.RIS")         -- load default instrument settings

local mode = 'idle'

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

-------------------------------------------------------------------------------
-- Callback to handle F1 key event
local function F1Pressed(key, state)
    mode = 'menu'
    return true  -- key handled here, don't send back to instrument for handling
end
device.setKeyCallback('f1', F1Pressed)
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Callback to handle F2 key event
device.enableOutput(3)
local function F2Pressed(key, state)
    device.turnOnTimed(3,5.0)
    return true  -- key handled here, don't send back to instrument for handling
end
device.setKeyCallback('f2', F2Pressed)
-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
device.setKeyCallback('pwr_cancel', rinApp.finish, 'long')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle changes in instrument settings
local function settingsChanged(status, active)
end
device.setStatusCallback('init', settingsChanged)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 0.10  -- time in seconds until timer events start triggering
local tickerRepeat = 0.20 -- time in seconds that the timer repeats
timers.addTimer(tickerRepeat, tickerStart, device.rotWAIT, 1)
-------------------------------------------------------------------------------



--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)
-------------------------------------------------------------------------------
device.setIdleCallback(device.abortDialog, 30)

local function prompt(msg)
    device.write('bottomLeft', msg or '', 'time=1.5, wait')
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
      device.write('topLeft', 'CAL.APP')
      device.write('bottomLeft', 'F1-MENU')
      device.write('bottomRight', '')
   elseif mode == 'menu' then
      device.write('topLeft')
      device.write('bottomLeft', '')
      sel = device.selectOption('MENU',{'ZERO','SPAN','MVV ZERO','MVV SPAN','SET LIN', 'CLR LIN','PASSCODE','EXIT'},sel,true)
      if not sel or sel == 'EXIT' then
         mode = 'idle'
         device.lockPasscode('full')
      elseif sel == 'PASSCODE' then
          local pc = device.selectOption('ENTER PASSCODE',{'full','safe','oper'},'full',true)
          if pc then
               device.changePasscode(pc)
          end
      elseif device.checkPasscode('full', nil, 5) then
          if sel == 'ZERO' then
              msg, err = device.calibrateZero()
              if err == nil then
                  dbg.info('Zero MVV: ',device.readZeroMVV())
              end
              prompt(msg)

          elseif sel == 'SPAN' then
              msg, err = device.calibrateSpan(device.editReg('calibwgt'))
              if err == nil then
                  dbg.info('Span Calibration Weight: ',device.readSpanWeight())
                  dbg.info('Span MVV: ',device.readSpanMVV())
              end
              prompt(msg)

          elseif sel == 'MVV SPAN' then
              MVV = device.edit('MVV SPAN','2.0','number')
              msg, err = device.calibrateSpanMVV(MVV)
              prompt(msg)

          elseif sel == 'MVV ZERO' then
              MVV = device.edit('MVV ZERO','0','number')
              msg, err = device.calibrateZeroMVV(MVV)
              prompt(msg)

          elseif sel == 'SET LIN' then
              pt = device.selectOption('LIN PT',{'1','2','3','4','5','6','7','8','9','10'},'1',true)
              if (pt) then
                  msg, err = device.calibrateLin(pt, device.editReg('calibwgt'))
                  if not err then
                      dbg.info('Linearisation Calibration: ', device.readLinCal())
                  end
                  prompt(msg)
              end
          elseif sel == 'CLR LIN' then
              pt = device.selectOption('LIN PT',{'1','2','3','4','5','6','7','8','9','10'},'1',true)
              if (pt) then
                 msg, err = device.clearLin(pt)
                 if not err then
                      dbg.info('Linearisation Calibration: ', device.readLinCal())
                 end
                 prompt(msg)
              end
          end
        end
    end
end

--=============================================================================
-- run the application
rinApp.setMainLoop(mainLoop)
rinApp.run()
--=============================================================================
