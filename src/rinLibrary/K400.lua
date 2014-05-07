-------------------------------------------------------------------------------
-- Library for K400 application support.
-- Provides wrappers for all device services
-- @module rinLibrary.K400
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

-- submodules are merged in as follows (and in this order):
local modules = {
    "rinCon",
    "K400Reg",
    "K400Util",
    "K400Stream",
    "K400Status",
    "K400Keys",
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
    -- Set up so that duplicate definitions are a fatal error.
    local _M, kt = {}, {}
    local mt = {
        __index = kt,
        __newindex = function (t, k, v)
                         if kt[k] == nil then
                             kt[k] = v
                         else
                             t.dbg.fatal("K400: redefinition of ".. k .. " as", v)
                             os.exit(1)
                         end
                     end
    }
    setmetatable(_M, mt)

    -- Load all the modules in order.
    for i = 1, #modules do
        require("rinLibrary." .. modules[i])(_M)
    end

    -- Provide a warning if an attempt is made to access an undefined field
    local function warnOnUndefined(t, k)
        _M.dbg.warn("K400: ", "attempt to access undefined field: " .. tostring(k))
        return nil
    end
    setmetatable(_M, { __index = warnOnUndefined })

    -- Copy the stored values back to the main table.
    for k, v in pairs(kt) do
        _M[k] = v
    end

    return _M
end
