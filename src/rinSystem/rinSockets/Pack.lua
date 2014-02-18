-------------------------------------------------------------------------------
-- Offer functions for sockets that are compatible with the app framework
-- @module rinSystem.rinSockets
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}
local dbg = require "rinLibrary.rinDebug"

local table = table
local pairs = pairs

local sockets = {}
local writers = {}

-------------------------------------------------------------------------------
-- Add a socket to the socket list
-- @param sock Socket to add to the list
-- @param callback Callback for the socket
function _M.addSocket(sock, callback)
    sockets[sock] = callback
end

-------------------------------------------------------------------------------
-- Remove a socket from the socket list
-- @param sock Socket to remove from the list
function _M.removeSocket(sock)
    writers[sock] = nil
    sockets[sock] = nil
end

-------------------------------------------------------------------------------
-- Write a message to a socket
-- @param sock Socket to write to
-- @param msg Data to write
function _M.writeSocket(sock, msg)
	local queue = writers[sock]
    if queue == nil then
    	queue = { start=1, finish=0 }
    end

    queue.finish = queue.finish + 1
	queue[queue.finish] = msg
    writers[sock] = queue
end

-------------------------------------------------------------------------------
-- Get a set of sockets that have pending write data
-- @return Set of sockets, nil if there are none
function _M.getReaderSockets()
	local r = {}
	for i, v in pairs(sockets) do
	  	table.insert(r, i)
    end

	if #r == 0 then
    	r = nil
    end
    return r
end

-------------------------------------------------------------------------------
-- Get a set of sockets that can safely be written to
-- @return Set of sockets, nil if there are none
function _M.getWriterSockets()
	local r = {}
	for i, v in pairs(writers) do
    	if v ~= nil then
	    	table.insert(r, i)
        end
    end

	if #r == 0 then
    	r = nil
    end
    return r
end

-------------------------------------------------------------------------------
-- Read a readable socket
-- @param socks A readable socket
function _M.processReadSocket(sock)
    local callback = sockets[sock]
    if callback then
        local call, err = callback(sock)
        if err == "closed" or err == "Transport endpoint is not connected" then
		    _M.removeSocket(sock)
	    end
    end
end

-------------------------------------------------------------------------------
-- Write a writable socket
-- @param socks A writable socket
function _M.processWriteSocket(sock)
    local queue = writers[sock]
    if queue ~= nil then
    	local s = queue.start
    	local msg = queue[s]
        queue[s] = nil
        s = s + 1
        if s > queue.finish then
        	writers[sock] = nil
        else
	        queue.start = s
        end

        local ret, err = sock:send(msg)
        
        if err then
            dbg.warn('FAILED TRANSMIT', msg)
        else
            dbg.debug(sock:getpeername(), '<<<', msg)
        end
        return ret, err
    end
end

return _M
