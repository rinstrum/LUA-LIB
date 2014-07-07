-------------------------------------------------------------------------------
-- Library for K400 application support.
-- Provides wrappers for all device services
-- @module rinLibrary.K400
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local lpeg = require "lpeg"
local C, P, R = lpeg.C, lpeg.P, lpeg.R

local dbg = require "rinLibrary.rinDebug"

-- submodules are merged in as follows (and in this order):
local modules = {
    "rinCon",
    "K400Reg",
    "K400Util",
    "K400Stream",
    "K400Status",
    "K400Keys",
    "K400Buzz",
    "K400LCD",
    "K400Dialog",
    "K400RTC",
    "K400Analog",
    "K400Setpoint",
    "K400Print",
    "K400Command"
}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Module factory function begins here
return function ()
    local _M, kt = {}, {}
    local depricated, private, dwarned = {}, {}, {}
    local regPattern = P'REG_' * C(R('AZ', '09', '__')^1)
    local regMap, regUnmap = {}, { [0] = 0 }

    -- Populate the utility functions
    require('rinLibrary.utilities')(private)

-------------------------------------------------------------------------------
-- Add an entry to the register mapping table if it is of the correct form
-- @param k Key
-- @param v Value
-- @see private.getRegisterNumber
-- @see private.getRegisterName
-- @local
    local function regPopulate(k, v)
        if type(k) == "string" then
            local m = regPattern:match(k)
            if m ~= nil then
                local r = string.lower(m)
                regMap[r] = v
                regUnmap[v] = r
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
        return private.convertNameToValue(r, regMap)
    end

-------------------------------------------------------------------------------
-- Convert a register number to the associated canonical register name.
-- @function getRegisterName
-- @param r Register name or number
-- @return Register name
-- @see getRegisterNumber
-- @local
    function private.getRegisterName(r)
        return private.convertValueToName(r, regUnmap)
    end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
    -- Set up so that duplicate definitions are a fatal error.
    setmetatable(_M, {
        __index = kt,
        __newindex =
            function (t, k, v)
                if kt[k] == nil then
                    kt[k] = v
                    regPopulate(k, v)
                else
                    dbg.fatal("K400: redefinition of ".. k .. " as", v)
                    os.exit(1)
                end
            end
    })
    setmetatable(depricated, { __newindex = function(t, k, v) rawset(t, k, v) regPopulate(k, v) end })

    -- Load all the modules in order.
    for i = 1, #modules do
        require("rinLibrary." .. modules[i])(_M, private, depricated)
    end

    -- Copy the stored values back to the main table.
    setmetatable(depricated, {})
    setmetatable(_M, {})
    for k, v in pairs(kt) do
        _M[k] = v
    end

    -- Provide a warning if an attempt is made to access an undefined field
    setmetatable(_M, {
        __index =
            function(t, k)
                if depricated[k] ~= nil then
                    if not dwarned[k] then
                        dbg.warn("K400: ", "access of depricated field: " .. tostring(k))
                        dwarned[k] = true
                    end
                    return depricated[k]
                end
                dbg.warn("K400: ", "attempt to access undefined field: " .. tostring(k))
                return nil
            end,

        __newindex =
            function(t, k, v)
                if depricated[k] ~= nil then
                    if not dwarned[k] then
                        dbg.warn("K400: ", "write to depricated field: " .. tostring(k))
                        dwarned[k] = true
                    end
                    depricated[k] = v
                else
                    rawset(t, k, v)
                end
            end
    })

    return _M
end
