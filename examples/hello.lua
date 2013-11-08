-------------------------------------------------------------------------------
-- Hello
-- 
-- Traditional Hello World example
-- 
-- Configures a rinApp application, displays 'Hello World' on screen and waits
-- for a key press before exit
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"

-- Add control of an L401 at the given IP and port
local L401 = rinApp.addL401("127.0.0.1", 2222)

-- Write "Hello world" to the LCD screen.
L401.writeBotLeft("Hello")
L401.writeBotRight("World")

-- Wait for the user to press a key on the L401
L401.getKey()

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()