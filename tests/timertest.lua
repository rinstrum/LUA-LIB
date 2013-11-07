-------------------------------------------------------------------------------
-- m4223hardware
-- 
-- m4223 hardware support
-- 
-- Configures a rinApp application
-- Enables the USB power supply
-- Monitors for USB over-current faults
-- Drives the status LED
-- 
-- LED OFF: rinApp not running
-- LED ON: USB over-current error
-- LED FLASHING: Normal operation 
-------------------------------------------------------------------------------

-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"

-- Add control of an L401 at the given IP and port
local L401 = rinApp.addL401("127.0.0.1", 2222)

-- Write to the LCD screen.
L401.writeBotLeft("hardware")
L401.writeBotRight("test")

-- Main application loop
while rinApp.running do
	
	print "---------------------------"
	require 'pl.pretty'.dump(rinApp.system.timers.timers)
	print "---------------------------"
	
	L401.rotWAIT(1)
	L401.delay(500)
end  

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()