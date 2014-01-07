-------------------------------------------------------------------------------
-- multi-device
-- 
-- Demonstrates how the libraries can control multiple devices
-- 
-- Displays 'hello' to two instruments and closes when a button is pressed on
-- a certain instrument.
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local rinApp = require "rinApp"

local device_a = rinApp.addK400()
local device_b = rinApp.addK400("K401", "192.168.1.3", 2222)

device_a.writeBotLeft("Hello")
device_a.writeBotRight("A")

device_b.writeBotLeft("Hello")
device_b.writeBotRight("B")

-- wait for keypress from device_a
device_a.getKey()       				

-- Clean up the devices
rinApp.cleanup()

os.exit()