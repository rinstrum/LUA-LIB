-------------------------------------------------------------------------------
-- Hello World Application
-- @author Darren Pearson
-- @author Merrick Heley
-- @author Sean Liddle
-- @copyright 2013 Rinstrum Pty Ltd
-- Traditional Hello World example
-- Configures a rinApp application, displays 'Hello World' on screen and waits
-- for a key press before exit
-------------------------------------------------------------------------------

-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"

-- Add control of an L401 at the given IP and port
local K401 = rinApp.addK400("K401")

--- Test Comment.
--@table wiring
--@field FILL = 4



-- Write "Hello world" to the LCD screen.
K401.writeBotLeft("Hello")
K401.writeBotRight("There")
K401.writeTopLeft("LEFT")
K401.writeTopRight("RIGHT")

-- Wait for the user to press a key on the L401
K401.getKey()

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()