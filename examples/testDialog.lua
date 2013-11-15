-------------------------------------------------------------------------------
-- testDialog
-- 
-- Example of how to use various library dialog functions
-------------------------------------------------------------------------------

-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local rinApp = require "rinApp"
local K401 = rinApp.addK400("K401")
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- Put a message on LCD and remove after 2 second delay
K401.writeBotLeft("DIALOG")
K401.writeBotRight("TEST")
K401.delay(2000)
K401.writeBotLeft("")
K401.writeBotRight("")

-------------------------------------------------------------------------------
-- Prompt user to enter the number of times to sound buzzer, validate, 
-- and then buzz after 0.5 second delay  
local val = K401.edit('BUZZ',2)
if K401.askOK('OK?',val) == K401.KEY_OK then   -- confirm buzz amount
   K401.delay(500)
   K401.buzz(val)
end   

-------------------------------------------------------------------------------
-- Prompt user to select from a list of options. Options list will loop.
-- (e.g. if user presses 'up' key when option is large, loop back to small.
local sel = K401.selectOption('SELECT',{'SMALL','MEDIUM','LARGE'},'SMALL',true)
K401.delay(10)
-- show selected option (on device and console) and wait until key pressed
K401.writeBotLeft(sel)
K401.writeBotRight('SELECTED')
dbg.printVar('Selected value', sel, dbg.INFO)
K401.getKey()

-------------------------------------------------------------------------------

rinApp.cleanup()  -- shutdown application resources
os.exit()