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
local io = io

local socks = require "rinSystem.rinSockets.Pack"
local ini = require "rinLibrary.rinINI"
local usb = require "rinLibrary.rinUSB"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
local function createRinApp()
local _M = {}
_M.running = false
_M.config = {
    '; level can be DEBUG,INFO,WARN,ERROR,FATAL',
    '; logger can be any of the supported groups - eg console or file',
    "; timestamp controls whether or not timestamps are added to messages, 'on' or 'off'",
    level = 'INFO',
    timestamp = 'on',
    logger = 'console',
    socket = {IP='192.168.1.20', port=2224},
    file = {filename = 'debug.log'}
}

-- Create the rinApp resources
_M.system = require "rinSystem.Pack"
_M.userio = require "IOSocket.Pack"
_M.dbg    = require "rinLibrary.rinDebug"

_M.devices = {}
_M.config = ini.loadINI('rinApp.ini',_M.config)
_M.config.level = 'DEBUG'
_M.dbg.configureDebug(_M.config)

usb.depricatedUSBhandlers(_M)

local userTerminalCallback = nil
local bidirectionalSocket = nil

local userMainLoop = nil
local userCleanup = nil

-------------------------------------------------------------------------------
-- Called to register application's callback for keys pressed in the terminal.
-- Nothing is called unless the user hits <Enter>.  The callback function is
-- called with the data entered by the user.  Have the callback return true
-- to indicate that the message has been processed, false otherwise.
-- @param f callback given data entered by user in the terminal screen
-- @usage
-- rinApp.setUserTerminal(function(data) print('received', data) end)
function _M.setUserTerminal(f)
   userTerminalCallback = f
end

-------------------------------------------------------------------------------
-- captures input from terminal to change debug level
-- @param sock Socket to read from
-- @local
local function userioCallback(sock)
    local data = sock:receive("*l")

    if userTerminalCallback then
        if userTerminalCallback(data) then
            return
        end
    end

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
-- Called to connect to the K400 instrument, and establish the timers,
-- streams and other services
-- @param model Software model expected for the instrument (eg "K401")
-- @param ip IP address for the socket, "127.0.0.1" used as a default
-- @param portA port address for the SERA socket (2222 used as default)
-- @param portB port address for the SERB socket (2223 used as default)
-- @return device object for this instrument
-- @usage
-- local rinApp = require "rinApp"
--
-- local device = rinApp.addK400('K401')
-- local otherDevice = rinApp.addK400('K401', '1.1.1.1')
function _M.addK400(model, ip, portA, portB)
    -- Create the socket
    local device = require("rinLibrary.K400")()
    table.insert(_M.devices, device)

    device.ipaddress = ip or "127.0.0.1"
    device.portA = portA or 2222
    device.portB = portB or 2223
    device.model = model or ""

  	local sA = _M.system.sockets.createTCPsocket(device.ipaddress, device.portA, 0.001)
    local sB = _M.system.sockets.createTCPsocket(device.ipaddress, device.portB, 0.001)

    -- Connect to the K400, and attach system if using the system library
    device.connect(device.model, sA, sB, _M)

    -- Register the K400 with system
    _M.system.sockets.addSocket(device.socketA, device.socketACallback)
    _M.system.sockets.addSocket(device.socketB, device.socketBCallback)

    -- Add a timer for the heartbeat (every 5s)
    _M.system.timers.addTimer(5.000, 0, device.sendMsg, "2017032F:10", true)

	-- Create the extra debug port
    _M.system.sockets.createServerSocket(2226, device.socketDebugAcceptCallback)
	_M.dbg.setDebugCallback(function (m) socks.writeSet("debug", m .. "\r\n") end)

    -- Flush the key presses
    device.sendRegWait(device.CMD_EX, device.REG_FLUSH_KEYS, 0)
    device.streamCleanup()  -- Clean up any existing streams on connect
    device.setupKeys()
    device.setupStatus()
    device.lcdControl('lua')
    device.configure(device.model)
    return device
end

-------------------------------------------------------------------------------
-- Write to the bidirectional socket
-- @param msg The message to write
-- @usage
-- rinApp.writeBidirectional('hello world!')
function _M.writeBidirectional(msg)
	if bidirectionalSocket ~= nil then
		_M.system.sockets.writeSocket(bidirectionalSocket, msg)
    end
end

-------------------------------------------------------------------------------
-- Set a call back that receives all incoming bidirectional communication.
-- @param f Call back function, takes one argument which contains the current message.
-- @usage
-- rinApp.setUserBidirectionalCallback(function(m) print('message received', m) end)
function _M.setUserBidirectionalCallback(f)
   _M.userBidirectionalCallback = f
end

-------------------------------------------------------------------------------
-- Callback function for client connections on the bidirectional socket.
-- @param sock Socket that has something ready to read.
-- @local
local function bidirectionalFromExternal(sock)
	local sockets = _M.system.sockets
	m, err = sockets.readSocket(sock)
    if err ~= nil then
    	sockets.removeSocket(sock)
        bidirectionalSocket = nil
    else
    	if _M.userBidirectionalCallback then
            _M.userBidirectionalCallback(m)
        end
    end
end

-------------------------------------------------------------------------------
-- Set a call back that handles incoming bidirectional socket connections.
-- @param f Call back function.
-- @usage
-- function cb(sock, ip, port)
--     print('connection from', ip, port)
-- end
--
-- rinApp.setUserBidirectionalConnectCallback(cb)
function _M.setUserBidirectionalConnectCallback(f)
   _M.userBidirectionalConnectCallback = f
end

-------------------------------------------------------------------------------
-- Three callback functions that are called when a new socket connection is
-- established.  These functions should add the socket to the sockets management
-- module and set any required timouts
-- @param sock Incoming connecting socket
-- @param ip Source IP address
-- @param port Source port number
-- @local
local function socketBidirectionalAccept(sock, ip, port)
	if bidirectionalSocket ~= nil then
        _M.dbg.info('second bidirectional connection from', ip, port)
    else
	    bidirectionalSocket = sock
	    local sockets = _M.system.sockets
	    sockets.addSocket(sock, bidirectionalFromExternal)
        sockets.setSocketTimeout(sock, 0.001)
        _M.dbg.debug('bidirectional connection from', ip, port)
        if _M.userBidirectionalConnectCallback then
            _M.userBidirectionalConnectCallback(sock, ip, port)
        end
    end
end

-------------------------------------------------------------------------------
-- Filter function on the outgoing data.
-- It is important to note that this function is called for things you
-- write to the socket set as well as system messages.
-- @param sock The socket in question (you'll usually ignore this)
-- @param msg The message to be filtered
-- @return The message to be sent or nil for no message
-- @local
local function unidirectionFilter(sock, msg)
    return nil
end

-------------------------------------------------------------------------------
-- Callback when a new connection is incoming the unidirection data stream.
-- @param sock The newly connected socket
-- @param ip The source IP address of the socket
-- @param port The source port of the socket
-- @local
local function socketUnidirectionalAccept(sock, ip, port)
	local sockets = _M.system.sockets
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
-- Called to register application's main loop function
-- @param f Mail Loop function to call
-- @usage
-- local function mainLoop()
--     ...
-- end
--
-- rinApp.setMainLoop(mainLoop)
function _M.setMainLoop(f)
   userMainLoop = f
end

-------------------------------------------------------------------------------
-- Called to register application's cleanup function
-- @param f cleanup function to call
-- @usage
-- local function cleanUp()
--     ...
-- end
--
-- rinApp.setCleanup(cleanUp)
function _M.setCleanup(f)
   userCleanup = f
end

-------------------------------------------------------------------------------
-- Initialise rinApp and all connected devices.
-- This function is generally called automatically by the run procedure.
-- @see run
-- @usage
-- rinApp.init()
function _M.init()
    if _M.initialised then
        return
    end
    usb.initUSB()
    for i,v in ipairs(_M.devices) do
        v.init()
    end
    _M.initialised = true
end

-------------------------------------------------------------------------------
-- Called to restore the system to initial state by shutting down services
-- enabled by configure().
-- This function is generally called automatically by the run procedure.
-- @see run
-- @usage
-- rinApp.cleanup()
function _M.cleanup()
    if not _M.initialised then
        return
    end
    if userCleanup then
        userCleanup()
        userCleanup = nil
    end
    userMainLoop = nil

    for _, d in pairs(_M.devices) do
        d.terminate()
    end
    _M.devices = {}
    _M.system.reset()

    _M.initialised = false
    _M.running = true
    _M.dbg.info('','------   Application Finished  ------')
end

-------------------------------------------------------------------------------
-- One iteration of the rinApp main loop.
-- @local
local function step()
    if userMainLoop then
       userMainLoop()
    end
    _M.system.handleEvents()           -- handleEvents runs the event handlers
end
if _TEST then
    _M.step = step
end

-------------------------------------------------------------------------------
-- Main rinApp program loop until the program terminates.
-- @usage
-- rinApp.run()
function _M.run()
    _M.init()
    while _M.running do
        step()
    end
   _M.cleanup()
end


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Create the server and io sockets
io.output():setvbuf('no')
socks.addSocket(_M.userio.connectDevice(), userioCallback)
socks.createServerSocket(2224, socketBidirectionalAccept)
socks.createServerSocket(2225, socketUnidirectionalAccept)
_M.running = true
_M.dbg.info('','------   Application Started %LATEST% -----')
return _M
end

if _TEST then
    return createRinApp
end
return createRinApp()
