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
