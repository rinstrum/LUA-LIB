#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- myApp
--
-- Application template
--
-- Copy this file to your project directory and insert the specific code of
-- your application
-------------------------------------------------------------------------------
local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers'
local dbg = require "rinLibrary.rinDebug"

--=============================================================================
-- Connect to the instruments you want to control
-- Define any Application variables you wish to use
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument
dwi.loadRIS("myApp.RIS")               -- load default instrument settings

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
        print('motion')
    else
        print('stable')
    end
end
dwi.setStatusCallback('motion', handleMotion)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleIO1(IO, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
    if active then
        print('IO 1 is on ')
    else
        print('IO 1 is off ')
    end
end
dwi.setIOCallback(1, handleIO1)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

local function handleIO(data)
    dbg.info(' IO: ', string.format('%08X',data))
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
    dbg.info('SETP: ',string.format('%04X',data))
end
dwi.setAllSETPCallback(handleSETP)
-- set callback to capture changes on IO1

--=============================================================================
-- Define the state machine that drives this appliction.

local function enterIdle()
    dwi.write('topLeft', 'MY APP')
    dwi.write('bottomLeft', 'F1-START F2-FINISH', 'time=1.5')
    dwi.write('bottomRight', '')        
end

local function enterRun()
    dwi.writeAuto('topLeft', 'grossnet')
    dwi.write('bottomLeft', '')
    dwi.write('bottomRight', 'PLACE')
end

local function captured()
    dwi.setUserNumber(3, dwi.toPrimary(curWeight))
    dwi.writeAuto('bottomLeft', 'usernum3')
    dwi.buzz(2)
    dwi.write('bottomRight', 'CAPTURED', 'time=1, wait')
    dwi.write('bottomRight', '...')
end

-- The actual state machine is pretty small at six lines:
local fsm = dwi.stateMachine { 'myAppFSM', showState=true }
    -- States are the modes we can be in.
    .state { 'idle', enter=enterIdle }
    .state { 'run',  enter=enterRun }
    .state { 'wait' }

    -- Transitions are the movements between modes.
    .trans { 'run', 'wait', status={'notzero', 'notmotion'}, activate=captured }
    .trans { 'wait', 'run', status='motion',
        activate = function()
            dwi.buzz(1)
            dwi.write('bottomRight', '', 'time=0.5, wait')
        end }

-------------------------------------------------------------------------------
-- Callbacks to handle F1 key event
dwi.setKeyCallback('f1', function() print('Long F1 Pressed') return true end, 'long')
dwi.setKeyCallback('f1', function() fsm.setState('run') return true end, 'short')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callbacks to handle F2 key event
dwi.setKeyCallback('f2', function() print('Long F2 Pressed') return true end, 'long')
dwi.setKeyCallback('f2', function() fsm.reset() return true end, 'short')
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

timers.addTimer(tickerRepeat, tickerStart, dwi.rotWAIT, 1)
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

-------------------------------------------------------------------------------

--=============================================================================
-- run the application
rinApp.setMainLoop(fsm.run)
rinApp.run()
--=============================================================================
