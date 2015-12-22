#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- Example for using the terminal via ethernet. This is useful for debugging.
-- 
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
device.addDisplay("terminal", "terminal", "172.17.1.72")

-- Loop function
local function looper()
  
  -- Write a long string and some units.
  device.write("terminal", "123456789 hello")
  device.writeUnits("terminal", 't')

  -- Wait for 3 seconds
  rinApp.delay(3)
  
  -- Check the annunciators work on the terminal.
  device.setAnnunciators("terminal", 'net', 'coz', 'redLight', 'greenLight')
  
  -- Wait for 3 seconds
  rinApp.delay(3)
  
  -- Send an empty string to the terminal.
  device.write("terminal", "")
  device.writeUnits("terminal", 'none')
  
  -- Wait for 3 seconds
  rinApp.delay(3)
  
end

rinApp.setMainLoop(looper)

rinApp.run()
