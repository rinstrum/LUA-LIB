-------------------------------------------------------------------------------
-- multi-device
-- 
-- Demonstrates how the libraries can control multiple devices
-- 
-- Displays 'hello' to two instruments and closes when a button is pressed on
-- a certain instrument.
-------------------------------------------------------------------------------
local rinApp = require "rinApp"

local device_a = rinApp.addL401("172.17.1.95", 2222)
local device_b = rinApp.addL401("172.17.1.139", 2222)

device_a.writeBotLeft("Hello")
device_a.writeBotRight("A")

device_b.writeBotLeft("Hello")
device_b.writeBotRight("B")

-- wait for keypress from device_a
device_a.getKey()       				

-- Clean up the devices
rinApp.cleanup()

os.exit()