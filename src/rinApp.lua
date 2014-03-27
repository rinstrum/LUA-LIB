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
_M.usb = require "devicemounter"
_M.ev_lib = require "ev_lib"
_M.kb_lib = require "kb_lib"
local input = require "linux.input"

_M.devices = {}
_M.config = ini.loadINI('rinApp.ini',_M.config)
_M.dbg.configureDebug(_M.config)


_M.userTerminalCallback = nil


-------------------------------------------------------------------------------
-- called to register application's callback for keys pressed in the terminal.  
-- Nothing is called unless the user hits <Enter>.  The callback function is 
-- called with the data entered by the user.  Have the callback return true
-- to indicate that the message has been processed, false otherwise.  
-- @param f callback given data entered by user in the terminal screen
function _M.setUserTerminal(f)
   _M.userTerminalCallback = f
end    


-- captures input from terminal to change debug level
local function userioCallback(sock)
    local data = sock:receive("*l")

    if _M.userTerminalCallback then
        if _M.userTerminalCallback(data) then return
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

_M.userUSBRegisterCallback = nil
_M.userUSBEventCallback = nil
_M.userUSBKBDCallback = nil

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB device change is detected
-- @param f  Callback function takes event table as a parameter
function _M.setUSBRegisterCallback(f)
   _M.userUSBRegisterCallback = f
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever a USB device change is detected
-- @return current callback
function _M.getUSBRegisterCallback(f)
   return _M.userUSBRegisterCallback
end

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB device event is detected
-- @param f  Callback function takes event table as a parameter
function _M.setUSBEventCallback(f)
   _M.userUSBEventCallback = f
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever a USB device event is detected
-- @return current callback
function _M.getUSBEventCallback()
   return _M.userUSBEventCallback
end

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB Keyboard event is processed
-- @param f  Callback function takes key string as a parameter
function _M.setUSBKBDCallback(f)
   _M.userUSBKBDCallback = f
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever whenever a USB Keyboard event is processed
-- @return current callback
function _M.getUSBKBDCallback()
   return _M.userUSBKBDCallback
end

_M.eventDevices = {}
function _M.eventCallback(sock)
   local ev = _M.ev_lib.getEvent(sock)
   if ev then
      if _M.userUSBEventCallback then
          _M.userUSBEventCallback(ev)
      end    
      local key = _M.kb_lib.getR400Keys(ev)
      if key and _M.userUSBKBDCallback then
            _M.userUSBKBDCallback(key)
      end   
    end      
end

function _M.usbCallback(t)
   _M.dbg.debug('',t)
   for k,v in pairs(t) do
      if v[1] == 'event' then
         if v[2] == 'added' then
            _M.eventDevices[k] = _M.ev_lib.openEvent(k)
            _M.system.sockets.addSocket(_M.eventDevices[k],_M.eventCallback) 
         elseif v[2] == 'removed' and _M.eventDevices[k] ~= nil then
            _M.system.sockets.removeSocket(_M.eventDevices[k])
            _M.eventDevices[k] = nil
         end   
      end    
    end  
   if _M.userUSBRegisterCallback then
      _M.userUSBRegisterCallback(t)
   end   
end

local function usbSockCallback(sock)
   local ret = _M.usb.receiveCallback()
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
  
  	local sA = _M.system.sockets.createTCPsocket(ip, portA, 0.001)
    local sB = _M.system.sockets.createTCPsocket(ip, portB, 0.001)
    
    -- Connect to the K400, and attach system if using the system library
    device.connect(model, sA, sB, _M)
   
    -- Register the K400 with system
    _M.system.sockets.addSocket(device.socketA, device.socketACallback)
    _M.system.sockets.addSocket(device.socketB, device.socketBCallback)

    -- Add a timer for the heartbeat (every 5s)
    _M.system.timers.addTimer(5.000, 0, device.sendMsg, "2017032F:10", true)

	-- Create the extra debug port
    _M.system.sockets.createServerSocket(2226, device.socketDebugAcceptCallback)
	_M.dbg.setDebugCallback(function (m) socks.writeSet("debug", m .. "\n\r") end)

    -- Flush the key presses
    device.sendRegWait(device.CMD_EX, device.REG_FLUSH_KEYS, 0)
    device.streamCleanup()  -- Clean up any existing streams on connect
    device.setupKeys()
    device.setupStatus()
    device.lcdControl('lua')
    device.configure(model)
    return device 
end
   
-------------------------------------------------------------------------------
-- called to initialise the USB port if in use

function _M.initUSB()   
  _M.system.sockets.addSocket(_M.usb.init(),usbSockCallback)
  _M.usb.registerCallback(_M.usbCallback)
  _M.usb.checkDev()  -- call to check if any usb devices already mounted
end
   
_M.userMainLoop = nil
_M.userCleanup = nil

-------------------------------------------------------------------------------
-- called to register application's main loop function
-- @param f Mail Loop function to call 
function _M.setMainLoop(f)
   _M.userMainLoop = f
end    

-------------------------------------------------------------------------------
-- called to register application's cleanup function
-- @param f cleanup function to call 
function _M.setCleanup(f)
   _M.userCleanup = f
end    
    
-------------------------------------------------------------------------------
-- Initialise rinApp and all connected devices
function _M.init()
    if _M.initialised then
        return
    end    
    _M.initUSB()
    for i,v in ipairs(_M.devices) do
        v.init() 
    end
    _M.initialised = true    
end    

-------------------------------------------------------------------------------
-- Called to restore the system to initial state by shutting down services
-- enabled by configure() 
function _M.cleanup()
    if _M.cleanedUp then
        return
    end        
    if _M.userCleanup then
      _M.userCleanup()
    end
    for k,v in pairs(_M.devices) do
        v.restoreLcd()
        v.lcdControl('default')
        v.streamCleanup()
        v.endKeys()
        v.delay(0.050)
     end 
    _M.dbg.info('','------   Application Finished  ------')
    _M.cleanedUp = true
end

-------------------------------------------------------------------------------
-- Main rinApp program loop
function _M.run()
    _M.init()
    while _M.running do
        if _M.userMainLoop then
           _M.userMainLoop()
        end   
        _M.system.handleEvents()           -- handleEvents runs the event handlers 
    end
   _M.cleanup()    
end

io.output():setvbuf('no')
_M.system.sockets.addSocket(_M.userio.connectDevice(), userioCallback)
_M.running = true
_M.dbg.info('','------   Application Started %LATEST% -----')
return _M
