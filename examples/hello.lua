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
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument

--=============================================================================
-- Main Application
--=============================================================================

-- Write "Hello world" to the LCD screen.
dwi.writeBotLeft("Hello")
dwi.writeBotRight("World")

dwi.getKey()  -- Wait for the user to press a key on the dwi

--=============================================================================
-- Clean Up
--=============================================================================
rinApp.cleanup()
