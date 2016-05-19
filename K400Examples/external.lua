#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- external
--
-- Example of how to set up sockets for remote connections to this device
-- To see things operating, telnet to port 1111 or 1112.
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers'
local sockets = require 'rinSystem.rinSockets'
local dbg = require 'rinLibrary.rinDebug'

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local device = rinApp.addK400()        --  make a connection to the instrument

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
device.setKeyCallback('pwr_cancel', rinApp.finish, 'long')
-------------------------------------------------------------------------------

--=============================================================================
-- Create a new socket on port 1111 that allows bidirection communications
-- with an extenal device
--=============================================================================

-------------------------------------------------------------------------------
-- We need somewhere to keep the socket descriptor so we can send messages to it
local bidirectionalSocket = nil

-- Write to the bidirectional socket
-- @param msg The message to write
local function writeBidirectional(msg)
	if bidirectionalSocket ~= nil then
		sockets.writeSocket(bidirectionalSocket, msg)
    end
end

-------------------------------------------------------------------------------
-- Helper function to split the read string into separate lines.
-- @param s The string to split
-- @return Table of lines.  Usually with a blank line at the end.
local function split(s)
    local t = {}
    local function helper(line)
    	table.insert(t, line)
        return ""
    end
    helper(s:gsub("(.-)\r?\n", helper))
    return t
end

-------------------------------------------------------------------------------
-- Callback function for client connections on the bidirectional socket.
-- @param sock Socket that has something ready to read.
local function bidirectionalFromExternal(sock)
	local m, err = sockets.readSocket(sock)
    if err ~= nil then
    	sockets.removeSocket(sock)
        bidirectionalSocket = nil
    else
    	lines = split(m)
        for i = 1, #lines do
    	    if lines[i] == "ping" then
        	    writeBidirectional("pong\r\n")
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Three callback functions that are called when a new socket connection is
-- established.  These functions should add the socket to the sockets management
-- module and set any required timouts
local function socketBidirectionalAccept(sock, ip, port)
	if bidirectionalSocket ~= nil then
        dbg.info('second bidirectional connection from', ip, port)
    else
	    bidirectionalSocket = sock

	    sockets.addSocket(sock, bidirectionalFromExternal)
        sockets.setSocketTimeout(sock, 0.010)
        dbg.info('bidirectional connection from', ip, port)
    end
end

-------------------------------------------------------------------------------
-- Create the server socket
sockets.createServerSocket(1111, socketBidirectionalAccept)

--=============================================================================
-- Create a new socket on port 1112 that allows unidirection communications
-- to an extenal device
--=============================================================================

-------------------------------------------------------------------------------
-- Filter function on the outgoing data.
-- @param sock The socket in question (you'll usually ignore this)
-- @param msg The message to be filtered
-- @return The message to be sent or nil for no message
-- It is important to note that this function is called for things you
-- write to the socket set as well as system messages.
local function unidirectionFilter(sock, msg)
	-- We'll keep all messages that contain a capital G and discard the rest
	if string.find(msg, "G") ~= nil then
    	return msg
    end
    -- Allow our own message but we change it to demonstrate message edit
    -- capabilities.
    if msg == "IDLE" then
    	return " uni-idle "
    end
    return nil
end

-------------------------------------------------------------------------------
-- Callback when a new connection is incoming the unidirection data stream.
-- @param sock The newly connected socket
-- @param ip The source IP address of the socket
-- @param port The source port of the socket
local function socketUnidirectionalAccept(sock, ip, port)
	-- Set up so that all incoming traffic is ignored, this stream only
    -- does outgoings.  Failure to do this will cause a build up of incoming
    -- data packets and blockage.
	sockets.addSocket(sock, sockets.flushReadSocket)

	-- Set a brief timeout to prevent things clogging up.
    sockets.setSocketTimeout(sock, 0.001)

	-- Add the socket to the unidirectional broadcast group.  A message
    -- sent here is forwarded to all unidirectional sockets.
    -- We're using an inline filter function that just allows all traffic
    -- through, this function can return nil to prevent a message or something
    -- else to replace a message.
    sockets.addSocketSet("uni", sock, unidirectionFilter)

	-- Finally, log the fact that we've got a new connection
    dbg.info('unidirectional connection from', ip, port)
end

-------------------------------------------------------------------------------
-- Timer call back that injects extra information into the unidirection sockets
local function unidirectionalTimedMessages()
	sockets.writeSet("uni", "IDLE")
end

-------------------------------------------------------------------------------
-- Create the server socket and timer
timers.addTimer(1.324, 0.3, unidirectionalTimedMessages)
sockets.createServerSocket(1112, socketUnidirectionalAccept)

rinApp.run()                       -- run the application framework
