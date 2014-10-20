-------------------------------------------------------------------------------
--- System utilities functions.
-- Functions for internal library use
-- @module rinSystem.utilities
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

-------------------------------------------------------------------------------
-- Check that an object is callable
-- @param obj
-- @return boolean true if object is callable, false otherwise
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- if utils.callable(f) then
--     f(1, 2, 3)
-- end
function _M.callable(obj)
    return type(obj) == "function" or type((debug.getmetatable(obj) or {}).__call) == "function"
end

-------------------------------------------------------------------------------
-- Check that a callback argument is really a function or nil
-- @function checkCallback
-- @param cb Callback argument
-- @return boolean true if the argument is a callback or nil, false otherwise
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- function callbackEnabler(cb)
--     utils.checkCallback(cb)
--     rememberCallback = cb
-- end
--
-- ...
-- if rememberCallback ~= nil then
--     rememberCallback(1, 2, 3)
-- end
function _M.checkCallback(cb)
    local r = cb == nil or _M.callable(cb)
    if not r then
        error('rinSystem: callback specified but not a function or nil')
    end
    return r
end

-------------------------------------------------------------------------------
-- Call a callback if it is callable, do nothing otherwise
-- @param cb Callback to call
-- @param ... Arguments to be passed to call back
-- @return The callback's return values
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- utils.call(myCallback, 1, 2, 'hello')
function _M.call(cb, ...)
    if _M.callable(cb) then
        return cb(...)
    end
end

return _M
