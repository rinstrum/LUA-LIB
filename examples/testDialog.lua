-------------------------------------------------------------------------------
-- testDialog
-- 
-- Example of how to use various library dialog functions
-------------------------------------------------------------------------------

-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local rinApp = require "rinApp"
local dwi = rinApp.addK400("K401")
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- Put a message on LCD and remove after 2 second delay
dwi.writeBotLeft("DIALOG")
dwi.writeBotRight("TEST")
dwi.delay(2000)
dwi.writeBotLeft("")
dwi.writeBotRight("")

id = dwi.editReg(dwi.REG_USERID1)
dbg.printVar(' Value: ', id)

-------------------------------------------------------------------------------
-- Prompt user to enter the number of times to sound buzzer, validate, 
-- and then buzz after 0.5 second delay  
local val = dwi.edit('BUZZ',2)
if dwi.askOK('OK?',val) == dwi.KEY_OK then   -- confirm buzz amount
   dwi.delay(500)
   dwi.buzz(val)
end   

-------------------------------------------------------------------------------
-- Prompt user to select from a list of options. Options list will loop.
-- (e.g. if user presses 'up' key when option is large, loop back to small.
local sel = dwi.selectOption('SELECT',{'SMALL','MEDIUM','LARGE'},'SMALL',true)
dwi.delay(10)
-- show selected option (on device and console) and wait until key pressed
dwi.writeBotLeft(sel)
dwi.writeBotRight('SELECTED')
dbg.printVar('Selected value', sel, dbg.INFO)
dwi.getKey()

rinApp.cleanup()  -- shutdown application resources
os.exit()