-------------------------------------------------------------------------------
--- USB Helper Infrastructure.
-- Support routines to provide a semi-standard interface to USB file copying
-- and package installation.
-- @module rinLibrary.Device.USB
-- @author Merrick
-- @copyright 2016 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local usb = require 'rinLibrary.rinUSB'
local dbg = require "rinLibrary.rinDebug"
local timers = require 'rinSystem.rinTimers'
local utils = require 'rinSystem.utilities'
local naming = require 'rinLibrary.namings'
local posix = require 'posix'

local pairs = pairs
local os = os

local REG_LUA_USB_NOTIFY = 0x0370

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)
    
-------------------------------------------------------------------------------
-- Unmount the attached USB storage device.
--
-- @usage
-- device.usbUnmount()
function _M.usbEject()
    usb.commitFileChanges()
    private.exReg(REG_LUA_USB_NOTIFY)
end

end
