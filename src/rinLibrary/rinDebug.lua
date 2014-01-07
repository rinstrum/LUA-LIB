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

-- Set the default logger type 
-- Refer to http://www.keplerproject.org/lualogging/manual.html
require "logging.console"
_M.logger = logging.console("%message\n")

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

_M.level = _M.INFO
_M.lastLevel = _M.level


_M.timestamp = false
_M.ip = ""

-- -- -- ------------------------------------------
-- private function
function _M.checkLevel(level)

   local level = level or _M.INFO
   if type(level) == 'string' then
      level = string.upper(level)
    end  
   
   local lev = _M.level
   for k,v in pairs(_M.LEVELS) do
     if k == level then
        lev = k
     elseif v == level then
        lev = k
     end
    end
   return lev  

end

-------------------------------------------------------------------------------
-- Set Debug level
-- @param level enumerated level constant or matching string.
-- If no match level set to INFO
function _M.setLevel(level)
   _M.lastLevel = _M.level
   _M.level = _M.checkLevel(level)
   _M.logger:setLevel(_M.level)    
end

-------------------------------------------------------------------------------
-- Restores Debug level to previous setting
function _M.restoreLevel()
   _M.level = _M.lastLevel
end


-------------------------------------------------------------------------------
-- Configures the level for debugging
-- @param level is debug level
-- @param timestamp true if timestamp to be included
-- @param ip optional tag printed with each message (usually IP address of the instrument)
function _M.configureDebug(level, timestamp, ip)
    
    _M.setLevel(level)    
    _M.timestamp = timestamp
  
    _M.logger:setLevel(_M.level)
   
    if type(ip) == "string" then
        _M.ip = string.rep(" ", 15-#ip) .. ip
    end
end
-------------------------------------------------------------------------------
-- returns debug configuration
-- @return level lualogging level
-- @return timestamp: true if timestamp logging is to included 
-- @return ip 
function _M.getDebugConfig()
    return _M.level, _M.timestamp, _M.ip
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

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at current debug level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed

function _M.print(prompt, ...)

    local timestr = ''
    if _M.timestamp then
        timestr = os.date("%Y-%m-%d %X ")
    end
    
    if (_M.ip == nil) then
        _M.ip = ""
    end
    
    local prompt = prompt or ''
    
    if type(prompt) == 'string' then
       s = prompt
    else   
       s = _M.varString(prompt) .. ' '
    end
    
    if arg.n == 0 then
      s = s .. _M.varString(nil)
    else    
      for i,v in ipairs(arg) do
        s = s .. _M.varString(v) .. ' '
      end  
    end    

    local level = _M.tempLevel or _M.level
     s = string.format("%s%s %s: %s",timestr, _M.ip, _M.LEVELS[level], s)
    _M.logger:log(level, s)
    _M.tempLevel = nil
                                   
end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at DEBUG level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed
function _M.debug(prompt,...)
    _M.tempLevel = _M.DEBUG    
    _M.print(prompt,unpack(arg))
end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at INFO level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed
function _M.info(prompt,...)
    _M.tempLevel = _M.INFO    
    _M.print(prompt,unpack(arg))
    
end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at WARN level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed

function _M.warn(prompt,...)
    _M.tempLevel = _M.WARN    
    _M.print(prompt,unpack(arg))
    
end
-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at ERROR level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed
function _M.error(prompt,...)
    _M.tempLevel = _M.ERROR    
    _M.print(prompt,unpack(arg))
end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at FATAL level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed
function _M.fatal(prompt,...)
    _M.tempLevel = _M.FATAL    
    _M.print(prompt,unpack(arg))
end

-------------------------------------------------------------------------------
-- Prints variable v contents to stdio with optional prompt
-- included for backward compatibility - replaced by print
-- @param prompt is an optional prompt
-- @param v is a variable whose contents are to be printed
-- @param level is the debug level for the message  INFO by default
function _M.printVar(prompt,v,level)
   _M.tempLevel = _M.checkLevel(level)
   _M.print(prompt,v)
end


return _M