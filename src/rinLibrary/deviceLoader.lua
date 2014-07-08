-------------------------------------------------------------------------------
-- Device loading library.
-- Provides wrappers for all device services
-- @module rinLibrary.deviceLoader
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Library for K400 application support.
-- Provides wrappers for all device services
-- @module rinLibrary.K400
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"
local lpeg = require "lpeg"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Module factory function begins here
return function (device, modules)
    local deviceColon = device .. ': '
    local _M, kt = {}, {}
    local depricated, dwarned = {}, {}
    local private = {   deviceType = device,
                        [device] = true,
                        modules = { utilities = true }
                    }

    -- Populate the utility functions
    require('rinLibrary.utilities')(private)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
    -- Set up so that duplicate definitions are a fatal error.
    setmetatable(_M, {
        __index = kt,
        __newindex =
            function (t, k, v)
                if kt[k] == nil then
                    kt[k] = v
                    private.regPopulate(k, v)
                else
                    dbg.fatal(deviceColon, "redefinition of ".. k .. " as", v)
                    os.exit(1)
                end
            end
    })
    setmetatable(depricated, { __newindex = function(t, k, v) rawset(t, k, v) private.regPopulate(k, v) end })

    -- Load all the modules in order.
    for i = 1, #modules do
        require("rinLibrary." .. modules[i])(_M, private, depricated)
        private.modules[modules[i]] = true
    end

    -- Copy the stored values back to the main table.
    setmetatable(depricated, {})
    setmetatable(_M, {})
    for k, v in pairs(kt) do
        _M[k] = v
    end

    -- Provide a warning if an attempt is made to access an undefined field and
    -- allow access to depricated fields with a different warning.
    setmetatable(_M, {
        __index =
            function(t, k)
                if depricated[k] ~= nil then
                    if not dwarned[k] then
                        dbg.warn(deviceColon, "access of depricated field: " .. tostring(k))
                        dwarned[k] = true
                    end
                    return depricated[k]
                end
                dbg.warn(deviceColon, "attempt to access undefined field: " .. tostring(k))
                return nil
            end,

        __newindex =
            function(t, k, v)
                if depricated[k] ~= nil then
                    if not dwarned[k] then
                        dbg.warn(deviceColon, "write to depricated field: " .. tostring(k))
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
