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

-- Make gpio available
local f = assert(io.open("/sys/class/gpio/export", "w"))
f:setvbuf("no")
f:write("36\n", "86\n", "87\n")
f:close()

-- Local function to write gpio files
local function writeGpioFile (file, value)
	local f = assert(io.open(file, "w"))
	f:write(value)
	f:close()
end

-- Set gpio directions
writeGpioFile("/sys/class/gpio/gpio36/direction", "out") -- USB Enable
writeGpioFile("/sys/class/gpio/gpio86/direction", "out") -- Status LED
writeGpioFile("/sys/class/gpio/gpio87/direction", "in")  -- USB Fault

-- Enable USB power supply
writeGpioFile("/sys/class/gpio/gpio36/value", "1")

-- Open value files
local fLed = assert(io.open("/sys/class/gpio/gpio86/value", "w"))
fLed:setvbuf("no")
local fFault = assert(io.open("/sys/class/gpio/gpio87/value", "r"))

local LED = false

-- Main application loop
while rinApp.running do

	local fault

	-- monitor USB fault
	fFault:seek("set", 0)
	fault = fFault:read("*l") 
	if fault == "0" then -- if there is an over-current condition
		LED = true		 -- turn on LED
	else 			     -- else toggle LED
		LED = not LED 
	end
	
	-- drive status LED
	if LED == true then
		fLed:write("0") -- LED on
	else
		fLed:write("1") -- LED off
	end
	
	print "---------------------------"
	require 'pl.pretty'.dump(rinApp.system.timers.timers)
	print "---------------------------"
	
	L401.rotWAIT(1)
	L401.delay(500)
end  
                          
-- Close files
fLed:close()
fFault:close()

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()