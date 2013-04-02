-------------------------------------------------------------------------------
-- Manages connections to the device
-- @module connection
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local require = require
local assert = assert

local socket = require "socket"

_M.socket = nil   -- must be set to a connected socket for the module to work
_M.echo = false   -- If true all messages are echoed to stdout

-------------------------------------------------------------------------------
-- Configure rinConnection
-- @param socket A LuaSocket connection for the R400
-- @param echo Set to true to echo all messages to stdout
function _M.configureRinConnection(socket, echo)
	_M.socket = socket
	_M.echo = echo or false
end

-------------------------------------------------------------------------------
-- Connect to a device and return the socket
-- @param ip ip to attempt connection on (string format)
-- @param port port to attempt connection on (integer)
-- @param timeout seconds to wait before quitting a blocking wait (integer)
-- @return LuaSocket socket that connection was made on
function _M.connect(ip, port, timeout)
	timeout = timeout or 0.1

	local s = assert(socket.tcp())
	s:connect(ip, port)
	s:settimeout(timeout)
	
	return s
end

-------------------------------------------------------------------------------
-- Disconnect from the R400
function _M.disconnect()
	_M.socket:close()
	_M.socket = nil
end

return _M
