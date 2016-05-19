#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- setpIO
--
-- Application template
--
-- Examples of how to use various IO services
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers'
local dbg = require 'rinLibrary.rinDebug'

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local device = rinApp.addK400()       --  make a connection to the instrument
device.loadRIS("setpIO.RIS")          -- load default instrument settings
-- IO 1,2,3,4 configured in K401 for various setpoint functions

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================
local SETP_OVER  = 1
local SETP_UNDER = 2
local SETP_FILL  = 3
local SETP_PULSE = 4

local OVER_OUTPUT = 5
local PASS_OUTPUT     = 6
local CHIME_OUTPUT    = 7
local RESET_OUTPUT    = 8

-------------------------------------------------------------------------------
--  Callback to capture changes to current weight
local curWeight = 0
local target = 5
local function handleNewWeight(data, err)
   curWeight = data
   print('Weight = ',curWeight)
end
device.addStream('grossnet', handleNewWeight, 'change')
-- choose a different register if you want to track other than GROSSNET weight
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleIO5(IO, active)
-- status is a copy of the instrument status bits and active is true or false 
-- to show if active or not
  if active then
     print ('IO 5 is on ')
  else
     print ('IO 5 is off ')
  end
end
device.setIOCallback(5, handleIO5)

-------------------------------------------------------------------------------
-- set callback to capture changes on IO1 as a key press
local function handleIO1(key, state)
    print('IO key', key, 'was pressed:', state)
end
device.setKeyCallback('io_1', handleIO1)

-------------------------------------------------------------------------------
-- Callback to monitor motion status
local function handleMotion(status, active)
-- status is a copy of the instrument status bits and active is true or false 
-- to show if active or not
  if active then
     print ('motion')
  else
     print('stable')
   end
end
device.setStatusCallback('motion', handleMotion)
-------------------------------------------------------------------------------

-- Setup Chimes

local chimeTimes = {}  -- off time, on time in tenths of second
local chimePos = 0        -- 0 for off, > 0 to keep track of chime position
local chimeCounter = 0    -- counts down the chime ticks

local chimerStart  = 0.10 -- time in seconds until timer events start triggering
local chimerRepeat = 0.10 -- time in second that the timer repeats

local function chimer()
    if chimeCounter > 0 then
       chimeCounter = chimeCounter - 1
       if chimeCounter == 0 then
          if chimePos < #chimeTimes then
              chimePos = chimePos +1
              chimeCounter = chimeTimes[chimePos]
          else
             chimePos = 0
          end
       end
       if (chimePos == 0) or (chimePos %2 ~= 0) then
           device.turnOff(CHIME_OUTPUT)
       else
           device.turnOn(CHIME_OUTPUT)
       end
    end
end
timers.addTimer(chimerRepeat,chimerStart,chimer)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to monitor real time clock status
local function handleRTC(status, active)
   local hour, min, sec = device.RTCreadTime()
   if min % 15 == 0 and sec == 0 then  -- every quarter hour
      chimeTimes = {}
      if min == 0 then
          for i = 1, 4 do                  -- add 4 fast chimes at the start
             table.insert(chimeTimes, 4)  -- off time
             table.insert(chimeTimes, 6)  -- on time
          end
          for i = 1, hour%12 do -- %12 to keep in 12 hour mode
             table.insert(chimeTimes,5)   -- add in long chime for each hour
             table.insert(chimeTimes,20)
          end
      else
          for i = 1, min/15 do  -- add fast chimes for each quarter hour
             table.insert(chimeTimes, 4)  -- off time
             table.insert(chimeTimes, 6)  -- on time
          end
      end
      chimePos = 1
      chimeCounter = chimeTimes[chimePos]
      dbg.info('Chimes : ',chimeTimes, chimePos, chimeCounter)
   end
   dbg.info('Clock : ',device.RTCtostring())
end
device.setStatusCallback('rtc', handleRTC)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleIO(IO, active)
    print(IO,active)
end
device.setIOCallback(1, handleIO)
device.setIOCallback(2, handleIO)
device.setIOCallback(CHIME_OUTPUT, handleIO)

-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 0.100    -- time in sec until timer events start triggering
local tickerRepeat = 0.200    -- time in sec that the timer repeats

timers.addTimer(tickerRepeat, tickerStart, device.rotWAIT, 'topLeft', 1)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F1 key event
local function F1Pressed(key, state)
    dbg.info('curIO: ',device.getCurIOStr())
    device.turnOnTimed(8,0.250)  -- reset setpoints 1 and 2
    device.setUserNumber(1, 1)  -- trigger pulses output on setpoint 4
    device.setUserNumber(1, 0)
    return true -- key handled here, don't send back to instrument for handling
end
device.setKeyCallback('f1', F1Pressed)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F2 key event
local function F2Pressed(key, state)
    target = device.edit('TARGET 5',target,'number')
    return true -- key handled here, don't send back to instrument for handling
end
device.setKeyCallback('f2', F2Pressed)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F3 key event
local function F3Pressed(key, state)
    device.editReg(device.setpRegAddress(3, 'setp_target'))
    device.releaseOutput(SETP_FILL)  -- let R420 drive the fill setpoint)
    return true -- key handled here, don't send back to instrument for handling
end
device.setKeyCallback('f3', F3Pressed)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
device.setKeyCallback('pwr_cancel', rinApp.finish, 'long')
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

device.write('bottomLeft', 'SETP IO', 'align=right')
device.write('bottomRight', '.LUA')
device.enableOutput(OVER_OUTPUT,
                 PASS_OUTPUT,
                 CHIME_OUTPUT,
                 RESET_OUTPUT)

device.enableOutput(SETP_FILL)     -- control SETP_FILL from Lua for now
device.turnOff(SETP_FILL)

device.sendKey('cancel','long')
--=============================================================================
-- Main Application Loop
--=============================================================================
-- mainLoop gets continually called by the framework
-- Main Application logic goes here

local function mainLoop()

-- turn on if over target and not motion or error
    if (curWeight > target) and
       device.allStatusSet('notmotion', 'noterror') then
         device.turnOn(OVER_OUTPUT)
     else
         device.turnOff(OVER_OUTPUT)
     end

-- turn on PASS_OUTPUT if the OVER and UNDER setpoints are off
     if not device.anyIOSet(SETP_OVER, SETP_UNDER) then
        device.turnOn(PASS_OUTPUT)
     else
        device.turnOff(PASS_OUTPUT)
     end

end
rinApp.setMainLoop(mainLoop)       -- register mainLoop with the framework
rinApp.setCleanup(function()
    device.releaseOutput(OVER_OUTPUT, PASS_OUTPUT, CHIME_OUTPUT, RESET_OUTPUT)
end)
rinApp.run()                       -- run the application framework
