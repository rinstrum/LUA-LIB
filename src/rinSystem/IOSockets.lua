-------------------------------------------------------------------------------
--- Module that manages IO functions
-- @module rinSystem.IOSockets
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local posix = require "posix"
local io = require "io"
local table = table

local devCon

local _M = {}
_M.socket = devCon		-- Allow for raw communication if necessary

-------------------------------------------------------------------------------
-- Makes an imitation socket from a LUA file descriptor that can be used with
-- select.
-- @param fdin File descriptor to take input from
-- @param fdout File descriptor to send output to
-- @return An imitation socket with the methods getfd, dirty, receive, send, 
-- close
function _M.makeSocket(fdin, fdout)
	local sock  = {}
	local getfd = posix.fileno(fdin)
	
	sock.getfd		= 	function () return getfd  end
	sock.dirty 		= 	function () return false end	
	
	sock.receive	= 	function (self, ...) 
							return io.input(fdin):read(...) 
					 	end
					 	
	sock.send		= 	function (self, ...) 
							return io.output(fdout):write(...) 
						end
						
	sock.close		= 	function (self, ...)
							fdin:close()
							fdout:close()
						end
	
	return sock
end

-------------------------------------------------------------------------------
-- Connects to the user IO
-- @return the connection (not neccessary for use)
function _M.connectDevice()
	if devCon then
		return devCon
	end
	
	devCon = _M.makeSocket(io.stdin, io.stdout)
	_M.socket = devCon
	
	return devCon
end

-------------------------------------------------------------------------------
-- Get a message from the connection
-- @return message
function _M.getMsg()
  -- This routine should be a lot smarter about the reading.  One character at
  -- a time is grossly inefficient.

	local msg
	local buf = {}
	
	while true do	
		local char = devCon:receive(1)
	
		if char == '\n' then
			msg = table.concat(buf)
			buf = {}
			break
		else 
			table.insert(buf, char)
		end
	end 
	
	return msg
end

return _M
