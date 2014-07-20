-------------------------------------------------------------------------------
--- General purpose utility functions.
-- Functions for internal library use
-- @module rinLibrary.utilities
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'

local lpeg = require "lpeg"
local C, P, R = lpeg.C, lpeg.P, lpeg.R

local regPattern = P'REG_' * C(R('AZ', '09', '__')^1)

local lower = string.lower
local min, max = math.min, math.max

return function(mod, private, deprecated)
    local regMap, regUnmap = { [0] = 0 }, { [0] = 0 }

-------------------------------------------------------------------------------
-- Check if a particular module or modules have been loaded.
-- @function isModuleLoaded
-- @param m Module name(s)
-- @return true iff all the specified modules are loaded
-- @local
    function private.isModuleLoaded(...)
        local r = true
        for _, m in pairs({...}) do
            r = r and (private.modules[m] or false)
        end
        return r
    end

-------------------------------------------------------------------------------
-- Add an entry to the register mapping table
-- @param reg Key
-- @param num Value
-- @see addRegisters
-- @local
    local function addRegister(reg, num)
        local r = lower(reg)
        regMap[r] = num
        regUnmap[num] = r
    end

-------------------------------------------------------------------------------
-- Add a list of registers to the mapping table
-- @function addRegisters
-- @param reglist List of pairs to add
-- @see addRegister
-- @see getRegisterNumber
-- @see getRegisterName
-- @see regPopulate
-- @usage
-- private.addRegisters{{ 'regname', 0x666}}
--
-- private.addRegisters{
--     { 'dead', 0xdead },
--     { 'beef', 0xbeef }
-- }
-- @local
    function private.addRegisters(reglist)
        for _, v in pairs(reglist) do
            addRegister(v[1], v[2])
        end
    end

-------------------------------------------------------------------------------
-- Add an entry to the register mapping table if it is of the correct form
-- @function regPopulate
-- @param k Key
-- @param v Value
-- @see getRegisterNumber
-- @see getRegisterName
-- @see addRegister
-- @local
    function private.regPopulate(k, v)
        if type(k) == "string" then
            local m = regPattern:match(k)
            if m ~= nil then
                addRegister(m, v)
            end
        end
    end

-------------------------------------------------------------------------------
-- Convert a string register name to the associated register number.
-- @function getRegisterNumber
-- @param r Register name or number
-- @return Register number
-- @see getRegisterName
-- @usage
-- -- Find out what register number the gross weight is stored in
-- print(private.getRegisterNumber('gross')
-- @local
    function private.getRegisterNumber(r)
        local n = naming.convertNameToValue(r, regMap)
        if n == nil then
            dbg.error('rinLibrary: ', 'bad register '..tostring(r))
            a[nil] = nil
        end
        return n
    end

-------------------------------------------------------------------------------
-- Convert a register number to the associated canonical register name.
-- @function getRegisterName
-- @param r Register name or number
-- @return Register name
-- @see getRegisterNumber
-- @local
    function private.getRegisterName(r)
        local n = naming.convertValueToName(r, regUnmap)
        if n == nil then
            dbg.warn('rinLibrary: ', 'unknown register '..tostring(r))
            a[nil] = nil
        end
        return n
    end

-------------------------------------------------------------------------------
-- Register a deprecated register name and value.
-- @function registerDeprecated
-- @param registers List of register names
-- @local
    function private.registerDeprecated(registers)
        -- Have to rawset this to avoid hitting the set register capture
        -- function that is installed in the deprecated table.
        for k, reg in pairs(registers) do
            rawset(deprecated, 'REG_' .. string.upper(reg), private.getRegisterNumber(reg))
        end
    end

    if _TEST then
        mod.getPrivate = function() return private end
    end
end
