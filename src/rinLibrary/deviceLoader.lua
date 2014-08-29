-------------------------------------------------------------------------------
-- Device loading library.
-- Provides wrappers for all device services
-- @module rinLibrary.deviceLoader
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local dbg = require "rinLibrary.rinDebug"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Module factory function begins here
return function (device, modules)
    local deviceColon = device .. ':'
    local _M, kt = {}, {}
    local deprecated, dwarned = {}, {}

    _M.model = device
    local private = {   deviceType = string.lower(device),
                        modules = { utilities = true }
                    }

    -- Populate the utility functions
    require('rinLibrary.utilities')(_M, private, deprecated)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
    -- Set up so that duplicate definitions are a fatal error.
    setmetatable(_M, {
        __index = kt,
        __newindex =
            function (t, k, v)
                if kt[k] == nil then
                    kt[k] = v
                else
                    dbg.fatal(deviceColon, "redefinition of ".. k .. " as", v)
                    os.exit(1)
                end
            end
    })
    setmetatable(deprecated, { __newindex = function(t, k, v) rawset(t, k, v) private.regPopulate(k, v) end })

    -- Load all the modules in order.
    for i = 1, #modules do
        require("rinLibrary." .. modules[i])(_M, private, deprecated)
        private.modules[modules[i]] = true
    end

    -- Copy the stored values back to the main table.
    setmetatable(deprecated, {})
    setmetatable(_M, {})
    for k, v in pairs(kt) do
        _M[k] = v
    end

    -- Provide a warning if an attempt is made to access an undefined field and
    -- allow access to deprecated fields with a different warning.
    setmetatable(_M, {
        __index =
            function(t, k)
                if deprecated[k] ~= nil then
                    if not dwarned[k] then
                        dbg.warn(deviceColon, "access of deprecated field: " .. tostring(k))
                        dwarned[k] = true
                    end
                    return deprecated[k]
                end
                dbg.warn(deviceColon, "attempt to access undefined field: " .. tostring(k))
                return nil
            end,

        __newindex =
            function(t, k, v)
                if deprecated[k] ~= nil then
                    if not dwarned[k] then
                        dbg.warn(deviceColon, "write to deprecated field: " .. tostring(k))
                        dwarned[k] = true
                    end
                    deprecated[k] = v
                else
                    rawset(t, k, v)
                end
            end
    })
    return _M
end
