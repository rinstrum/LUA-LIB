#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- testDialog
--
-- Example of how to use various library dialog functions
-------------------------------------------------------------------------------

local rinApp = require "rinApp"
local device = rinApp.addK400()
local dbg = require "rinLibrary.rinDebug"
local system = require 'rinSystem'

-------------------------------------------------------------------------------
-- Put a message on LCD and remove after 2 second delay
device.write('bottomLeft', "DIALOG")
device.write('bottomRight', "TEST")
rinApp.delay(2.000)
device.write('bottomLeft', "")
device.write('bottomRight', "")

id = device.editReg('userid1', 'NAME')
dbg.info(' Value: ', id)

-------------------------------------------------------------------------------
-- Prompt user to enter the number of times to sound buzzer, validate,
-- and then buzz after 0.5 second delay
local val = device.edit('BUZZ',2)
if device.askOK('OK?',string.format('BUZZ = %d',val)) == 'ok' then  -- confirm buzz amount
   rinApp.delay(0.500)
   device.buzz(val)
end

-------------------------------------------------------------------------------
-- Prompt user to select from a list of options. Options list will loop.
-- (e.g. if user presses 'up' key when option is large, loop back to small.
local sel = device.selectOption('SELECT',{'SMALL','MEDIUM','LARGE'},'SMALL',true)
rinApp.delay(0.010)
-- show selected option (on device and console) and wait until key pressed
device.write('bottomLeft', sel)
device.write('bottomRight', 'SELECTED')
dbg.info('Selected value', sel)
device.getKey()
device.write('bottomLeft', ' ')
device.write('bottomRight', ' ')
dbg.info('',device.editReg(0x1121,true))

-------------------------------------------------------------------------------
-- Key Handler for F1
-------------------------------------------------------------------------------
local function F1Pressed(key, state)
    dbg.info('','F1 Pressed')
    if (device.askOK('OK?','CONT') == 'ok') then
        device.buzz(3)
    end
    return true -- key handled here, don't send back to instrument for handling
end
device.setKeyCallback('f1', F1Pressed)

-------------------------------------------------------------------------------
-- Handler to capture PWR+ABORT key and end program
-------------------------------------------------------------------------------
device.setKeyCallback('pwr_cancel', rinApp.finish, 'long')

while rinApp.isRunning() do
  local k = device.getKey()
  if k == 'ok' then
     device.buzz(2)
  end
  system.handleEvents()           -- handleEvents runs the event handlers
end

rinApp.cleanup()  -- shutdown application resources
os.exit()
