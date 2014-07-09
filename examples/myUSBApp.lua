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
local dbg = require 'rinLibrary.rinDebug'
local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers.Pack'
local usb = require "rinLibrary.rinUSB"
local usbKBD = require "rinLibrary.rinUSBKBD"
usbKBD.link(rinApp)

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
barcodeKeys = {}
barcode = nil
local function kbdHandler(key)
    dbg.info('Key is :', key)
    if key == '\n' then
        barcode = table.concat(barcodeKeys)
    else
        table.insert(barcodeKeys,key)
    end
end
usb.setUSBKBDCallback(kbdHandler)

-------------------------------------------------------------------------------
-- Callback for USB serial events
local function usbSerialHandler(c, err, port)
    print("USB serial", c, err)
end
usb.serialUSBdeviceHandler(usbSerialHandler)

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 0.100    -- time in millisec until timer events start triggering
local tickerRepeat = 0.200  -- time in millisec that the timer repeats

local function ticker()
-- insert code here that you want to run on each timer event
    dwi.rotWAIT(1)
end
timers.addTimer(tickerRepeat,tickerStart,ticker)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle F1 key event
local function F1Pressed(key, state)
    print (usbKBD.edit(dwi,'NAME','FRED','string'))
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)
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

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

dwi.writeBotLeft('  USB APP')
dwi.writeBotRight(' .LUA')

--=============================================================================
-- Main Application Loop
--=============================================================================
-- Define your application loop
-- mainLoop() gets called by the framework after any event has been processed
-- Main Application logic goes here
local function mainLoop()

     if barcode then
         print (barcode, ': ',curWeight)
         barcode = nil
         barcodeKeys = {}
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
