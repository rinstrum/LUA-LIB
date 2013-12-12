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


-- Add control of an dwi at the given IP and port
local dwi = rinApp.addK400("K401")

-- Write "Hello world" to the LCD screen.
dwi.writeBotLeft("Hello")
dwi.writeBotRight("World!")

-- Wait for the user to press a key on the dwi
dwi.getKey()

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()