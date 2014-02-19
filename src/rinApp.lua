-------------------------------------------------------------------------------
-- Module manager for L401
-- @module rinApp
-- @author Darren Pearson
-- @author Merrick Heley
-- @author Sean Liddle
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local assert = assert
local string = string
local pairs = pairs
local require = require
local dofile = dofile
local bit32 = require "bit"

local socks = require "rinSystem.rinSockets.Pack"
local ini = require "rinLibrary.rinINI"

local _M = {}
_M.running = false
_M.config = {
         '; level can be DEBUG,INFO,WARN,ERROR,FATAL',
         '; logger can be any of the supported groups - eg console, socket,file',
         '; timestamp controls whether or not timestamps are added to messages, true or false',         
         level = 'INFO',
         timestamp = true,
         logger = 'console',
		 socket = {IP='192.168.1.20', port=2224},
         file = {filename = 'debug.log'}
         }

-- Create the rinApp resources
_M.system = require "rinSystem.Pack"
_M.userio = require "IOSocket.Pack"
_M.dbg    = require "rinLibrary.rinDebug"

package.loaded["rinLibrary.rinDebug"] = nil

_M.devices = {}
_M.config = ini.loadINI('rinApp.ini',_M.config)
_M.dbg.configureDebug(_M.config, 'Application')

-- captures input from terminal to change debug level
local function userioCallback(sock)
    local data = sock:receive("*l")
       
    if data == nil then
        sock.close()
        socks.removeSocket(sock)
    elseif data == 'exit' then
        _M.running = false
    else
        _M.dbg.setLevel(data)
          -- Set the level in all devices connected
        for k,v in pairs(_M.devices) do
                v.dbg.setLevel(_M.dbg.level)
            end
    end  
end

-------------------------------------------------------------------------------
-- Callback function for client connections on the port 2224 socket.
local function socket2224PassthroughCallback(sock)
	local device = _M.devices[1]
	local msg, err = device.recMsg(sock)
    if err then
    	_M.dbg.info("read eror ", err)
    else
    	device.sendRaw(msg) -- write to socket A
    end
end

-------------------------------------------------------------------------------
-- Stream A call back routine to determine if a message should be forwarded or
-- not for a particular socket.
-- @param sock The socket to be written to
-- @param msg The raw message to write
-- @param command  (CMD_*)
-- @param register (REG_*)
-- @param data
-- @param err
-- @return nil for no forwarding or
-- @return a message to be set (which can be modified or not)
local function streamAprocessor(sock, msg, cmd, reg, data, err)
    return msg
end

-------------------------------------------------------------------------------
-- Three callback functions that are called when a new socket connection is
-- established.  These functions should add the socket to the sockets management
-- module and set any required timouts
local function socket2224Callback(newSocket, ip, port)
	_M.system.sockets.addSocket(newSocket, socket2224PassthroughCallback)
    _M.system.sockets.setSocketTimeout(newSocket, 0.010)
    _M.dbg.info('-- new connection on port 2224 from', ip, port)
    socks.addSocketSet("bi", newSocket, streamAprocessor)
end

local function socket2225Callback(newSocket, ip, port)
	_M.system.sockets.addSocket(newSocket, _M.system.sockets.flushReadSocket)
    _M.system.sockets.setSocketTimeout(newSocket, 0.001)
    _M.dbg.info('-- new unidirectional connection on port 2225 from', ip, port)
    socks.addSocketSet("uni", newSocket, nil)
end

local function socket2226Callback(newSocket, ip, port)
	_M.system.sockets.addSocket(newSocket, _M.system.sockets.flushReadSocket)
    _M.system.sockets.setSocketTimeout(newSocket, 0.001)
    _M.dbg.info('-- new connection on port 2226 from', ip, port)
    socks.addSocketSet("uni", newSocket, nil)
    socks.addSocketSet("debug", newSocket, nil)
end

-------------------------------------------------------------------------------
-- Called to connect to the K400 instrument, and establish the timers,
-- streams and other services
-- @param model Software model expected for the instrument (eg "K401")
-- @param ip IP address for the socket, "127.0.0.1" used as a default
-- @param portA port address for the SERA socket (2222 used as default)
-- @param portB port address for the SERB socket (2223 used as default)
-- @return device object for this instrument
function _M.addK400(model, ip, portA, portB)
    
    -- Create the socket
    local ip = ip or "127.0.0.1"
    local portA = portA or 2222
    local portB = portB or 2223
    
    local model = model or ""
    
    local device = require "rinLibrary.K400"
    
    package.loaded["rinLibrary.K400"] = nil

    _M.devices[#_M.devices+1] = device
  
  	local sA = _M.system.sockets.createTCPsocket(ip, portA, 0.010)
    local sB = _M.system.sockets.createTCPsocket(ip, portB, 0.001)
    
    -- Connect to the K400, and attach system if using the system library
    device.connect(model, sA, sB, _M)
   
    -- Register the K400 with system
    _M.system.sockets.addSocket(device.socketA, device.socketACallback)
    _M.system.sockets.addSocket(device.socketB, device.socketBCallback)

    -- Add a timer for the heartbeat (every 5s)
    _M.system.timers.addTimer(5000, 1000, device.sendMsg, "2017032F:10", true)

	-- Create the extra ports
    _M.system.sockets.createServerSocket(2224, socket2224Callback)
    _M.system.sockets.createServerSocket(2225, socket2225Callback)
    _M.system.sockets.createServerSocket(2226, socket2226Callback)

    -- Flush the key presses
    device.sendRegWait(device.CMD_EX, device.REG_FLUSH_KEYS, 0)
    device.streamCleanup()  -- Clean up any existing streams on connect
    device.setupKeys()
    device.setupStatus()
    device.lcdControl('lua')
    device.configure(model)
    return device 
end
   



   
_M.mainLoop = nil

-------------------------------------------------------------------------------
-- called to register application's main loop
-- @param f Mail Loop function to call 
function _M.setMainLoop(f)
   _M.mainLoop = f
end    
    
-------------------------------------------------------------------------------
-- Main rinApp program loop
function _M.run()
    while _M.running do
        if _M.mainLoop then
           _M.mainLoop()
        end   
        _M.system.handleEvents()           -- handleEvents runs the event handlers 
    end  
end

-------------------------------------------------------------------------------
-- Called to restore the system to initial state by shutting down services
-- enabled by configure() 
function _M.cleanup()
    for k,v in pairs(_M.devices) do
        v.restoreLcd()
        v.lcdControl('default')

        v.streamCleanup()
        v.endKeys()
        v.delay(50)
     end 
    _M.dbg.info('','------   Application Finished  ------')
end

_M.running = true
_M.system.sockets.addSocket(_M.userio.connectDevice(), userioCallback)
_M.dbg.info('','------   Application Started   -----')

return _M
