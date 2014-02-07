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
-- Called to connect to the K400 instrument, and establish the timers,
-- streams and other services
-- @param model Software model expected for the instrument (eg "K401")
-- @param ip IP address for the socket, "127.1.1.1" used as a default
-- @param portA port address for the SERA socket (2222 used as default)
-- @param portB port address for the SERB socket (2223 used as default)
-- @return device object for this instrument
function _M.addK400(model, ip, portA, portB)
    
    -- Create the socket
    local ip = ip or "127.1.1.1"
    local portA = portA or 2222
    local portB = portB or 2223
    
    local model = model or ""
    
    local device = require "rinLibrary.K400"
    
    package.loaded["rinLibrary.K400"] = nil

    _M.devices[#_M.devices+1] = device
  
    local sA = assert(require "socket".tcp())
    sA:connect(ip, portA)
    sA:settimeout(0.1)
    local sB = assert(require "socket".tcp())
    sB:connect(ip, portB)
    sB:settimeout(5.1)
    
    -- Connect to the K400, and attach system if using the system library
    device.connect(model, sA, sB, _M)
   
    -- Register the K400 with system
    _M.system.sockets.addSocket(device.socketA, device.socketACallback)
    _M.system.sockets.addSocket(device.socketB, device.socketBCallback)

    -- Add a timer to send data every 5ms
    _M.system.timers.addTimer(5, 100, device.sendQueueCallback)
    -- Add a timer for the heartbeat (every 5s)
    _M.system.timers.addTimer(5000, 1000, device.sendMsg, "2017032F:10", true)

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
