#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- usbPrinter
--
-- Minimal example of howw to drive a USB printer.
-------------------------------------------------------------------------------
local dbg = require 'rinLibrary.rinDebug'                                      
local rinApp = require "rinApp"
local usb = require "rinLibrary.rinUSB"                                  
local timers = require 'rinSystem.rinTimers'

local device = rinApp.addK400()

-- The file we'll use to write to the printer.
local printFile = nil

-- We have to listen for printer USB events.
usb.setUSBRegisterCallback(function (ev)
    for k,v in pairs(ev) do
        if v[1] == 'printer' then
            if v[2] == 'added' then
                printFile = v[3]
            else
                printFile = nil
            end
        end
    end
end)

-- And print something out to show we're working.
-- We can't print too quickly, we've got to let the printer keep up
-- with us.
local count = 0
timers.addTimer(1, 1, function()
    if printFile ~= nil then
        count = count + 1
        printFile:write('Line number ', count, '\r\n')
    end
end)

-- Run the main application.
rinApp.run()                                                                   
