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
local unpack = unpack
local tostring = tostring
local os = os
local ipairs = ipairs
local math = math

local logging = require "logging"

-- Local variables
local secondaryLogFunction = nil

-- Set the default logger type
-- Refer to http://www.keplerproject.org/lualogging/manual.html
require "logging.console"
require "logging.file"
_M.logger = logging.console("%message\n")

_M.DEBUG    = logging.DEBUG
_M.INFO     = logging.INFO
_M.WARN     = logging.WARN
_M.ERROR    = logging.ERROR
_M.FATAL    = logging.FATAL

local levelNames = {
    DEBUG = _M.DEBUG,
    INFO  = _M.INFO,
    WARN  = _M.WARN,
    ERROR = _M.ERROR,
    FATAL = _M.FATAL
}
local levels = setmetatable({}, { __index = function(t,k) return _M.INFO end })

for k, v in pairs(levelNames) do
    levels[k], levels[v] = v, k
end

_M.level = _M.DEBUG
_M.lastLevel = _M.level

_M.timestamp = 'off'

-------------------------------------------------------------------------------
-- Determine the debug level either numeric or textual
-- @param level Level of debug to check
-- @return the numeric coded level corresponding to the specicied level
-- @local
local function checkLevel(level)
    if type(level) == 'string' then
        level = string.upper(level)
    end
    return levels[level]
end

-------------------------------------------------------------------------------
-- Set Debug level
-- @param level enumerated level constant or matching string.
-- If no match level set to INFO
function _M.setLevel(level)
   _M.lastLevel = _M.level
   _M.level = checkLevel(level)
   if _M.lastLevel ~= _M.level then
      _M.logger:setLevel(_M.level)
   end	
end

-------------------------------------------------------------------------------
-- Restores Debug level to previous setting
function _M.restoreLevel()
   _M.level = _M.lastLevel
end

function _M.setLogger(config)

  if config.logger == 'file' then
     _M.logger = logging.file(config.file.filename,nil,"%message\n")
  else -- config.logger is 'console' by default
	 config.logger = 'console'
	 _M.logger = logging.console("%message\n")
  end
end

_M.config = {
         level = 'INFO',
         timestamp = 'on',
         logger = 'console'
		 }

function _M.setConfig(config)
    _M.config = config
    _M.config.level = checkLevel(_M.config.level)
    _M.config.timestamp = config.timestamp or 'on'
    _M.setLogger(_M.config)
end

-------------------------------------------------------------------------------
-- Configures the level for debugging
-- @param config is table of settings
-- @usage
-- dbg.configureDebug({level = 'DEBUG',timestamp = 'on', logger = 'console'})
function _M.configureDebug(config)

	_M.setConfig(config)
    _M.setLevel(_M.config.level)
    _M.timestamp = _M.config.timestamp

end
-------------------------------------------------------------------------------
-- returns debug configuration table
-- @return config table eg{level = 'DEBUG',timestamp = 'on', logger = 'console'}
function _M.getDebugConfig()
    return _M.config
end

-------------------------------------------------------------------------------
-- Converts table t into a string
-- @param t is a table
-- @param margin is a blank string to enable pretty formatting of t
function _M.tableString(t,margin)
    local s = ''
    local pad = ''
    local margin = margin or 0

    if margin > 0 then
       pad = '{'
    end
    local first = true
    for k,v in pairs(t) do
         k = tostring(k)
         if v == nil then
            s = s .. (string.format('%s%s = <nil>, ',pad,k))
        elseif type(v) == "table" and type(k) == "number" then
            local lenk = math.floor(math.log10(k)) + 1
            s = s .. string.format('%s%s = %s, ',pad,k,_M.tableString(v,margin+lenk+4))
        elseif type(v) == "table" then
            s = s .. string.format('%s%s = %s, ',pad,k,_M.tableString(v,margin+#k+4))
        else
            s = s .. string.format('%s%s = %s, ',pad,k,_M.varString(v))
        end
        if first then
             first = false
             pad = '\n'..string.rep(' ', margin+1)
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
-- @param margin is the number of spaces to leave on each line of a table display
function _M.varString(arg,margin)
    local t
    local margin = margin or 0

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
        return _M.tableString(arg,margin)
    elseif t == "function" then
        return "<function>"
    elseif t == "userdata" then
        return string.format("%s",tostring(arg))
    else
        return "<unknown>"
    end
end

-----------------------------------------------------------------------------------
-- Set a secondary debug capability
-- @param logfunction The function to call for extra logging
function _M.setDebugCallback(logfunction)
	secondaryLogFunction = logfunction
end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at current debug level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed

function _M.print(prompt, ...)

    local timestr = ''
    local s

    if _M.timestamp == 'on' then
        timestr = os.date("%Y-%m-%d %X ")
    end

    local level = _M.tempLevel or _M.level
    local header = string.format("%s %s: ", timestr, levelNames[level])
    local margin = #header

    if type(prompt) == 'string' then
       s = prompt .. ' '
       margin = margin + #s
    else
       s = _M.varString(prompt,margin) .. ' '
    end

    if arg.n == 0 then
        s = s .. _M.varString(nil)
    else
        for i,v in ipairs(arg) do
            s = s .. _M.varString(v,margin) .. ' '
        end
   end

    s = string.format("%s%s",header, s)
    _M.logger:log(level, s)
    if secondaryLogFunction ~= nil then
        secondaryLogFunction(s)
    end
    _M.tempLevel = nil
end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at DEBUG level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed
function _M.debug(prompt, ...)
    _M.tempLevel = _M.DEBUG
    _M.print(prompt, ...)
end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at INFO level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed
function _M.info(prompt, ...)
    _M.tempLevel = _M.INFO
    _M.print(prompt, ...)

end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at WARN level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed

function _M.warn(prompt, ...)
    _M.tempLevel = _M.WARN
    _M.print(prompt, ...)

end
-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at ERROR level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed
function _M.error(prompt, ...)
    _M.tempLevel = _M.ERROR
    _M.print(prompt, ...)
end

-----------------------------------------------------------------------------------
-- Prints variable contents to debugger at FATAL level with optional prompt
-- @param prompt is an optional prompt printed before the arguments
-- @param ... arguments to be printed
function _M.fatal(prompt, ...)
    _M.tempLevel = _M.FATAL
    _M.print(prompt, ...)
end

-------------------------------------------------------------------------------
-- Prints variable v contents to stdio with optional prompt
-- included for backward compatibility - replaced by print
-- @param prompt is an optional prompt
-- @param v is a variable whose contents are to be printed
-- @param level is the debug level for the message  INFO by default
function _M.printVar(prompt, v, level)
   _M.tempLevel = checkLevel(level)
   _M.print(prompt, v)
end

return _M
