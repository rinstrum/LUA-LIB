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
local device = rinApp.addC500()         --  make a connection to the instrument

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
device.addStream('grossnet', handleNewWeight, 'change')
-- choose a different register if you want to track other than GROSSNET weight
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to monitor motion status
local function handleMotion(status, active)
-- status is a copy of the instrument status bits and active is true or false
-- to show if active or not
    if active then
        print('motion')
    else
        print('stable')
    end
end
device.setStatusCallback('motion', handleMotion)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleIO1(IO, active)
-- status is a copy of the instrument status bits and active is true or false 
-- to show if active or not
    if active then
        print('IO 1 is on ')
    else
        print('IO 1 is off ')
    end
end
device.setIOCallback(1, handleIO1)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

local function handleIO(data)
    dbg.info(' IO: ', string.format('%08X',data))
end
device.setAllIOCallback(handleIO)

--=============================================================================
-- Define the state machine that drives this appliction.

local function enterIdle()
    device.write('topLeft', 'F1-SRT F2-FIN', 'time=1.5')
end

local function doRun()
    -- Update the weight on the screen. Only update screen at 10Hz so as not to
    -- overwork the device.
    device.write('topLeft', curWeight, 'align=right')
    rinApp.delay(0.1)
end

local function captured()
    device.buzz(2)
    device.write('topLeft', 'CAPTRD', 'time=1, wait')
end

local function rerun()
    device.buzz(1)
end

-- The actual state machine is pretty small:
local fsm = device.stateMachine { 'myAppFSM', showState=true }
    -- States are the modes we can be in.
    .state { 'idle', enter=enterIdle    }
    .state { 'run',  run=doRun     }
    .state { 'wait'                     }

    -- Transitions are the movements between modes.
    .trans { 'run', 'wait', status={'notzero', 'notmotion'}, activate=captured }
    .trans { 'wait', 'run', status='motion',                 activate=rerun    }
    .trans { 'idle', 'run', event='run'                                        }
    .trans { 'all', 'idle', event='reset'                                      }

-------------------------------------------------------------------------------
-- Callbacks to handle F1 key event
device.setKeyCallback('f1', function() print('Long F1 Pressed') return true end, 'long')
device.setKeyCallback('f1', function() fsm.raise('run') return true end, 'short')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callbacks to handle F2 key event
device.setKeyCallback('f2', function() print('Long F2 Pressed') return true end, 'long')
device.setKeyCallback('f2', function() fsm.raise('reset') return true end, 'short')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle changes in instrument settings
local function settingsChanged(status, active)
end
device.setStatusCallback('init', settingsChanged)
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
