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
dwi.writeBotRight("World")

-- Wait for the user to press a key on the dwi

running = true

while running do
   k, s = dwi.getKey()
   
   dwi.writeBotUnits(dwi.UNITS_KG, dwi.UNITS_OTHER_PER_H)
   if (k == dwi.KEY_5) then
       print ('Got cha')
       running = false
   elseif (k == dwi.KEY_F1) then
      print(dwi.readReg(dwi.REG_SERIALNO))
   end    
   print(k,s)
end

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()