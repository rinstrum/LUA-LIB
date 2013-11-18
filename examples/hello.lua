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

-- John changes

-- Require the rinApp module
local rinApp = require "rinApp"

-- Add control of an K401 at the given IP and port
local K401 = rinApp.addK400("K401")

-- Write "Hello world" to the LCD screen.
K401.writeBotLeft("Hello")
K401.writeBotRight("World")

-- Wait for the user to press a key on the K401

running = true

while running do
   k, s = K401.getKey()

   if (k == K401.KEY_5) then
       print ('Got cha')
       running = false
   elseif (k == K401.KEY_F1) then
      print(K401.readReg(K401.REG_SERIALNO))
   end    
   print(k,s)
end

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()