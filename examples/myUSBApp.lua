#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- myApp
--
-- Application template
--
-- Copy this file to your project directory and insert the specific code of
-- your application
-------------------------------------------------------------------------------

local dbg = require 'rinLibrary.rinDebug'
local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers'
local usb = require "rinLibrary.rinUSB"

--=============================================================================
-- Connect to the instruments you want to control
-- Define any Application variables you wish to use
--=============================================================================
local device = rinApp.addK400()       --  make a connection to the instrument
device.loadRIS("myApp.RIS")           -- load default instrument settings

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
     print ('motion')
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
     print ('IO 1 is on ')
  else
     print ('IO 1 is off ')
  end
end
device.setIOCallback(1, handleIO1)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for USB registration
local function usbRegisterHandler(ev)
    for k,v in pairs(ev) do
        dbg.info(k,v[2])
    end
end
usb.setUSBRegisterCallback(usbRegisterHandler)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for general USB device events
local function usbEventHandler(ev)
    dbg.debug(ev)
end
usb.setUSBEventCallback(usbEventHandler)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for USB keyboard events
local acceptKeyboardInput = false
local function kbdHandler(key)
    dbg.info('Key is :', key)
end
usb.setUSBKBDCallback(kbdHandler)

local function kbdLineHandler(line)
    rinApp.addIdleEvent(print, line, ':', curWeight)
end
usb.setUSBKBDLineCallback(kbdLineHandler)

-------------------------------------------------------------------------------
-- toggle USB keyboard input between a simulated barcode reader and performing
-- display functions.
device.setKeyCallback('f2', function(key, state)
    acceptKeyboardInput = not acceptKeyboardInput
    device.usbProcessKeys(acceptKeyboardInput)
    usb.setUSBKBDLineCallback(not acceptKeyboardInput and kbdLineHandler or nil)

    local m = 'KEYBOARD ' .. (acceptKeyboardInput and 'CONTROL' or 'BAR CODE') .. ' MODE'
    device.write('bottomLeft', m, 'clear, time=1.5, restore')
end, 'short')

-------------------------------------------------------------------------------
-- Callback for USB serial events
local function usbSerialHandler(c, err, port)
    print("USB serial", c, err)
end
usb.serialUSBdeviceHandler(usbSerialHandler)

-------------------------------------------------------------------------------
-- Callback for USB storage events
local function usbStorageAppears(where)
    print(where..' has appeared')
end
usb.setStorageAddedCallback(usbStorageAppears)

local function usbStorageDisappears()
    print('USB storage has gone')
end
usb.setStorageRemovedCallback(usbStorageDisappears)

-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 0.10  -- time in seconds until timer events start triggering
local tickerRepeat = 0.20 -- time in seconds that the timer repeats

local function ticker()
-- insert code here that you want to run on each timer event
    device.rotWAIT(1)
end
timers.addTimer(tickerRepeat,tickerStart,ticker)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F1 key event
local function F1Pressed(key, state)
    print (device.edit(device,'NAME','FRED','string'))
    return true -- key handled here, don't send back to instrument for handling
end
device.setKeyCallback('f1', F1Pressed, 'short')

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
device.setKeyCallback('pwr_cancel', rinApp.finish, 'long')
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

device.write('bottomLeft', 'USB APP', 'align=right')
device.write('bottomRight', '.LUA')

--=============================================================================
-- run the application
rinApp.run()
--=============================================================================
