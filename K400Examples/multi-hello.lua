#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- multi-device
--
-- Demonstrates how the libraries can control multiple devices
--
-- Displays 'hello' to two instruments and closes when a button is pressed on
-- a certain instrument.
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local deviceA = rinApp.addK400()     --  make a connection to the instrument
local deviceB = rinApp.addK400(nil, "10.0.0.2", 2222)

--=============================================================================
-- Main Application
--=============================================================================

-- Write "Hello world" to the LCD screen.
deviceA.write('bottomLeft', "Hello")
deviceA.write('bottomRight', "A")

deviceB.write('bottomLeft', "Hello")
deviceB.write('bottomRight', "B")

deviceA.getKey()  -- Wait for the user to press a key on the device

--=============================================================================
-- Clean Up
--=============================================================================
rinApp.cleanup()

