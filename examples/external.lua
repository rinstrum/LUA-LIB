-------------------------------------------------------------------------------
-- myApp
-- 
-- Application template
--    
-- Copy this file to your project directory and insert the specific code of 
-- your application
-------------------------------------------------------------------------------
-- Include the src directory
package.path = "/home/src/?.lua;" .. package.path 
-------------------------------------------------------------------------------
local rinApp = require "rinApp"     --  load in the application framework

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
local function pwrCancelPressed(key, state)
    if state == 'long' then
      rinApp.running = false
      return true
    end 
    return false
end
dwi.setKeyCallback(dwi.KEY_PWR_CANCEL, pwrCancelPressed)
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
local function writeBidirectional(msg)
	if bidirectionalSocket ~= nil then
		rinApp.system.sockets.writeSocket(bidirectionalSocket, msg)
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
	local sockets = rinApp.system.sockets

	m, err = sockets.readSocket(sock)
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
        rinApp.dbg.info('second bidirectional connection from', ip, port)
    else
	    bidirectionalSocket = sock
	    local sockets = rinApp.system.sockets

	    sockets.addSocket(sock, bidirectionalFromExternal)
        sockets.setSocketTimeout(sock, 0.010)
        rinApp.dbg.info('bidirectional connection from', ip, port)
    end
end

-------------------------------------------------------------------------------
-- Create the server socket
rinApp.system.sockets.createServerSocket(2224, socketBidirectionalAccept)

--=============================================================================
-- Create a new socket on port 2225 that allows unidirection communications
-- to an extenal device
--=============================================================================

-------------------------------------------------------------------------------
-- Filter function on the outgoing data.
-- @param sock The socket in question (you'll usually ignore this)
-- @param msg The message to be filtered
-- @return The message to be sent or nil for no message
local function unidirectionFilter(sock, msg)
	-- We'll keep all messages that contain a capital G and discard the rest
	if string.find(msg, "G") ~= nil then
    	return msg
    end
    return nil
end

-------------------------------------------------------------------------------
-- Callback when a new connection is incoming the unidirection data stream.
-- @param sock The newly connected socket
-- @param ip The source IP address of the socket
-- @param port The source port of the socket
local function socketUnidirectionalAccept(sock, ip, port)
	local sockets = rinApp.system.sockets

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
    rinApp.dbg.info('unidirectional connection from', ip, port)
end

-------------------------------------------------------------------------------
-- Timer call back that injects extra information into the unidirection sockets
local function unidirectionalTimedMessages()
	rinApp.system.sockets.writeSet("uni", " uni-idle ")
end

-------------------------------------------------------------------------------
-- Create the server socket and timer
rinApp.system.timers.addTimer(1.324, 0.3, unidirectionalTimedMessages)
rinApp.system.sockets.createServerSocket(2225, socketUnidirectionalAccept)

--=============================================================================
-- Main Application Loop
--=============================================================================
-- mainLoop gets continually called by the framework
-- Main Application logic goes here
local function mainLoop()
     
end
rinApp.setMainLoop(mainLoop)       -- register mainLoop with the framework
rinApp.run()                       -- run the application framework

--=============================================================================
-- Clean Up 
--=============================================================================
-- Put any application clean up here

rinApp.cleanup()                   -- shutdown application resources
