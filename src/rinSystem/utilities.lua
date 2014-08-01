-------------------------------------------------------------------------------
--- Meta utilities functions.
-- Functions for internal library use
-- @module rinLibrary.metautilities
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

-------------------------------------------------------------------------------
-- Check that an object is callable
-- @param obj
-- @return true if object is callable
-- @local
function _M.callable(obj)
    return type(obj) == "function" or type((debug.getmetatable(obj) or {}).__call) == "function"
end

-------------------------------------------------------------------------------
-- Check that a callback argument is really a function or nil
-- @function checkCallback
-- @param cb Callback argument
-- @return boolean true if the argument is a callback or nil
-- @local
function _M.checkCallback(cb)
    local r = cb == nil or _M.callable(cb)
    if not r then
        print('rinSystem: callback specified but not a function or nil')
        nonFunctionCallbackFound[nil] = nil
    end
    return r
end

return _M
