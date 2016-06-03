-------------------------------------------------------------------------------
--- System utilities functions.
-- Functions for internal library use
-- @module rinSystem.utilities
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local lpeg = require 'lpeg'
local Cg, Ct, Cs, P = lpeg.Cg, lpeg.Ct, lpeg.Cs, lpeg.P

local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable
local next = next
local error = error
local debug = debug
local os = os
local pairs = pairs
local table = table
local tostring = tostring
local ipairs = ipairs
local pcall = pcall
local string = string
local loadfile = loadfile
local io = io

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
-- @treturn bool True
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- if utils.True() then print('yes') end
function _M.True()   return true     end

-------------------------------------------------------------------------------
-- A function that always returns false
-- @treturn bool False
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
-- @tab o Object to copy
-- @treturn tab A copy of o that shares no data but is otherwise identical
-- @usage
-- local deepcopy = require('rinSystem.utilities').deepcopy
--
-- local t = { 'a', 3, { 1, 4, 3 } }
-- local u = deepcopy(t)
--
-- assert.not_equal(t, u)
-- assert.same(t, u)
function _M.deepcopy(o) return dc(o, {}) end

-------------------------------------------------------------------------------
-- @function readonlyreference
-- @param o Object to copy
-- @return A copy of o that is read only
-- @usage
-- local readonly = readonlyreference{ 1, 2, 3 }
-- @local
function _M.readonlyreference(o)
    if type(o) == 'table' then
        return setmetatable({}, {
            __index = o,
            __newindex = function(t, n, v)
                error('rinSystem: attempt to write to a read only table')
            end
        })
    end
    return o
end

-------------------------------------------------------------------------------
-- Return a callback if it is callable, return the default if not.
-- @func callback User supplied callback
-- @func default System suplied default
-- @treturn func Callback if callable, default if not
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
-- @treturn bool True if object is callable, false otherwise
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
-- @tparam bool True if the argument is a callback or nil, false otherwise
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
-- @func cb Callback to call
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
-- @bool[opt] wait Boolean indicating if we're to wait, default is wait.
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- utils.sync()
function _M.sync(wait)
    if wait ~= false then
        os.execute('sync')
    else
        os.execute('sync &')
    end
end

-------------------------------------------------------------------------------
-- Reboot this Lua module
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- utils.reboot()
function _M.reboot()
    os.execute('reboot')
end

-------------------------------------------------------------------------------
-- Invert a table returning a new table
-- @tab map Table containing the forward mapping
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- local map = { a = 1, b = 3, c = 2 }
-- local unmap = utils.invert(map)
--
-- -- unmap is equivalent to { 'a', 'c', 'b' }
function _M.invert(map)
    local r = {}
    for k, v in pairs(map) do
        r[v] = k
    end
    return r
end

-------------------------------------------------------------------------------
-- Load a text file as a number of lines in a table
-- @string filename The path of the file to be read
-- @treturn tab Table of lines or nil on error
-- @treturn string Error or nil if none
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- local lines, err = utils.loadFileByLines('myfile.txt')
function _M.loadFileByLines(filename)
    local lines, f, err = {}, io.open('ticket.txt', 'r')
    if f then
        for l in f:lines() do
            table.insert(lines, l)
        end
        f:close()
        return lines
    end
    return nil, err
end

-------------------------------------------------------------------------------
-- Create a function that accepts an incoming stream of data and breaks it into
-- pieces according to the start, end and escape characters, string or patterns.
-- The stream is buffered and reassembled as required.
-- @func callback Callback to accept the broken down chunks
-- @string[opt] start Start character, string or pattern (can be nil for none)
-- @string[opt] fin End character, string or pattern (cannot be nil)
-- @string[opt] escape Escape character, string or pattern (can be nil for no escape)
-- @treturn func A function to process and buffer an incoming stream
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- local function process(s, err)
--     if err then print('error:', err)
--     else        print('received:', s)
--     end
-- end
--
-- local stream = utils.streamProcessor(process, '\2', '\3', '\16')
function _M.streamProcessor(callback, start, fin, escape)
    _M.checkCallback(callback)
    if fin == nil then
        error 'streamProcessor: must have a finish sequence defined'
    end

    local function wrap(s)
        if type(s) == 'userdata'  then  return s
        elseif type(s) == 'nil'   then  return nil
        elseif type(s) == 'table' then  return P(s) / ''
        end
        return P(tostring(s)) / ''
    end

    start, fin, escape = wrap(start), wrap(fin), wrap(escape)
    local begin = start ~= nil and (1-start)^0 / '' * start or P(true)
    local body, rest = 1 - fin, P(1)^0
    if escape ~= nil then   body = escape * P(1) + body end
    local msg = Ct(Cs(begin * body^0 * fin)^0 * Cg(Cs(rest), 'residue'))

    local buf, cb = '', _M.deepcopy(callback)
    return function(c, err, ...)
        if err then
            _M.call(cb, nil, err, ...)
        else
            buf = buf .. c
            local r = msg:match(buf)
            if r then
                buf = r.residue
                for k, v in ipairs(r) do
                    _M.call(cb, v, nil, ...)
                end
            end
        end
    end
end

--=============================================================================
-- Persistent table implementation starts here

-------------------------------------------------------------------------------
-- Save a table or tables to file so they can be restored later using loadfile.
-- The created file returns the tables in the same order they are passed to
-- this function.
-- @tparam file f File to save to
-- @tab ... Tables to save
-- @usage
-- local utils = require 'rinSystem.utilities'
--
-- local subTable = {
--     { 'this', { 'is', { 'another', { 'table' } } } }
-- }
-- local myTable = {
--     'abc', 123, 'hello world',
--     name = 'fred',
--     nesting = subTable,
--     not_a_copy_of_nesting = subTable,
--     happy = true
-- }
-- local f = io.open('myfile.lua', 'w')
-- if f then
--     utils.saveTableToFile(f, myTable)
--     io.close(f)
-- end
--
-- ...
--
-- local mySavedTable, err = loadfile('myfile.lua')
function _M.saveTableToFile(f, ...)
    local tbls = { ... }
    local indent, cache, idx, writers = '', {}, 0

    local function doCache(v)
        if type(v) == 'table' or type(v) == 'function' then
            if cache[v] == nil then
                cache[v] = false
                if type(v) == 'table' then  
                    for x, y in pairs(v) do
                        doCache(x)
                        doCache(y)
                    end
                end
            elseif cache[v] == false then
                idx = idx + 1
                cache[v] = 'z'..idx
            end
        end
    end

    local function w(x)
        writers[type(x)](x)
    end

    local function emitFunction(v)
		local info = debug.getinfo(v, "uS");
		if info.nups > 0 then
			f:write('nil --[[ function with upvalue ]] ');
		elseif info.what ~= 'Lua' then
			f:write('nil --[[ not Lua ]] ');
		else
            local r, s = pcall(string.dump, v)
            if s then
                f:write(string.format('loadstring(%q)', s))
            else
                f:write('nil --[[ dump failed ]] ')
            end
        end
    end

    local function unquoted(x)
        return type(x) == 'string' and x:find '^[%a_][%w_]*$'
    end

    writers = {
        ['nil'] = function(v) f:write('nil') end,
        number  = function(v) f:write(tostring(v)) end,
        string  = function(v) f:write(string.format('%q', v)) end,
        boolean = function(v) f:write(v and 'true' or 'false') end,
        table   = function(v)
            if cache[v] then
                f:write(cache[v])
            else
                f:write('{\n')
                indent = indent .. '  '
                for x, y in pairs(v) do
                    if unquoted(x) then
                        f:write(indent, x, ' = ')
                    else
                        f:write(indent, '[')
                        w(x)
                        f:write '] = '
                    end
                    w(y)
                    f:write ',\n'
                end
                indent = indent:sub(1, -3)
                f:write(indent, '}')
            end
        end,
        ['function'] = function(v)
            if cache[v] then
                f:write(cache[v])
            else
                emitFunction(v)
            end
        end,
        thread  = function(v) f:write('nil --[[ thread ]] ') end,
        userdata= function(v) f:write('nil --[[ userdata ]] ') end
    }

    for k, t in ipairs(tbls) do
        doCache(t)
        cache[t] = cache[t] or ('a'..k)
    end

    for k, v in pairs(cache) do
        if v then
            if type(k) == 'table' then
                f:write('local '..v..' = {}\n')
            else
                f:write('local '..v..' = ')
                emitFunction(k)
                f:write'\n'
            end
        end
    end

    for k, v in pairs(cache) do
        if v then
            if type(k) == 'table' then
                local n = cache[k]
                for k, v in pairs(k) do
                    if unquoted(k) then
                        f:write(n, '.', k, ' = ')
                    else
                        f:write(n, '[')
                        w(k)
                        f:write('] = ')
                    end
                    w(v)
                    f:write('\n')
                end
            end
        end
    end

    f:write 'return '
    for i = 1, #tbls do
        f:write(cache[tbls[i]])
        if i < #tbls then f:write ', ' end
    end
    f:write '\n'
end

-------------------------------------------------------------------------------
-- Create a persistent table that will retain its values across restarts and
-- reboots.
--
-- A persistent table looks and behaves much like a normal table but not
-- completely.
--
-- The biggest difference is the inability to use pairs or ipairs on a persistent
-- table.  They simply don't work.  This implies that any function that
-- relies on these to work won't.  However, the table is created with pairs and ipairs
-- functions as part of itself.  They are named <i>_pairs</i> and <i>_ipairs</i>
-- respectively.  They don't take any arguments but otherwise behave as expected.
--
-- The next important difference is that changes to tables inside a persistent
-- table are not automatically detected and saved to backing store.  You must
-- change something in the table itself for this to occur.  There is a function
-- included in the table <i>_save</i> which saves the table to backing store to
-- cover this case.  It doesn't take any arguments and doesn't return any results.
--
-- There are also restriction on functions in the table.  Only Lua functions
-- that don't use upvalues can be saved (and they are).  There is no workaround
-- for this restriction.
-- @string filename Name of the backing file for the persistent table
-- @tab defaults Table of values which are added to the persistent table if not already present
-- @treturn tab Persistent table, contents as before or empty if newly created
-- @usage
-- local history = utils.persistentTable 'history.lua'
function _M.persistentTable(filename, defaults)
    local fname, t = filename

    pcall(function()
        local f, err = loadfile(fname)
        if f then t = f() end
    end)
    t = t or {}

    local function saveTable()
        local f = io.open(fname, "w")
        if f then
            f:write "-- Don't edit this file, it is overwritten by the application\n"
            _M.saveTableToFile(f, t)
            f:close()
            _M.sync(false)
        end
    end

    if type(defaults) == 'table' then
        local changes = false
        for k, v in pairs(defaults) do
            if t[k] == nil then
                t[k] = v
                changes = true
            end
        end
        if changes then saveTable() end
    end

    return setmetatable({
        _pairs = function() return pairs(t) end,
        _ipairs = function() return ipairs(t) end,
        _save = saveTable
    }, {
        __index = t,
        __newindex = function(r, f, v)
            if t[f] ~= v then
                t[f] = v
                saveTable()
            end
        end,
        __metatable = {}
    })
end

return _M
