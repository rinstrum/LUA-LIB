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

local _M = {}
_M.running = false

-- Create the rinApp resources
_M.system = require "rinSystem.Pack"
_M.userio = require "IOSocket.Pack"
_M.dbg    = require "rinLibrary.rinDebug"
_M.dbgconfig = require "debugConfig"

package.loaded["rinLibrary.rinDebug"] = nil

--"Usage: lua SCRIPTNAME [-- dbgconfig=PATH/TO/FILE]"
local function handleArgs(args)
    
    for i=1,#args do
    
        local mid = string.find(args[i], "=")
        
        if mid == nil then
            -- do nothing, because lua has no continue statement
        elseif "dbgconfig" == string.sub(args[i], 1, mid - 1) then
        
            _M.dbconfig = dofile(string.sub(args[i], mid + 1, #args[i]))
            
            _M.dbg.configureDebug(_M.dbconfig, 'Application')
            _M.dbg.printVar('', _M.dbg.LEVELS[_M.dbg.level])
        end
    end
end

_M.devices = {}
_M.dbg.configureDebug(_M.dbgconfig, 'Application')
handleArgs(arg)

-- captures input from terminal to change debug level
local function userioCallback(sock)
    local data = sock:receive("*l")
       
    if data == nil then
        sock.close()
        socks.removeSocket(sock)
    elseif data == 'exit' then
        _M.running = false
    else
        local level = nil
        
        -- Get the level that corresponds to the text (should be UPPERCASE)
        for k,v in pairs(_M.dbg.LEVELS) do
            if data == v then
                level = k
            end
        end
        
        if level ~= nil then
            -- Set the level in all devices connected
            for k,v in pairs(_M.devices) do
                v.dbg.config.logger:setLevel(level)
            end
            _M.dbg.config.logger:setLevel(level)
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
-- TODO:  Get second socket working 
-- commented out to enable system to run, otherwise get a socket closed error
--    _M.system.sockets.addSocket(device.socketB, device.socketBCallback)

    -- Add a timer to send data every 5ms
    _M.system.timers.addTimer(5, 100, device.sendQueueCallback)
    -- Add a timer for the heartbeat (every 5s)
    _M.system.timers.addTimer(5000, 1000, device.sendMsg, "20110001:", true)

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
    _M.dbg.printVar('------   Application Finished  ------','', _M.dbg.INFO)
end

_M.running = true
_M.system.sockets.addSocket(_M.userio.connectDevice(), userioCallback)
_M.dbg.printVar('------   Application Started   -----', '', _M.dbg.INFO)

return _M