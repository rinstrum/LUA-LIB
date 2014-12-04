#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- Print Copy
--
-- Application to print Carbon copy
--
-- Copy this file to your project directory and insert the specific code of
-- your application
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local dbg = require 'rinLibrary.rinDebug'

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local device = rinApp.addK400()        --  make a connection to the instrument
device.loadRIS("printCopy.RIS")        -- load default instrument settings

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

-------------------------------------------------------------------------------
-- Handler for SerB messages
-------------------------------------------------------------------------------

printCopy = {}  -- table to hold print lines of text

function printHandler(s)
   dbg.print('SER3B:', s)
   device.printCustomTransmit(s, 'ser1a')
   table.insert(printCopy,s)
end
--device.setDelimiters('\02','\03')
device.setSerBCallback(printHandler)

-------------------------------------------------------------------------------
-- Callback to handle F3 key event
local function F3Pressed(key, state)
   dbg.info('Copy Printed')
   if #printCopy > 0 then
       device.printCustomTransmit([[--------------------------\C1]], 'ser1a')
       for k,v in ipairs(printCopy) do
         device.printCustomTransmit(v, 'ser1a')
       end
       device.printCustomTransmit([[<<Copy>>\C1]], 'ser1a')
       printCopy = {}
    end
   return true
end
device.setKeyCallback('f3', F3Pressed)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
device.setKeyCallback('pwr_cancel', rinApp.finish, 'long')

-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

device.write('bottomLeft', "PRINT")
device.write('bottomRight', "COPY")

--=============================================================================
-- Main Application Loop
--=============================================================================
rinApp.run()                       -- run the application framework
