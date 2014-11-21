#!/usr/bin/env lua
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local sockets = require 'rinSystem.rinSockets'
local dbg = require 'rinLibrary.rinDebug'

require "struct"
require "pb"
require "messages"

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
dwi.setKeyCallback('pwr_cancel', rinApp.finish, 'long')
-------------------------------------------------------------------------------

--=============================================================================
-- Create a new socket on port 2224 that allows bidirection communications
-- with an extenal device
--=============================================================================

-------------------------------------------------------------------------------
-- We need somewhere to keep the socket descriptor so we can send messages to it
local bidirectionalSocket = nil

-- Write to the bidirectional socket
-- @param msg The message to write
local function sendMessage(msg)
	if bidirectionalSocket ~= nil and msg ~= nil then
        local s = msg:Serialize()
        local p = struct.pack("I2c0", #s, s)
		sockets.writeSocket(bidirectionalSocket, p)
    end
end

-------------------------------------------------------------------------------
-- Callback function for client connections on the bidirectional socket.
-- @param sock Socket that has something ready to read.
local function bidirectionalFromExternal(sock)
	m, err = sockets.readSocket(sock)
    if err ~= nil then
    	sockets.removeSocket(sock)
        bidirectionalSocket = nil
    else
        local protoMessage = struct.unpack("I2c0", m)
    	local message = protodemo.ToM4223():Parse(protoMessage)
        local resp, send = protodemo.FromM4223(), false

        if message.add_request then
            local addRes = protodemo.AddResult()
            addRes.result = message.add_request.arg1 + message.add_request.arg2
            resp.add_result = addRes
            send = true
        end

        if message.mul_request then
            local mulRes = protodemo.MulResult()
            mulRes.result = message.mul_request.arg1 * message.mul_request.arg2
            resp.mul_result = mulRes
            send = true
        end

        if send then
            sendMessage(resp)
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
sockets.createServerSocket(2224, socketBidirectionalAccept)

-- Set up a timer to periodically send data

--=============================================================================
-- Main Application Loop
--=============================================================================
-- Main Application logic goes here
rinApp.run()                       -- run the application framework
