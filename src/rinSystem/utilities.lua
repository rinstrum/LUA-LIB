-------------------------------------------------------------------------------
--- System utilities functions.
-- Functions for internal library use
-- @module rinSystem.utilities
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local posix = require 'posix'

local _M = {}

-------------------------------------------------------------------------------
-- A null function for use as a dummy callback
-- @return nil
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- null()
function _M.null()   return nil      end

-------------------------------------------------------------------------------
-- A function that always returns true
-- @return true
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- if utils.True() then print('yes') end
function _M.True()   return true     end

-------------------------------------------------------------------------------
-- A function that always returns false
-- @return false
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- if not utils.False() then print('yes') end
function _M.False()  return false    end

-------------------------------------------------------------------------------
-- Return a full deep copy of an original object.
-- @param o Object to copy
-- @param s Tables we've already seen
-- @return A copy of o
-- @local
local function dc(o, s)
    if type(o) == 'table' then
        if s[o] ~= nil then return s[o] end
        local c = {}
        s[o] = c

        for k, v in next, o, nil do
            c[dc(k, s)] = dc(v, s)
        end
        return setmetatable(c, dc(getmetatable(o), s))
    end
    return o
end

-------------------------------------------------------------------------------
-- Return a full deep copy of an original object.
-- @function deepcopy
-- @param o Object to copy
-- @return A copy of o that shares no data but is otherwise identical
-- @usage
-- local deepcopy = require 'rinLibrary.deepcopy'
--
-- local t = { 'a', 3, { 1, 4, 3 } }
-- local u = deepcopy(t)
--
-- assert.not_equal(t, u)
-- assert.same(t, u)
function _M.deepcopy(o) return dc(o, {}) end

-------------------------------------------------------------------------------
-- Return a callback if it is callable, return the default if not.
-- @param callback User supplied callback
-- @param default System suplied default
-- @return callback if callable, default if not
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- local callback = utils.cb(userCallback, utils.True)
function _M.cb(callback, default)
    return _M.callable(callback) and _M.deepcopy(callback) or default
end

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

-------------------------------------------------------------------------------
-- Force buffers to discs
-- @param wait Boolean indicating if we're to wait or not, default is wait.
function _M.sync(wait)
    if wait ~= false then
        os.execute('sync')
    else
        os.execute('sync &')
    end
end

-------------------------------------------------------------------------------
-- Reboot this Lua module
function _M.reboot()
    os.execute('reboot')
end

-------------------------------------------------------------------------------
-- Invert a table returning a new table
-- @param map Table containing the forward mapping
function _M.invert(map)
    local r = {}
    for k, v in pairs(map) do
        r[v] = k
    end
    return r
end

return _M
