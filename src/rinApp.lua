-------------------------------------------------------------------------------
-- Module manager for L401
-- @module rinApp
-- @author Darren Pearson
-- @author Merrick Heley
-- @author Sean Liddle
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local assert = assert

local _M = {}
_M.running = false

-- Create the rinApp resources

_M.system = require "rinSystem.Pack"
_M.userio = require "IOSocket.Pack"
_M.dbg    = require "rinLibrary.rinDebug"

package.loaded["rinLibrary.rinDebug"] = nil


_M.devices = {}
_M.debugs = {}
_M.dbg.configureDebug(arg[1], true, 'Application')

-- captures input from terminal to change debug level
local function userioCallback(sock)
	local data = sock:receive("*l")
	  
	if data == 'exit' then
	 _M.running = false
	end   
	_M.dbg.configureDebug(data) 
end

-------------------------------------------------------------------------------
-- Called to connect the L401 library to a socket, and establish the timers,
-- streams and other services to run the application
-- @param ip IP address for the socket, "127.1.1.1" used as a default
-- @param port port address for the socket 2222 used as default

function _M.addL401(ip, port)
	
	-- Create the socket
	local ip = ip or "127.1.1.1"
	local port = port or 2222
	
	local dbg = require "rinLibrary.rinDebug"
	local device = require "rinLibrary.L401"
	
    package.loaded["rinLibrary.L401"] = nil
    package.loaded["rinLibrary.rinDebug"] = nil

	_M.devices[#_M.devices+1] = device
	_M.debugs[#_M.debugs+1] = dbg
	
	local s = assert(require "socket".tcp())
	s:connect(ip, port)
	s:settimeout(0.1)
	
	-- set rinDebug level according to the first argument passed to the application
	dbg.configureDebug(arg[1], true, ip)
	
	dbg.printVar(ip, 'L401 Connected: ', dbg.INFO)

	-- Connect to the L401, and attach system if using the system library
	device.connect(s, _M.system)
	-- Register the L401 with system
	_M.system.sockets.addSocket(device.socket, device.socketCallback)
	-- Add a timer to send data every 5ms
	_M.system.timers.addTimer(5, 100, device.sendQueueCallback)
	-- Add a timer for the heartbeat (every 5s)
	_M.system.timers.addTimer(5000, 1000, device.sendMsg, "20110001:", true)

    _M.system.sockets.addSocket(_M.userio.connectDevice(), userioCallback)
	
	device.streamCleanup()	-- Clean up any existing streams on connect
	device.setupKeys()
	device.setupStatus()
	device.configure()
	
	_M.running = true
	
	return device, dbg
end

-------------------------------------------------------------------------------
-- Called to connect the K412 library to a socket, and establish the timers,
-- streams and other services to run the application
-- @param ip IP address for the socket, "127.1.1.1" used as a default
-- @param port port address for the socket 2222 used as default

function _M.addK412(ip, port)
	
	-- Create the socket
	local ip = ip or "127.1.1.1"
	local port = port or 2222
	
	local dbg = require "rinLibrary.rinDebug"
	local device = require "rinLibrary.K412"
	
    package.loaded["rinLibrary.K412"] = nil
    package.loaded["rinLibrary.rinDebug"] = nil

	_M.devices[#_M.devices+1] = device
	_M.debugs[#_M.debugs+1] = dbg
	
	local s = assert(require "socket".tcp())
	s:connect(ip, port)
	s:settimeout(0.1)
	
	-- set rinDebug level according to the first argument passed to the application
	dbg.configureDebug(arg[1], true, ip)
	
	dbg.printVar(ip, 'K412 Connected: ', dbg.INFO)

	-- Connect to the L401, and attach system if using the system library
	device.connect(s, _M.system)
	-- Register the L401 with system
	_M.system.sockets.addSocket(device.socket, device.socketCallback)
	-- Add a timer to send data every 5ms
	_M.system.timers.addTimer(5, 100, device.sendQueueCallback)
	-- Add a timer for the heartbeat (every 5s)
	_M.system.timers.addTimer(5000, 1000, device.sendMsg, "20110001:", true)

    _M.system.sockets.addSocket(_M.userio.connectDevice(), userioCallback)
	
	device.streamCleanup()	-- Clean up any existing streams on connect
	device.setupKeys()
	device.setupStatus()
	device.configure()
	
	_M.running = true
	
	return device, dbg
end
	
-------------------------------------------------------------------------------
-- Called to restore the system to initial state by shutting down services
-- enabled by configure() 
function _M.cleanup()
    for k,v in pairs(_M.devices) do
		v.restoreLcd()
		v.streamCleanup()
		v.endKeys()
		v.delay(50)
	 end 
	_M.dbg.printVar('','------   Application Finished  ------', _M.dbg.INFO)
end

_M.dbg.printVar('------   Application Started   -----','', _M.dbg.INFO)

return _M