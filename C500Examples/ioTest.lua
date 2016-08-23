-------------------------------------------------------------------------------
-- IOTest
-- Drive IO1 to IO8 using functions from the setpoint library
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
local IO1 = 1
local IO2 = 2
local IO3 = 3
local IO4 = 4
local IO5 = 5
local IO6 = 6
local IO7 = 7
local IO8 = 8
local ready = false

--=============================================================================
-- Connection and configuration
--=============================================================================
local device = rinApp.addC500()     --  make a connection to the instrument

--=============================================================================
-- Supporting functions
--============================================================================= 
function ready()
  return ready
end

function refreshIO()
  -- give lua control of all IO ports
  device.enableOutput(IO1, IO2, IO3, IO4, IO5, IO6, IO7, IO8)

  -- give lua control over the lcd
  device.lcdControl('lua')

  -- set type to 'off', flight to 0, and hysteresis to 0 for all IO ports
  for i = 1, 8, 1 do
    device.setpType(i, 'off')
    device.setpFlight(i, 0)
    device.setpHys(i, 0)      
  end
  
  -- set preset tare to 0
  device.presetTare(0)
  
  -- set the setpoint to trigger on gross weight 
  device.setpSource(1, 'gross')
  
  device.saveSettings()
end

--=============================================================================
-- Main application
--============================================================================= 
-- automatic tests, requiring no operator input 
function autoTest1()
  device.write('topLeft', 'TEST 1') 
  
  -- turn on each IO sequentially 
  for i = 1, 8, 1 do
      device.turnOn(i)
      rinApp.delay(.5)
  end
  -- turn off each IO sequentially 
  for i = 1, 8, 1 do
      device.turnOff(i)
      rinApp.delay(.5)
  end
end

function autoTest2()
  device.write('topLeft', 'TEST 2') 
  
  -- turn on all IO ports for 2 seconds
  device.turnOnTimed(IO1, 2)
  device.turnOnTimed(IO2, 2)
  device.turnOnTimed(IO3, 2)    
  device.turnOnTimed(IO4, 2)
  device.turnOnTimed(IO5, 2)
  device.turnOnTimed(IO6, 2)
  device.turnOnTimed(IO7, 2)    
  device.turnOnTimed(IO8, 2)
  
  rinApp.delay(2)
end

function autoTest()
  autoTest1()
  autoTest2()
  timers.addEvent(fsm.raise, 'restart')
end

-- manual tests, requiring a weight input
function manualTest1()
  -- flag that this function has just begun 
  ready = false
  
  device.write('topLeft', 'TEST 1') 

  -- trigger setpoints when 'over' the target, set logic high when active
  for i = 1, 8, 1 do
    device.setpType(i, 'over')
    device.setpLogic(i, 'high')
  end

  -- set alarm for setpoint 1
  device.setpAlarm(1, 'double')

  -- set target for each set point
  device.setpTarget(IO1, 100)
  device.setpTarget(IO2, 200)
  device.setpTarget(IO3, 300)
  device.setpTarget(IO4, 400)
  device.setpTarget(IO5, 500)
  device.setpTarget(IO6, 600)
  device.setpTarget(IO7, 700)
  device.setpTarget(IO8, 800) 
  
  device.saveSettings()
  rinApp.delay(1)

  -- release IO control from lua to indicator 
  device.releaseOutput(IO1, IO2, IO3, IO4, IO5, IO6, IO7, IO8)

  -- release LCD control from lua to indicator
  device.lcdControl('default')
  
  print('Test 1: wind up weight from 0kg to 800kg and back to turn on IO1 to IO8')
  
  -- flag that this function has completed
  ready = true
end

function manualTest2()
  -- flag that this function has just begun 
  ready = false
  
  -- give lua control over the lcd screen
  device.lcdControl('lua')
  device.write('topLeft', 'TEST 2') 

  -- turn off setpoints 2 to 8
  for i = 2, 8, 1 do
    device.setpType(i, 'off')
  end

  -- set target for the set point
  device.setpTarget(IO1, 1000)

  -- set the hysteresis value for setpoint 1
  device.setpHys(1, 500)
 
  device.saveSettings() 

  rinApp.delay(1)

  -- give lua control of IO ports 2 to 8 
  device.enableOutput(IO2, IO3, IO4, IO5, IO6, IO7, IO8)

  -- release LCD control from lua to indicator  
  device.lcdControl('default')

  print('Test 2: wind up weight from 0kg to 1000kg to set IO1 high and wind weight down to 500kg set IO1 low')
  
  -- flag that this function has completed
  ready = true
end

function manualTest3()
  -- give lua control over the lcd screen
  device.lcdControl('lua')
  device.write('topLeft', 'TEST 3') 
  
  -- set the hysteresis value for setpoint 1 to 0
  device.setpHys(1, 0)
  
  -- set a preset tare so gross and net weights are different 
  device.presetTare(500)
  
  -- set the setpoint to trigger on net weight
  device.setpSource(1, 'net')

  rinApp.delay(1)
  
  device.saveSettings()   
  
  -- release LCD control from lua to indicator
  device.lcdControl('default')
  
  print('Test 3: wind up weight to 1500kg to turn on IO1, which is triggered by the net weight')
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
  if fsm.getState() == 'idle' or fsm.getState() == 'manualTest1' or fsm.getState() == 'manualTest2' then 
    print('f2Pressed')
    fsm.raise('f2Pressed')
    return true
  end
  return false
end 
device.setKeyCallback('f2', f2Pressed, 'short')

local function f3Pressed(key, state)
  if fsm.getState() == 'manualTest1' or fsm.getState() == 'manualTest2' or fsm.getState() == 'manualTest3' then 
    print('f3Pressed')
    fsm.raise('restart')
    return true
  end
  return false
end 
device.setKeyCallback('f3', f3Pressed, 'short')

-- Callback to capture changes to instrument status
local function handleIO(IO, active)
    print(IO,active)
end
device.setIOCallback(IO1, handleIO)
device.setIOCallback(IO2, handleIO)
device.setIOCallback(IO3, handleIO)
device.setIOCallback(IO4, handleIO)
device.setIOCallback(IO5, handleIO)
device.setIOCallback(IO6, handleIO)
device.setIOCallback(IO7, handleIO)
device.setIOCallback(IO8, handleIO)

--=============================================================================
-- Initialisation
--=============================================================================
print('Set point count = ' .. device.setPointCount())                  

--=============================================================================
-- State Machine
--=============================================================================
fsm = device.stateMachine { 'FSM' }
  .state{'idle', enter = function () device.write('topLeft', 'IDLE') refreshIO() end }
  .state{'autoTest', enter = autoTest}
  .state{'manualTest1', enter = manualTest1}
  .state{'manualTest2', enter = manualTest2}
  .state{'manualTest3', enter = manualTest3}  
 
  .trans{ 'idle', 'autoTest', event='f1Pressed' }
  .trans{ 'idle', 'manualTest1', event='f2Pressed' }
  .trans{ 'manualTest1', 'manualTest2', event='f2Pressed', cond='ready' }
  .trans{ 'manualTest2', 'manualTest3', event='f2Pressed', cond='ready' }  

  .trans{ 'all', 'idle', event='restart' }

--=============================================================================
-- run the application
--============================================================================
rinApp.setMainLoop(fsm.run)
rinApp.run()

