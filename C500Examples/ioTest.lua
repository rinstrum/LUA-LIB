-------------------------------------------------------------------------------
-- IOTest
-- Drive IO1 to IO8 then process IO inputs from an IO tester
--
-- @author Luke Allison
-- @copyright 2016 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

--=============================================================================
-- Requires
--=============================================================================
local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers'
local dbg = require 'rinLibrary.rinDebug'

--=============================================================================
-- Global variables 
--=============================================================================

--=============================================================================
-- Connection and configuration
--=============================================================================
local device = rinApp.addC500()         --  make a connection to the instrument
-- device.loadRIS("setpIO.RIS")     

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================
local IO1 = 1
local IO2 = 2
local IO3 = 3
local IO4 = 4
local IO5 = 5
local IO6 = 6
local IO7 = 7
local IO8 = 8

--=============================================================================
-- Supporting functions
--============================================================================= 

--=============================================================================
-- Main application
--============================================================================= 
function autoTests()
  autoTest1()
end

function autoTest1()
  print('autoTest')
  for i = 0, 8, 1 do
      print('i='tester..i)
      device.turnOn(i)
      rinApp.delay(1)
  end
  for i = 0, 8, 1 do
      print('i='..i)
      device.turnOff(i)
      rinApp.delay(1)
  end
end

--=============================================================================
-- Callbacks
--============================================================================= 
local function f1Pressed(key, state)
  if fsm.getState() == 'idle' then 
    print('f1Pressed')
    fsm.raise('f1Pressed')
    return true
  end
  return false
end 
device.setKeyCallback('f1', f1Pressed, 'short')

local function f2Pressed(key, state)
  if fsm.getState() == 'idle' then 
    print('f2Pressed')
    fsm.raise('f2Pressed')
    return true
  end
  return false
end 
device.setKeyCallback('f2', f2Pressed, 'short')

--=============================================================================
-- Initialisation
--=============================================================================
device.enableOutput(IO1,
                  IO1,
                  IO2,
                  IO3,
                  IO4,
                  IO5,
                  IO6,
                  IO7,
                  IO8)
                  
--=============================================================================
-- State Machine
--=============================================================================
fsm = device.stateMachine { 'FSM' }
  .state{'idle', enter = function () device.write('topLeft', 'IDLE') end}
  .state{'autoTest', enter = autoTests}
  .state{'manualTest', enter = manualTests}
 
  .trans{ 'idle', 'autoTest', event='f1Pressed' }
  .trans{ 'idle', 'manualTest', event='f2Pressed' }

  .trans{ 'all', 'idle', event='f3Pressed' }

--=============================================================================
-- run the application
--============================================================================
rinApp.setMainLoop(fsm.run)
rinApp.run()

