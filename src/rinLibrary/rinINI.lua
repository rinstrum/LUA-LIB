------------------------------------------------------------------------------
--- Services for saving and restoring settings in a table to .INI config file
-- @module rinLibrary.rinINI
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local io = io
local type = type
local pairs = pairs
local string = string
local table = table
local ipairs = ipairs
local tostring = tostring
local utils = require 'rinSystem.utilities'

-------------------------------------------------------------------------------
-- Saves table t as a .INI name (fname)
-- @string fname Name of file
-- @tab t is table of settings
-- @treturn tab Input table t if successful, nil otherwise
-- @usage
-- local config = {
--         general = { name = 'Fred'},  -- [general] group settings
--         comms = {baud = '9600',bits = 8, parity = 'N', stop = 1},  -- [comms] group settings
--         }
-- local t = ini.saveINI('config.ini',config)  -- save INI file to disk using config table

function _M.saveINI(fname, t)
    local f = io.open(fname, "w")
    if f == nil then
        return nil, [['Can't find ]] .. fname
    end

    for k,v in ipairs(t) do  -- put in comments (currently comments are all grouped at top of file)
        if type(v) == 'string' and string.sub(v,1,1) == ';' then
           f:write(v,'\n')
        end
     end
    for k,v in pairs(t) do    -- do global vars first
        if type(v) ~= 'table' then
            v = tostring(v)
            if string.sub(v,1,1) ~= ';' then  -- don't print comments again
                 f:write(k,'=',v,'\n')
            end
        end
    end

    for k,v in pairs(t) do   -- now do section vars
        if type(v) == 'table' then
            f:write('[',k,']','\n')
            for i,s in pairs(v) do
                f:write(i,'=',s,'\n')
            end
        end
    end
    f:close()
    utils.sync()
    return t
end

-------------------------------------------------------------------------------
-- populates table t with contents of INI file fname
-- if fname is not found a new file is created with table def contents
-- @string fname Name of file
-- @tab def Default table of settings
-- @treturn tab Table t or nil if file invalid
-- @usage
-- local t = ini.loadINI('config.ini',config)  -- load INI file from disk using config table
function _M.loadINI(fname, def)

    local lt = {}
    local t = {}
    local name, pos, val
    local extra = false

    local f = io.open(fname, "r")
    if f == nil then
        if def == nil then  return nil end
        return _M.saveINI(fname,def)
    end

    lt = t    -- support settings with no section header directly
    for s in f:lines() do
        -- Handle \r\n terminated ini files.
        if string.sub(s, -1) == '\r' then
            s = string.sub(s, 1, -2)  
        end
    
        local first = string.find(s,'%[')
        local last = string.find(s,'%]')
        if first ~= nil and last ~= nil then
            name = string.sub(s,first+1,last-1)
            lt = {}
            t[name] = lt
        else
            pos = string.find(s,'=')
            if pos ~= nil and pos > 1 then
                name = string.gsub(string.sub(s,1,pos-1),' ','')
                val = string.gsub(string.sub(s,pos+1),' ','')
                lt[name] = val
            elseif string.sub(s,1,1) == ';' then
                table.insert(t,s)  -- put comment in the main table
            end

        end
    end

   f:close()

   -- check default table to see if any extra settings to include
   for k,v in pairs(def) do
      if t[k] == nil then
         t[k] = def[k]
         extra = true
        end
    end

    if extra then
        _M.saveINI(fname,t)
    end   -- if extra fields in default table not already in file then save
    return t
end

-------------------------------------------------------------------------------
-- returns table t contents in an INI format string
-- @tab t T is table of settings
-- @treturn string A string in INI format
-- @usage
-- local t = ini.loadINI('config.ini',config)
-- print(ini.stringINI(t))
function _M.stringINI(t)

    local initab = {}

    table.insert(initab,'-------------------------------------------------------------------------------------\r\n')

    for k,v in pairs(t) do
        if type(v) ~= 'table' then
            table.insert(initab, string.format("%s=%s\r\n", k, v))
        end
    end

    for k,v in pairs(t) do
        if type(v) == 'table' then
            table.insert(initab, string.format("[%s]\r\n", k))
            for i,s in pairs(v) do
                table.insert(initab, string.format("%s=%s\r\n", i, s))
            end
        end
    end

    return table.concat(initab)
end

return _M
