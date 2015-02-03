#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- Example for using the D320 with the R400 serial.
--
-- The D320 should be connected to the USB port of the M4223 using a USB to 
-- RS232 cable.
-- 
-------------------------------------------------------------------------------

--=============================================================================
-- Some of the more commonly used modules as globals
local rinApp = require 'rinApp'               -- load in the application framework
local timers = require 'rinSystem.rinTimers'  -- load in some system timers
local dbg    = require 'rinLibrary.rinDebug'  -- load in a debugger

--=============================================================================
-- Connect to the instrument you want to control
local device = rinApp.addK400()                  -- local K401 instrumentH

-- Load the remote display. An extra ip addess option is supplied here to 
-- connect using ethernet.
device.addDisplay("D840", "d840", "172.17.1.180")

-- Loop function
local function looper()
  
  -- Write a long string and some units.
  device.write("D840", "123456789 hello")
  device.writeUnits("D840", 't')
  
  -- Write the same text and some units to the top left
  device.write("topLeft", "123456789 hello")
  device.writeUnits("topLeft", 't', 'per_h')
  
  -- Write the same text and some units to the bottom left
  device.write("bottomLeft", "123456789 hello")
  device.writeUnits("bottomLeft", 't', 'per_h')
  
  -- Turn on some annunciators.
  device.setAnnunciators('topLeft', 'battery')
  device.setAnnunciators('bottomLeft', 'clock')
  
  -- Wait for 3 seconds
  rinApp.delay(3)
  
  -- Turn on some annunciators on the remote display.
  -- The red and green lights can be turned on simultaneously.
  device.setAnnunciators("D840", 'net', 'zero', 'redLight', 'greenLight')
  
  -- Wait for 3 seconds
  rinApp.delay(3)
  
  -- Turn off some annunciators on the remote display.
  device.clearAnnunciators('D840', 'net', 'zero', 'redLight', 'greenLight')
  
  -- Flash the green light.
  device.setAnnunciators("D840", 'greenLight')
  rinApp.delay(2)
  device.clearAnnunciators("D840", 'greenLight')
  
  -- Flash the red light.
  device.setAnnunciators("D840", 'redLight')
  rinApp.delay(2)
  device.clearAnnunciators("D840", 'redLight')
  
  -- Flash the green and red light.
  device.setAnnunciators("D840", 'greenLight', 'redLight')
  rinApp.delay(2)
  device.clearAnnunciators("D840", 'greenLight', 'redLight')
  
  -- Clear the remote display
  device.write("D840", "")
  device.writeUnits("D840", 'none')
  
  -- Wait for 3 seconds
  rinApp.delay(3)
  
end

rinApp.setMainLoop(looper)

rinApp.run()
