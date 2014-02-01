-------------------------------------------------------------------------------
-- Carbon Copy Printer
-- @author Darren Pearson
-- @copyright 2014 Rinstrum Pty Ltd
-- Takes printout information from SER3B and sends to ser1A keeping a copy
-- Prints the copy out ser1A when F3 pressed
-------------------------------------------------------------------------------

-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"

-- Add control of an L401 at the given IP and port
local dwi = rinApp.addK400("K401")

-- Write "Hello world" to the LCD screen.
dwi.writeBotLeft("PRINT")
dwi.writeBotRight("COPY")

printCopy = {}  -- table to hold print lines of text

function printHandler(s)
   dwi.dbg.print('SER3B:',s)
   dwi.printCustomTransmit(dwi.expandCustomTransmit(s),dwi.PRINT_SER1A)
   table.insert(printCopy,s)
 end
dwi.setDelimiters(nil,'\13','\10')
dwi.setSerBCallback(printHandler)


-------------------------------------------------------------------------------
-- Key Handler for F3 
-------------------------------------------------------------------------------
local function F3Pressed(key, state)
   
   if #printCopy > 0 then
       for k,v in ipairs(printCopy) do
         dwi.printCustomTransmit(dwi.expandCustomTransmit(v),dwi.PRINT_SER1A)
       end
       dwi.printCustomTransmit([[<<Copy>>\C1]],dwi.PRINT_SER1A)
       printCopy = {}
    end
   return true
end
dwi.setKeyCallback(dwi.KEY_F3, F3Pressed)


while rinApp.running do
   rinApp.system.handleEvents()
end

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()