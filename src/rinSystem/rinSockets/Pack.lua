-------------------------------------------------------------------------------
-- Offer functions for sockets that are compatible with the app framework
-- @module rinlib
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

_M.sockets = {}
_M.socketCallbacks = {}

-------------------------------------------------------------------------------
-- Add a socket to the socket list
-- @param socket Socket to add to the list
function _M.addSocket(sock, callback)
	table.insert(_M.sockets, sock)
	_M.socketCallbacks[sock] = callback
end

-------------------------------------------------------------------------------
-- Run the callback function associated with a socket
-- @param socket Socket whose callback function should be executed.
function _M.socketCallback(sock)
	_M.socketCallbacks[sock](sock)
end

-------------------------------------------------------------------------------
-- Remove a socket from the socket list
-- @param socket Socket to remove from the list
function _M.removeSocket(sock)
	for k,v in pairs(_M.sockets) do
		if v == sock then
			table.remove(_M.sockets, k)
			break
		end
	end
	
	_M.socketCallbacks[sock] = nil
end

return _M