-------------------------------------------------------------------------------
--- General purpose utility functions.
-- Functions for internal library use
-- @module rinLibrary.utilities
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"

local lpeg = require "lpeg"
local C, P, R = lpeg.C, lpeg.P, lpeg.R

local regPattern = P'REG_' * C(R('AZ', '09', '__')^1)

local lower = string.lower
local min, max = math.min, math.max

return function(private, deprecated)
    local regMap = { [0] = 0 }

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
-- Convert a named value into a real value but also let real values through
-- unmodified.
-- @function convertNameToValue
-- @param n Name to be converted
-- @param map Mapping from names to numeric values
-- @param default Default value to return if something is amiss
-- @param l Least value allowed
-- @param u Uppermost value allowed
-- @return The numeric code associted with the specified name
-- @local
    function private.convertNameToValue(n, map, default, l, u)
        local r
        if type(n) == 'string' then
            r = map[lower(n)] or default
        elseif type(n) == 'number' then
            r = n
        else
            r = default
        end
        if l ~= nil and r < l then r = default end
        if u ~= nil and r > u then r = default end
        return r
    end

-------------------------------------------------------------------------------
-- Convert a named value into a real value but also let real values through
-- unmodified.
-- @function convertValueToName
-- @param n Number to be converted
-- @param map Mapping from numeric values to names
-- @param default Default value to return if something is amiss
-- @return The name associted with the specified code
-- @local
    function private.convertValueToName(n, map, default)
        if type(n) == 'string' then
            return lower(n)
        elseif type(n) == 'number' then
            return map[n] or default
        end
        return default
    end

-------------------------------------------------------------------------------
-- Add an entry to the register mapping table
-- @function addRegister
-- @param k Key
-- @param v Value
-- @see getRegisterNumber
-- @see getRegisterName
-- @see regPopulate
-- @local
    function private.addRegister(reg, num)
        local r = lower(reg)
        regMap[r] = num
        regMap[num] = r
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
                private.addRegister(m, v)
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
        local n = private.convertNameToValue(r, regMap)
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
        local n = private.convertValueToName(r, regMap)
        if n == nil then
            dbg.warn('rinLibrary: ', 'unknown register '..tostring(r))
            a[nil] = nil
        end
        return n
    end

-------------------------------------------------------------------------------
-- Register a deprecated register name and value.
-- @function registerDeprecated
-- @param reg Register name
-- @local
    function private.registerDeprecated(reg)
        -- Have to rawset this to avoid hitting the set register capture
        -- function that is installed in the deprecated table.
        rawset(deprecated, 'REG_' .. string.upper(reg), private.getRegisterNumber(reg))
    end
end
