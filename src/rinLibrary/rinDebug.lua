-------------------------------------------------------------------------------
-- Offer functions for converting variables into strings for debugging
-- @module rinLibrary.rinDebug
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local _M = {}

local pairs = pairs
local string = string
local type = type 
local print = print
local require = require

local logging = require "logging"
local logger

_M.DEBUG    = logging.DEBUG
_M.INFO     = logging.INFO
_M.WARN     = logging.WARN
_M.ERROR    = logging.ERROR
_M.FATAL    = logging.FATAL

_M.LEVELS = {}
_M.LEVELS[_M.DEBUG] = 'DEBUG'
_M.LEVELS[_M.INFO]  = 'INFO'
_M.LEVELS[_M.WARN]  = 'WARN'
_M.LEVELS[_M.ERROR] = 'ERROR'
_M.LEVELS[_M.FATAL] = 'FATAL'

_M.config = nil
_M.level = logging.INFO
_M.useTimestamp = false
_M.ip = ""

-------------------------------------------------------------------------------
-- Configures the level for debugging
-- @param config Config file containing the logger type, level and timestamp option
-- @param ip optional tag printed with each message (usually IP address of the instrument)
function _M.configureDebug(config, ip)
    
    _M.config = config
    
    logger = config.logger
    _M.level = config.level
    _M.useTimestamp = config.timestamp
  
    logger:setLevel(_M.level)
   
    if type(ip) == "string" then
        _M.ip = string.rep(" ", 15-#ip) .. ip
    end
end

-------------------------------------------------------------------------------
-- Configures the level for debugging
-- @return level lualogging level
-- @return timestamp: true if timestamp logging is to included 
-- @return ip 
function _M.getDebugConfig()
    return _M.config, _M.ip
end
-------------------------------------------------------------------------------
-- Converts table t into a string
-- @param t is a table
function _M.tableString(t)
    local s = '{'
    for k,v in pairs(t) do
         if v == nil then
             s = s .. (string.format('%s = <nil>, ',k))
        elseif type(v) == "table" then
            s = s .. string.format('%s = %s, ',k,_M.tableString(v))
        else
            s = s .. string.format('%s = %s, ',k,_M.varString(v))
        end
    end
    if #s < 3 then
        return ('{}')
    else
        -- take off the last 2 chars for the last member of the table
        return string.sub(s,1,-3) .. '}'     
    end  
end

-------------------------------------------------------------------------------
-- Converts arg into a string
-- @param arg is any variable
function _M.varString(arg)
    local t

    if arg == nil then
        return '<nil>'
    else
         t = type(arg)
    end

    if t == 'number' then
        return string.format("%s",tostring(arg))
    elseif t == "string" then
        -- replace any characters not between ASCII 32 and ASCII126 with [xx]
        return string.format('\"%s\"',string.gsub(arg,"[^\32-\126]",      
                        function(x) 
                            return string.format("[%02X]",string.byte(x))
                        end))
    elseif t == "boolean" then
        if arg then return "true" else return "false" end
    elseif t == "table" then
        return _M.tableString(arg)
    elseif t == "function" then
        return "<function>"
    else
        return "<unknown>"
    end
end

-------------------------------------------------------------------------------
-- Prints variable v contents to stdio with optional name tag
-- @param name is the name of the variable (optional)
-- @param v is a variable whose contents are to be printed
-- @param level is the debug level for the message  INFO by default
function _M.printVar(name, v, level)
    local level = level or _M.INFO

    if name then
        name = name .. ' '
    else 
        name = ''
    end
    
    local timestamp = ''
    if _M.useTimestamp then
        timestamp = os.date("%Y-%m-%d %X ")
    end
    
    if (_M.ip == nil) then
        _M.ip = ""
    end
    
    logger:log(level, string.format("%s%s %s: %s",
                                    timestamp,
                                    _M.ip,
                                    _M.LEVELS[level], 
                                    name .. _M.varString(v)))
end

-------------------------------------------------------------------------------
-- Function to test the module
function _M.testDebug()
    local a = nil
    local b = "Hello"
    local c = 25.7
    local d = true
    local e = {var = 1, tab = {a = 1, b= 2}}
    local f = { fred = 'friend', 
                address = nil, 
                phone = 123456, 
                happy = false, 
                find = function() print("go look yourself") end
              }

    print (_M.varString(a))
    print (_M.varString(b))
    print (_M.varString(c))
    print (_M.varString(d))
    print (_M.varString(e))
    print (_M.varString(f))
end

return _M