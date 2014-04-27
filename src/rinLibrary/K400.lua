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

    -- There are two options for removal of the double assignment check.  Both
    -- remove the newindex function so that things can be added to the table.
    -- We can't simply return kv instead of _M for obvious reasons.

    -- The first is to block modification of the metatable and leave things as
    -- they are (the newindex bit is likely optional):
    --setmetatable(_M, { __index = kt, __newindex = kt, __metatable = {} })

    -- The second is to totally remove the metatable and to copy the stored values
    -- back to the main table.  This way has no risk of breaking existing code that
    -- does silly things e.g. iterating over pairs(_M)
    setmetatable(_M, {})
    for k, v in pairs(kt) do
        _M[k] = v
    end

    return _M
end
