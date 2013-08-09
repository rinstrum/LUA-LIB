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
require "logging.console"

local logger = logging.console("%message\n")

_M.DEBUG 	= logging.DEBUG
_M.INFO 	= logging.INFO
_M.WARN 	= logging.WARN
_M.ERROR 	= logging.ERROR
_M.FATAL 	= logging.FATAL

_M.LEVELS = {}
_M.LEVELS[_M.DEBUG] = 'DEBUG'
_M.LEVELS[_M.INFO]  = 'INFO'
_M.LEVELS[_M.WARN]  = 'WARN'
_M.LEVELS[_M.ERROR] = 'ERROR'
_M.LEVELS[_M.FATAL] = 'FATAL'

_M.useTimestamp = false

_M.ip = nil

-------------------------------------------------------------------------------
-- Configures the level for debugging
-- @param level lualogging level, default is INFO with no timestamp
-- @param timestamp true if logging is to include date/time stamps
function _M.configureDebug(level, timestamp, ip)

     local found = false
     -- try and match level to something meaningful in the logger library 
     for k,v in pairs(_M.LEVELS) do
	    if level == k then
		    found = true
		    break
		end
        if type(level) == "string" and string.find(v,string.upper(level)) then
           level = k
		   found = true
        end
      end		
    if not found then
	    level = _M.INFO
	end	
	_M.useTimestamp = timestamp or found
	logger:setLevel(level)
	if (ip) then
		_M.ip = string.rep(" ", 15-#ip) .. ip
	else
		_M.ip = ""
	end
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
-- @param v is a variable whose contents are to be printed
-- @param name is the name of the variable (optional)
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
	local f = {	fred = 'friend', 
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