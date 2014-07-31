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
        for r, v in pairs(reglist) do
            addRegister(r, v)
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
            unknown_register[nil] = nil
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
            unknown_register[nil] = nil
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
        for _, reg in pairs(registers) do
            local n = naming.convertNameToValue(reg, regMap)
            if n ~= nil then
                rawset(deprecated, 'REG_' .. string.upper(reg), n)
            end
        end
    end

    if _TEST then
        mod.getPrivate = function() return private end
    end

-------------------------------------------------------------------------------
-- Return our argument
-- @param v Value to return
-- @return v
-- @local
    local function willy(v)
        return v
    end

-------------------------------------------------------------------------------
-- Return nil
-- @param v Value to not return
-- @return nil
-- @local
    local function nilly(v)
        return nil
    end

-------------------------------------------------------------------------------
-- Filter a value based on a batching device
-- @function batching
-- @param v Value to return if batching
-- @return v or nil
-- @local

-------------------------------------------------------------------------------
-- Filter a value based on a nonbatching device
-- @function nonbatching
-- @param v Value to return if non-batching
-- @return v or nil
-- @local
    if private.deviceType == 'k410' then
        private.batching = willy
        private.nonbatching = nilly
    else
        private.batching = nilly
        private.nonbatching = willy
    end

-------------------------------------------------------------------------------
-- Filter a value based on a specific device
-- @function k401 k402 k410 k491
-- @param v Value to return if we're the specified device
-- @return v or nil
-- @local
    for _, d in pairs{'k401', 'k402', 'k410', 'k491'} do
        if private.deviceType == d then
            private[d] = willy
        else
            private[d] = nilly
        end
    end

end
