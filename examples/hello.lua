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

-- Add control of an K401 at the given IP and port
local K401 = rinApp.addK400("K401")

-- Write "Hello world" to the LCD screen.
K401.writeBotLeft("Hello")
K401.writeBotRight("World")

-- Wait for the user to press a key on the K401
K401.getKey()

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()