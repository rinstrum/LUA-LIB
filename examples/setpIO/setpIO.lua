-------------------------------------------------------------------------------
-- setpIO
--
-- Application template
--
-- Examples of how to use various IO services
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local timers = requre 'rinSystem.rinTimers.Pack'

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument
dwi.loadRIS("setpIO.RIS")              -- load default instrument settings
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
dwi.addStream('grossnet', handleNewWeight, 'change')
-- choose a different register if you want to track other than GROSSNET weight
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleIO5(IO, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then
     print ('IO 5 is on ')
  else
     print ('IO 5 is off ')
  end
end
dwi.setIOCallback(5, handleIO5)
-- set callback to capture changes on IO1
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
dwi.setStatusCallback('motion', handleMotion)
-------------------------------------------------------------------------------

-- Setup Chimes

local chimeTimes = {}  -- off time, on time in tenths of second
local chimePos = 0           -- 0 for off, > 0 to keep track of chime position
local chimeCounter = 0       -- counts down the chime ticks

local chimerStart  = 0.100    -- time in seconds until timer events start triggering
local chimerRepeat = 0.100    -- time in second that the timer repeats

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
           dwi.turnOff(CHIME_OUTPUT)
       else
           dwi.turnOn(CHIME_OUTPUT)
       end
    end
end
timers.addTimer(chimerRepeat,chimerStart,chimer)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to monitor real time clock status
local function handleRTC(status, active)
   if (dwi.RTC.min % 15 == 0) and (dwi.RTC.sec == 0) then  -- every quarter hour
      chimeTimes = {}
      if dwi.RTC.min == 0 then
          for i = 1,4 do                  -- add 4 fast chimes at the start
             table.insert(chimeTimes, 4)  -- off time
             table.insert(chimeTimes, 6)  -- on time
          end
          for i = 1,dwi.RTC.hour%12 do    -- %12 to keep in 12 hour mode
             table.insert(chimeTimes,5)   -- add in long chime for each hour
             table.insert(chimeTimes,20)
          end
      else
          for i = 1,dwi.RTC.min/15 do     -- add fast chimes for each quarter hour
             table.insert(chimeTimes, 4)  -- off time
             table.insert(chimeTimes, 6)  -- on time
          end
      end
      chimePos = 1
      chimeCounter = chimeTimes[chimePos]
      dbg.info('Chimes : ',chimeTimes, chimePos, chimeCounter)
   end
   dbg.info('Clock : ',dwi.RTCtostring())
end
dwi.setEStatusCallback('rtc', handleRTC)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleIO(IO, active)
    print(IO,active)
end
dwi.setIOCallback(1, handleIO)
dwi.setIOCallback(2, handleIO)
dwi.setIOCallback(CHIME_OUTPUT, handleIO)

-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 0.100    -- time in sec until timer events start triggering
local tickerRepeat = 0.200    -- time in sec that the timer repeats

local function ticker()
-- insert code here that you want to run on each timer event
    dwi.rotWAIT(1)
end
timers.addTimer(tickerRepeat,tickerStart,ticker)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F1 key event
local function F1Pressed(key, state)
    dbg.info('curIO: ',dwi.getCurIOStr())
    dwi.turnOnTimed(8,0.250)  -- reset setpoints 1 and 2
    dwi.setUserNumber(1, 1)  -- trigger pulses output on setpoint 4
    dwi.setUserNumber(1, 0)
    dwi.RTC.sec = 58
    dwi.RTC.min = 59
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback('f1', F1Pressed)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F2 key event
local function F2Pressed(key, state)
    target = dwi.edit('TARGET 5',target,'number')
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback('f2', F2Pressed)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F3 key event
local function F3Pressed(key, state)
    dwi.editReg(dwi.setpRegAddress(3, 'setp_target'))
    dwi.releaseOutput(SETP_FILL)  -- let R420 drive the fill setpoint)
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback('f3', F3Pressed)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
dwi.setKeyCallback('pwr_cancel', function() rinApp.running = false return true end, 'long')
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

dwi.writeBotLeft('  SETP IO')
dwi.writeBotRight(' .LUA')
dwi.enableOutput(OVER_OUTPUT,
                 PASS_OUTPUT,
                 CHIME_OUTPUT,
                 RESET_OUTPUT)

dwi.enableOutput(SETP_FILL)     -- control SETP_FILL from Lua for now
dwi.turnOff(SETP_FILL)

dwi.sendKey('cancel','long')
--=============================================================================
-- Main Application Loop
--=============================================================================
-- mainLoop gets continually called by the framework
-- Main Application logic goes here

local function mainLoop()

-- turn on if over target and not motion or error
    if (curWeight > target) and
       dwi.allStatusSet('notmotion', 'noterror') then
         dwi.turnOn(OVER_OUTPUT)
     else
         dwi.turnOff(OVER_OUTPUT)
     end

-- turn on PASS_OUTPUT if the OVER and UNDER setpoints are off
     if not dwi.anyIOSet(SETP_OVER, SETP_UNDER) then
        dwi.turnOn(PASS_OUTPUT)
     else
        dwi.turnOff(PASS_OUTPUT)
     end

end
rinApp.setMainLoop(mainLoop)       -- register mainLoop with the framework
rinApp.init()
rinApp.run()                       -- run the application framework

--=============================================================================
-- Clean Up
--=============================================================================
-- Put any application clean up here
dwi.releaseOutput(OVER_OUTPUT,
                 PASS_OUTPUT,
                 CHIME_OUTPUT,
                 RESET_OUTPUT)

rinApp.cleanup()                   -- shutdown application resources
