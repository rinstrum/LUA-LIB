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
local dwi = rinApp.addK400("K401")

--- Test Comment.
--@table wiring
--@field FILL = 4



-- Write "Hello world" to the LCD screen.
dwi.writeBotLeft("Hello")
dwi.writeBotRight("There")


function printHandler(s)
   print ('This received from Print Engine: ',s)
end

dwi.setSerBCallback(printHandler)


-- Wait for the user to press a key on the L401
while rinApp.running do
   rinApp.system.handleEvents()
   end

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()