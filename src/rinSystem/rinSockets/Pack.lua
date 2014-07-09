-------------------------------------------------------------------------------
-- Offer functions for sockets that are compatible with the app framework
-- @module rinSystem.rinSockets
-- @author Merrick Heley
-- @author Pauli
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}
local dbg = require "rinLibrary.rinDebug"

local table = table
local pairs = pairs

local sockets = {}
local writers = {}
local sockSet = {}

-- Close down everything socket related
-- Calling this yourself is likely to cause portions of the rinApp application
-- framework to cease correctly functioning.
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.reset()
function _M.reset()
    for k, _ in pairs(sockets) do
        k:close()
    end
    sockets = {}
    writers = {}
    sockSet = {}
end

-------------------------------------------------------------------------------
-- Callback function that ignores incoming data for a read only socket.
-- @param sock The socket to read all available data from
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.flushReadSocket(mySocket)
function _M.flushReadSocket(sock)
	local ch, err, extra = nil, nil, nil
    while err == nil do
		ch, err, extra = sock:receive(10000)
    end
    if err ~= "timeout" then
        _M.removeSocket(sock)
        dbg.info("Socket closed down", ch, err)
    end
end

-------------------------------------------------------------------------------
-- Add a socket to the socket list
-- @param sock Socket to add to the list
-- @param callback Callback for the socket
-- @return a handle to the socket
-- @see removeSocket
-- @usage
-- -- Refer to the 'exernal.lua' example.
--
-- local sockets = require 'rinSystem.rinSockets.Pack'
-- local mySocket
--
-- local function mySocketReader(sock)
--     local m, err = sockets.readSocket(sock)
--     if err ~= nil then
--     	   sockets.removeSocket(sock)
--     else
--     	   lines = split(m)
--         for i = 1, #lines do
--     	       if lines[i] == "ping" then
--         	       sockets.writeSocket(mySocket, "pong\r\n")
--             end
--         end
--     end
-- end
--
-- local function myAccept(sock, ip, port)
--     mySocket = sock
--     sockets.addSocket(sock, mySocketReader)
--     sockets.setSocketTimeout(sock, 0.010)
-- end
--
-- sockets.createServerSocket(666, myAccept)
function _M.addSocket(sock, callback)
    sockets[sock] = callback
    return sock
end

-------------------------------------------------------------------------------
-- Remove a socket from the socket list
-- @param sock Socket to remove from the list
-- @see addSocket
-- @usage
-- -- Refer to the 'exernal.lua' example or to the
-- -- addSocket call above that has a fuller example.
--
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.removeSocket(mySocket)
function _M.removeSocket(sock)
    writers[sock] = nil
    sockets[sock] = nil
    _M.removeAllSocketSet(sock)
end

-------------------------------------------------------------------------------
-- Create a server/listening socket.
-- Generally you'll use createServerSocket to do this for you.
-- @param sock The socket to listen on
-- @param callback The callback that will be invoked when a new connection is established
-- @see createServerSocket
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.listenSocket(mySocket, function(client, ip, port) print('attempt from', ip, port) end)
function _M.listenSocket(sock, callback)
	_M.addSocket(sock, function (s)
    					   -- s and sock are identical here
	                       local client, error = s:accept()
                           if error then
                               dbg.warn('FAILED ACCEPT', error)
	                       elseif client then
    	                       local ip, port = client:getpeername()
                               if callback then
        	                       callback(client, ip, port)
                               end
                           end
    				   end
                )
end

-------------------------------------------------------------------------------
-- Set the socket's timeout threshold
-- @param sock The socket to alter
-- @param timeout The socket's timeout in seconds
-- @see addSocket
-- @usage
-- -- Refer to the 'exernal.lua' example or to the
-- -- addSocket call above that has a fuller example.
--
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.setSocketTimeout(mySocket, 0.1)
function _M.setSocketTimeout(sock, timeout)
	sock:settimeout(timeout)
end

-------------------------------------------------------------------------------
-- Read a message from a socket
-- @param sock Socket to read from
-- @return The message received
-- @see addSocket
-- @see writeSocket
-- @usage
-- -- Refer to the 'exernal.lua' example or to the
-- -- addSocket call above that has a fuller example.
--
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- local m, err = sockets.readSocket(sock)
-- print('message is: ', m)
-- print('error is:', err)
function _M.readSocket(sock)
	local m, err, extra = nil, nil, nil
	m, err, extra = sock:receive(70000)
    if err == nil then
    	return m, nil
    elseif err ~= "timeout" then
        return nil, err
    end
    return extra, nil
end

-------------------------------------------------------------------------------
-- Write a message to a socket
-- @param sock Socket to write to
-- @param msg Data to write
-- @return Length of the send queue
-- @see addSocket
-- @see readSocket
-- @usage
-- -- Refer to the 'exernal.lua' example or to the
-- -- addSocket call above that has a fuller example.
--
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.writeSocket(mySocket, 'hello again')
function _M.writeSocket(sock, msg)
	local queue = writers[sock]
    if queue == nil then
    	queue = { start=1, finish=0 }
    end

    queue.finish = queue.finish + 1
	queue[queue.finish] = msg
    writers[sock] = queue
    return queue.finish
end

-------------------------------------------------------------------------------
-- Get a set of sockets that have pending write data.
-- You don't need to call this, the rinApp application takes care of this.
-- @return Set of sockets, nil if there are none
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- local readers = sockets.getReaderSockets()
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
-- You don't need to call this, the rinApp application takes care of this.
-- @return Set of sockets, nil if there are none
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- local writers = sockets.getWriterSockets()
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
-- You don't need to call this, the rinApp application takes care of this.
-- @param sock A readable socket
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.processReadSocket(mySocket)
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
-- Suppress debug messages to a socket
-- @param sock A socket
-- @local
local function suppressSocketDebug(sock)
    local queue = writers[sock]
    if queue ~= nil then
    	queue.suppress = true
    end
end

-------------------------------------------------------------------------------
-- Write a writable socket
-- You don't need to call this, the rinApp application takes care of this.
-- @param sock A writable socket
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.processWriteSocket(mySocket)
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
        elseif not queue.suppress then
            dbg.debug(sock:getpeername(), '<<<', msg)
        end
        return ret, err
    end
end

-------------------------------------------------------------------------------
-- Create a TCP socket connected to the specified address
-- @param ip IP address for the socket
-- @param port Port address for the socket
-- @param timeout The timeout associated with the socket
-- @return the socket
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- local mySocket = createTCPsocket('1.1.1.1', 666, 0.1)
function _M.createTCPsocket(ip, port, timeout)
    local s = assert(require "socket".tcp())
    s:connect(ip, port)
    _M.setSocketTimeout(s, timeout)
    return s
end

-------------------------------------------------------------------------------
-- Create a new TCP socket and connect to the specified address
-- @param port Port address for the socket
-- @param callback The read callback for the socket
-- @return the socket
-- @return error code
-- @see addSocket
-- @usage
-- -- Refer to the 'exernal.lua' example or to the
-- -- addSocket call above that has a fuller example.
--
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- local function mySocketReader(sock)
--     ...
-- end
--
-- local function myAccept(sock, ip, port)
--     sockets.addSocket(sock, mySocketReader)
--     sockets.setSocketTimeout(sock, 0.010)
-- end
--
-- sockets.createServerSocket(666, myAccept)
function _M.createServerSocket(port, callback)
	local server, err = socket.bind('*', port)
	if server then
    	_M.setSocketTimeout(server, 0)
	    _M.listenSocket(server, callback)
	end
    return server, err
end

-------------------------------------------------------------------------------
-- Add the specified socket into the named socket set.  Optionally supply
-- a callback routine that can filter the packet stream.
-- @param name The name of the socket set
-- @param sock The socket to add
-- @param callback The filter callback.  Pass nil for complete filtering.
-- @param silent If true, suppresses debug output for message on this socket
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- -- The callback function looks like:
-- -- function callback(sock, msg, ...)
-- -- param sock The socket to be written to
-- -- param msg The message to be written
-- -- param ... variable numbers of extra arguments depending on source
-- -- return msg The message that will actually be sent or nil for no message
-- function cb(sock, msg)
--     return msg
-- end
--
-- sockets.addSocketSet('myset', mySocket, cb)
function _M.addSocketSet(name, sock, callback, silent)
	if name == nil or sock == nil then return end
	if sockSet[name] == nil then
    	sockSet[name] = {}
    end
 	sockSet[name][sock] = { cb = callback, supress = silent }
end

-------------------------------------------------------------------------------
-- Remove the specified socket from the named socket set.
-- @param name The name of the socket set
-- @param sock The socket to remove
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.removeSocketSet('myset', mySocket)
function _M.removeSocketSet(name, sock)
	if name == nil or sock == nil or sockSet[name] == nil then return end
	sockSet[name][sock] = nil
end

-------------------------------------------------------------------------------
-- Remove the specified socket from all socket sets.
-- @param sock The socket to remove
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.removeAllSocketSet(mySocket)
function _M.removeAllSocketSet(sock)
	if sock ~= nil then
	    for i, v in pairs(sockSet) do
    	    v[sock] = nil
        end
    end
end

-------------------------------------------------------------------------------
-- Write the specified message to all sockets in the named set.
-- @param name The socket set to write to
-- @param msg The message to write
-- @param ... Optional arguments which will be passed to each call back filter.
-- @usage
-- local sockets = require 'rinSystem.rinSockets.Pack'
--
-- sockets.writeSet('myset', 'hello there')
function _M.writeSet(name, msg, ...)
	if name and msg then
        local s = sockSet[name]
        if s ~= nil then
            for sock, set in pairs(s) do
                local cb = set.cb
    	        if cb ~= nil then
        	        local m = cb(sock, msg, ...)
                    if m ~= nil then
                	    _M.writeSocket(sock, m)
                        if set.supress then
	                        suppressSocketDebug(sock)
                        end
                    end
                end
            end
        end
    end
end

return _M
