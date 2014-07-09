-------------------------------------------------------------------------------
-- Creates a connection to the M4223.
-- Most of the functions here are for internal predominately.
-- It is generally advised that they not be called directly.
-- @module rinLibrary.rinCon
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local sockets = require "rinSystem.rinSockets.Pack"
local timers = require 'rinSystem.rinTimers.Pack'
local bit32 = require "bit"
local rinMsg = require "rinLibrary.rinMessage"
local dbg = require "rinLibrary.rinDebug"

local str = string
local table = table
local tonum = tonumber
local type = type

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, depricated)

_M.socketA = nil   -- must be set to a connected socket for the module to work
_M.socketB = nil   -- must be set to a connected socket for the module to work

local deviceRegisters = {}

local serABuffer = {}

local startChar     = nil
local end1Char      = '\13'
local end2Char      = '\10'
local serBTimeout   = nil
local serBTimer     = nil
local serBBuffer    = {}
local SerBCallback  = nil

local largeSerialBMessageWarning = false  -- Have we warned about an over sized message yet?
local queueClearing = false

rinMsg.copyRelocatedFields(_M)

-------------------------------------------------------------------------------
-- Designed to be registered with rinSystem. If a message error occurs, pass it
-- to the error handler.
--
-- This routine is called by the rinApp application framework.  You don't usually
-- need to call it yourself.
-- @return Message received
-- @return error code or nil if none
-- @usage
-- local msg, err = socketACallback()
function _M.socketACallback()
    -- This routine should be a lot smarter about the reading.  One character at
    -- a time is grossly inefficient.  Read a buffer full, split the packets and
    -- decode each.
    local char, prevchar, err
    while true do
        prevchar = char
        char, err = _M.socketA:receive(1)

        if err then break end

        if char == '\01' then
            serABuffer = {}
        end

        table.insert(serABuffer,char)

        -- Check for delimiters.
        if serABuffer[1] == '\01' then
            if char == '\04' then
                break
            end
        elseif (prevchar == '\r' and char == '\n') or char == ';' then
            break
        end
    end

    if err == nil then
        local msg = table.concat(serABuffer)
        serABuffer = {}
        dbg.debug(_M.socketA:getpeername(), '>>>', msg)
        local addr, cmd, reg, data, e, excess = rinMsg.processMsg(msg, nil)
        if e then
            rinMsg.handleError(addr, cmd, reg, data, e)
            data = nil
        elseif excess ~= nil and excess ~= '' then
            -- since we're reading character at a time and cheching delimiters,
            -- this should never happen but let's be a bit paranoid just in case.
            dbg.warn("excess data after message", excess)
        end
        if deviceRegisters[reg] then
            deviceRegisters[reg](data, e)
        elseif deviceRegisters[0] then
            deviceRegisters[0](data, e)
        end
        return nil,nil

    elseif err == 'timeout' then  -- partial message received
         return nil, nil
    end

    dbg.error("Receive failed: ", err)
    if err == "closed" or err == "Transport endpoint is not connected" then
    	sockets.removeSocket(_M.socketA)
        dbg.fatal("Critical error. Exiting.", err)
        os.exit(1)
    end
    return nil, err
end

-------------------------------------------------------------------------------
-- Disconnect from the R400.
-- This routine is called by the rinApp application framework.  You don't usually
-- need to call it yourself.
-- @usage
-- device.disconnect()
function _M.disconnect()
    _M.socketA:close()
    _M.socketA = nil
    _M.socketB:close()
    _M.socketB = nil
end

-------------------------------------------------------------------------------
-- Flush the output stream and guarantee that all outstanding messages have
-- been written.  This function is safe to call from user applications.
-- @usage
-- device.flush()
function _M.flush()
    if not queueClearing then
        -- There is a queue of messages building up.  Send a mostly harmless
        -- ping to the display and away its response.  This flushes the queue.
        queueClearing = true
        _M.readReg(_M.REG_SERIALNO)
        queueClearing = false
    end
end

-------------------------------------------------------------------------------
-- Sends a raw message to the display.  This message should be a properly
-- and correctly formatted message.
-- @param raw string to send
-- @see send
-- @usage
-- local msg = require 'rinLibrary.rinMessage'
-- local message = msg.buildMsg(addr, cmd, reg, data, reply)
-- device.sendRaw(msg.encapsulateMsg(message), 'crc')
function _M.sendRaw(raw)
    if sockets.writeSocket(_M.socketA, raw) > 5 then
        _M.flush()
    end
end

-------------------------------------------------------------------------------
-- Sends a message with delimiters added optionally with CRC.
-- The message is encapsulated and the checksum added, however the message
-- must be correctly formatted for the display device.
-- @param msg message string to send
-- @param crc if crc = 'crc' then SOH msg CRC EOT sent, msg CRLF otherwise (default)
-- @usage
-- stream.sendMsg(message, crc)
function _M.sendMsg(msg, crc)
    _M.sendRaw(rinMsg.encapsulateMsg(msg, crc or ''))
end

-------------------------------------------------------------------------------
-- Sends a structured message built up from individual parameters as follows
-- @param addr Indicator address (0x00 to 0x1F)
-- @param cmd Command (CMD_*)
-- @param reg Register
-- @param data Data to be sent
-- @param reply 'reply' (default) if reply required, sent with ADDR_NOREPLY otherwise
-- @param crc 'crc' if message sent with crc, false (default) otherwise
-- @usage
-- stream.send(device.ADDR_BROADCAST, device.CMD_RDLIT, 'grossnet', data, 'reply')
function _M.send(addr, cmd, reg, data, reply, crc)
    local r = private.getRegisterNumber(reg)
    _M.sendMsg(rinMsg.buildMsg(addr, cmd, reg, data, reply), crc)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- This section is for functions associated with binding registers
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

-------------------------------------------------------------------------------
-- Get the binding for a specified device register
-- @param reg register to be checked
-- @return Device register binding
-- @usage
-- local func = device.getDeviceRegister('grossnet')
function _M.getDeviceRegister(reg)
    local r = private.getRegisterNumber(reg)
    return deviceRegisters[r]
end

-------------------------------------------------------------------------------
-- Set up a callback for when data on a specific register is received.
-- This function is safe to call from user applications.
-- @param reg Register to give callback, 0 is used to match anything received that has no other binding
-- @param callback Function to be run when data is received
-- @return previous register binding
-- @usage
-- local curIO = 0
-- local function IOStatusHandler(data, err)
--     curIO = tonumber(data, 16)
-- end
-- device.bindRegister('iostatus', IOStatusHandler)
function _M.bindRegister(reg, callback)
    local r = private.getRegisterNumber(reg)
    local prev = deviceRegisters[r]
    deviceRegisters[r] = callback
    return prev
end

-------------------------------------------------------------------------------
-- Unbind a register
-- This function is safe to call from user applications.
-- @param reg Register to remove callback
-- @return previous register binding
-- @usage
-- device.unbindRegister('iostatus')
function _M.unbindRegister(reg)
    return _M.bindRegister(reg, nil)
end

-------------------------------------------------------------------------------
-- Dispatch the serial B stream to other things
-- @param err returned error code
-- @local
local function serBProcess(err)
    local msg = table.concat(serBBuffer)
    dbg.debug(_M.socketB:getpeername(), '-->', msg, err)
    if SerBCallback then
        SerBCallback(msg, err)
    end
    sockets.writeSet("uni", msg)
    serBBuffer = {}
end

-------------------------------------------------------------------------------
-- Read input from the serial B stream, build up messages and handle start and
-- end characters.
-- This routine is designed to be registered with rinSystem.
-- @return Assembled message
-- @return Error code or nil if no error
-- @usage
-- local msg, err = device.socketBCallback()
function _M.socketBCallback()
    -- This routine should be a lot smarter about the reading.
    -- One character at a time is grossly inefficient.
    local char, prevchar, err
    local msg

    while true do
        prevchar = char
        char, err = _M.socketB:receive(1)
        if err then break end
        if char == startChar then
            serBBuffer = {}
        end
        table.insert(serBBuffer,char)
        if #serBBuffer > 250 then
           if not largeSerialBMessageWarning then
              dbg.warn("Receive SERB:", "Large message -- incorrect message delimiters?")
              largeSerialBMessageWarning = true
           end
           break
        end
        if (end2Char) then
           if (prevchar == end1Char and char == end2Char) then
            break
           end
         elseif (char == end1Char) then
            break
        end
    end

    if err == nil then
        serBProcess()
        if serBTimer then
           timers.removeTimer(serBTimer)
        end
        return nil, nil
    elseif err == 'timeout' then  -- partial message received
        local timeout = serBTimeout or .1

        timers.removeTimer(serBTimer)
        if timeout > 0 then
            serBTimer = timers.addTimer(0, timeout, serBProcess, 'timeout')
        else
            serBTimer = nil
        end
        return nil, nil
    end
    dbg.error("Receive SERB failed: ", err)
    return nil, err
end

-------------------------------------------------------------------------------
-- Set delimiters for messages received from the socket linked to SERB.
-- This function is safe to call from user applications.
-- @param start start character, nil if not used
-- @param end1 first end character, nil if not used
-- @param end2 second end character, nil if not used
-- @param t is a timeout in seconds to return any message received without
-- matching delimiters.  If 0 then partial messages are never returned
-- @usage 
-- device.setDelimiters(nil, '\r', '\n')
function _M.setDelimiters(start, end1, end2, t)
    if type(start) == 'number' then
        start = str.char(start)
    end
    if type(end1) == 'number' then
        end1 = str.char(end1)
    end
    if type(end2) == 'number' then
        end2 = str.char(end2)
    end

    startChar = start
    end1Char = end1
    end2Char = end2
    serBTimeout = tonumber(t)
end

-------------------------------------------------------------------------------
-- Set callback function for the SerB data stream
-- @param f callback function that takes a message string as an argument
-- @usage
-- function serialBCallback(message, error)
--     ...
-- end
-- device.setSerBCallback(serialBCallback)
function _M.setSerBCallback(f)
    SerBCallback = f
end

-------------------------------------------------------------------------------
-- Callback when a new connection is incoming on the external debug stream.
-- This call is handled automatically by the rinApp application framework
-- and should never be called by user code.
-- @param sock The newly connected socket
-- @param ip The source IP address of the socket
-- @param port The source port of the socket
-- @usage
-- local sockets = require "rinSystem.rinSockets.Pack"
--
-- sockets.createServerSocket(1111, device.socketDebugAcceptCallback)
function _M.socketDebugAcceptCallback(sock, ip, port)
	sockets.addSocket(sock, sockets.flushReadSocket)
    sockets.setSocketTimeout(sock, 0.001)
    sockets.addSocketSet("debug", sock, function (s, m) return m end, true)
    dbg.info('debug connection from', ip, port)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the depricated fields
depricated.dbg = dbg

end
