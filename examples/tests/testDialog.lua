#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- testDialog
--
-- Example of how to use various library dialog functions
-------------------------------------------------------------------------------

local rinApp = require "rinApp"
local dwi = rinApp.addK400("K401")
local dbg = require "rinLibrary.rinDebug"
local system = require 'rinSystem.Pack'

-------------------------------------------------------------------------------
-- Put a message on LCD and remove after 2 second delay
dwi.write('bottomLeft', "DIALOG")
dwi.write('bottomRight', "TEST")
rinApp.delay(2.000)
dwi.write('bottomLeft', "")
dwi.write('bottomRight', "")

id = dwi.editReg('userid1', 'NAME')
dbg.info(' Value: ', id)

-------------------------------------------------------------------------------
-- Prompt user to enter the number of times to sound buzzer, validate,
-- and then buzz after 0.5 second delay
local val = dwi.edit('BUZZ',2)
if dwi.askOK('OK?',string.format('BUZZ = %d',val)) == 'ok' then   -- confirm buzz amount
   rinApp.delay(0.500)
   dwi.buzz(val)
end

-------------------------------------------------------------------------------
-- Prompt user to select from a list of options. Options list will loop.
-- (e.g. if user presses 'up' key when option is large, loop back to small.
local sel = dwi.selectOption('SELECT',{'SMALL','MEDIUM','LARGE'},'SMALL',true)
rinApp.delay(0.010)
-- show selected option (on device and console) and wait until key pressed
dwi.write('bottomLeft', sel)
dwi.write('bottomRight', 'SELECTED')
dbg.info('Selected value', sel)
dwi.getKey()
dwi.write('bottomLeft', ' ')
dwi.write('bottomRight', ' ')
dbg.info('',dwi.editReg(0x1121,true))

-------------------------------------------------------------------------------
-- Key Handler for F1
-------------------------------------------------------------------------------
local function F1Pressed(key, state)
    dbg.info('','F1 Pressed')
    if (dwi.askOK('OK?','CONT') == 'ok') then
        dwi.buzz(3)
    end
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback('f1', F1Pressed)

-------------------------------------------------------------------------------
-- Handler to capture PWR+ABORT key and end program
-------------------------------------------------------------------------------
dwi.setKeyCallback('pwr_cancel', rinApp.finish, 'long')

while rinApp.isRunning() do
  local k = dwi.getKey()
  if k == 'ok' then
     dwi.buzz(2)
  end
  system.handleEvents()           -- handleEvents runs the event handlers
end

rinApp.cleanup()  -- shutdown application resources
os.exit()
