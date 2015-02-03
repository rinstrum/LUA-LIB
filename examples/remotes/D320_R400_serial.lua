#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- Example for using the D320 with the R400 serial.
--
-- The D320 should be connected to the comms port of the R400, and the R400
-- should be configured such that:
-- 
-- SER.AUT
--  NUM:  _1_
--  AUTO.1
--    TYPE:   5 Hz
--    SERIAL: SER1A    
--    FORMAT: CUSTOM
--    SOURCE: GROSS
-------------------------------------------------------------------------------

--=============================================================================
-- Some of the more commonly used modules as globals
local rinApp = require 'rinApp'               -- load in the application framework
local timers = require 'rinSystem.rinTimers'  -- load in some system timers
local dbg    = require 'rinLibrary.rinDebug'  -- load in a debugger

--=============================================================================
-- Connect to the instrument you want to control
local device = rinApp.addK400()                  -- local K401 instrumentH

-- Load the remote display. No extra options here indicates that the R400 comms 
-- port should be used.
device.addDisplay("D320", "d320")

-- Loop function
local function looper()
  
  -- Write a long string and some units.
  device.write("D320", "123456789 hello")
  device.writeUnits("D320", 't')
  
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
  device.setAnnunciators('D320', 'net', 'range1')
  
  -- Wait for 3 seconds
  rinApp.delay(3)
  
  -- Turn off some annunciators on the remote display.
  device.clearAnnunciators('D320', 'net', 'range1')
  
  -- Clear the remote display
  device.write("D320", "")
  device.writeUnits("D320", 'none')
  
  -- Wait for 3 seconds
  rinApp.delay(3)
  
end

rinApp.setMainLoop(looper)

rinApp.run()
