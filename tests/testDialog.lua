-------------------------------------------------------------------------------
-- testDialog
-- 
-- Example of how to use various library dialog functions
-------------------------------------------------------------------------------

local rinApp = require "rinApp"
local L401 = rinApp.addL401("172.17.1.95", 2222)
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- Put a message on LCD and remove after 2 second delay
L401.writeBotLeft("DIALOG")
L401.writeBotRight("TEST")
L401.delay(2000)
L401.writeBotLeft("")
L401.writeBotRight("")

-------------------------------------------------------------------------------
-- Prompt user to enter the number of times to sound buzzer, validate, 
-- and then buzz after 0.5 second delay  
local val = L401.edit('BUZZ',2)
if L401.askOK('OK?',val) == L401.KEY_OK then   -- confirm buzz amount
   L401.delay(500)
   L401.buzz(val)
end   

-------------------------------------------------------------------------------
-- Prompt user to select from a list of options. Options list will loop.
-- (e.g. if user presses 'up' key when option is large, loop back to small.
local sel = L401.selectOption('SELECT',{'SMALL','MEDIUM','LARGE'},'SMALL',true)
L401.delay(10)
-- show selected option (on device and console) and wait until key pressed
L401.writeBotLeft(sel)
L401.writeBotRight('SELECTED')
dbg.printVar('Selected value', sel, dbg.INFO)
L401.getKey()

-------------------------------------------------------------------------------

rinApp.cleanup()  -- shutdown application resources
os.exit()