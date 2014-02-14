-------------------------------------------------------------------------------
-- multi-device
-- 
-- Demonstrates how the libraries can control multiple devices
-- 
-- Displays 'hello' to two instruments and closes when a button is pressed on
-- a certain instrument.
-------------------------------------------------------------------------------
-- Include the src directory
package.path = "/home/src/?.lua;" .. package.path 

-------------------------------------------------------------------------------
local rinApp = require "rinApp"     --  load in the application framework

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local dwiA = rinApp.addK400("K401")     --  make a connection to the instrument
local dwiB = rinApp.addK400("K401", "10.0.0.2", 2222)

--=============================================================================
-- Main Application 
--=============================================================================

-- Write "Hello world" to the LCD screen.
dwiA.writeBotLeft("Hello")
dwiA.writeBotRight("A")

dwiB.writeBotLeft("Hello")
dwiB.writeBotRight("B")

dwiA.getKey()  -- Wait for the user to press a key on the dwi

--=============================================================================
-- Clean Up 
--=============================================================================
rinApp.cleanup()

