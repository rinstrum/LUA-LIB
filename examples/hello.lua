#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- Hello
--
-- Traditional Hello World example
--
-- Configures a rinApp application, displays 'Hello World' on screen and waits
-- for a key press before exit
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local device = rinApp.addK400()        --  make a connection to the instrument

--=============================================================================
-- Main Application
--=============================================================================

-- Write "Hello world" to the LCD screen.
device.write('bottomLeft', "Hello")
device.write('bottomRight', "World")

device.getKey()  -- Wait for the user to press a key on the device

--=============================================================================
-- Clean Up
--=============================================================================
rinApp.cleanup()
