-------------------------------------------------------------------------------
--- LCD Services.
-- Functions to configure the LCD
-- @module rinLibrary.Device.LCD
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local table = table
local ipairs = ipairs
local tonumber = tonumber
local pairs = pairs
local type = type

local naming = require 'rinLibrary.namings'
local utils = require 'rinSystem.utilities'
local timers = require 'rinSystem.rinTimers'

--- Display Fields.
--
-- These are use as the first arugment the the @see write and associated functions.
--
-- @table displayField
-- @field bottomLeft The bottom left field
-- @field bottomRight The bottom right field
-- @field topLeft The top left field
-- @field topRight The top right field
-- @field console Output to console

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

-------------------------------------------------------------------------------
-- Query the auto register for a display field
-- @param f Display field
-- @return Register name
-- @local
local function readAuto(f)
    if f == nil or f.regAuto == nil then
        return nil
    end
    local reg = private.readRegDec(f.regAuto)
    reg = tonumber(reg)
    f.auto = reg
    return private.getRegisterName(reg)
end

-------------------------------------------------------------------------------
-- Set the auto register for a display field
-- @param f Display field
-- @param register Register name
-- @local
local function writeAuto(f, register)
    if f ~= nil and register ~= nil then
        local reg = private.getRegisterNumber(register)

        if f.regAuto ~= nil and reg ~= f.auto then
            private.removeSlideTimer(f)
            f.current = nil
            f.currentReg = nil
            private.writeRegHexAsync(f.regAuto, reg)
            f.saveAuto = f.auto or 0
            f.auto = reg
        end
    end
end

-----------------------------------------------------------------------------
-- Link register address with display field to update automatically.
-- Not all fields support this functionality.
-- @param where which display section to write to
-- @param register address of register to link display to.
-- Set to 0 to enable direct control of the area
-- @see displayField
-- @usage
-- device.writeAuto('topLeft', 'grossnet')
function _M.writeAuto(where, register)
    return writeAuto(naming.convertNameToValue(where, private.getDisplay()), register)
end

-----------------------------------------------------------------------------
-- Reads the current auto update register for the specified field
-- @return register that is being used for auto update, 0 if none
-- @see displayField
-- @usage
-- local old = device.readAuto('topLeft')
-- device.writeAuto('topLeft', 'none')
-- ...
-- device.writeAuto('topLeft', old)
function _M.readAuto(where)
    return readAuto(naming.convertNameToValue(where, private.getDisplay()))
end
  
-------------------------------------------------------------------------------
-- Save the bottom left and right fields and units.
-- @treturn func Function that restores the bottom fields to their current values
-- @usage
-- local restoreBottom = device.saveBottom()
-- device.writeBotLeft('fnord')
-- restoreBottom()
function _M.saveBottom()
    return private.saver(function(v) return v.bottom end)
end


-------------------------------------------------------------------------------
-- Save the top and bottom left field auto settings
-- @treturn func Function that restores the left auto fields to their current values
-- @usage
-- device.saveAutoLeft()
function _M.saveAutoLeft()
    local restorations = {}
    private.map(function(v) return v.left end,
        function(v)
            v.saveAuto = v.auto or 0
            table.insert(restorations, { f=v, a=v.saveAuto })
        end)
    return function()
        for _, v in ipairs(restorations) do
            writeAuto(v.f, v.a)
        end
    end
end

-------------------------------------------------------------------------------
-- Rotate the WAIT annunciator
-- @param where which display section to write to
-- @param dir 1 clockwise, -1 anticlockwise 0 no change
-- @usage
-- while true do
--     device.rotWAIT('topLeft', -1)
--     rinApp.delay(0.7)
-- end
function _M.rotWAIT(where, dir)
  local f = naming.convertNameToValue(where, private.getDisplay())

  if type(f) == 'table' and utils.callable(f.rotWait) then
    return f.rotWait(dir)
  end
end

-------------------------------------------------------------------------------
-- Called to restore the LCD to its default state
-- @usage
-- device.restoreLcd()
function _M.restoreLcd()
    private.map(function(v) return v.localDisplay end, function(v) private.write(v, '') end)
    writeAuto(private.getDisplay().topleft, 'grossnet')
    writeAuto(private.getDisplay().bottomright, 0)

    writeAuto('topLeft', 0)
    _M.clearAnnunciators('bottomLeft', 'all')
    _M.writeUnits('bottomLeft', 'none')
end

end