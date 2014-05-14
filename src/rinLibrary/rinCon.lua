-------------------------------------------------------------------------------
-- Creates a connection to the M4223
-- @module rinLibrary.rincon
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local sockets = require "rinSystem.rinSockets.Pack"
local bit32 = require "bit"
local rinMsg = require "rinLibrary.rinMessage"

local str = string
local table = table
local tonum = tonumber
local type = type

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M)

_M.socketA = nil   -- must be set to a connected socket for the module to work
_M.socketB = nil   -- must be set to a connected socket for the module to work

_M.dbg = require "rinLibrary.rinDebug"

local deviceRegisters = {}

local serABuffer = {}

local startChar     = nil
local end1Char      = '\13'
local end2Char      = '\10'
local serBTimeout   = 0
local serBTimer     = nil
local serBBuffer    = {}
local SerBCallback  = nil

local largeSerialBMessageWarning = false  -- Have we warned about an over sized message yet?

rinMsg.copyRelocatedFields(_M)

-------------------------------------------------------------------------------
-- Designed to be registered with rinSystem. If a message error occurs, pass it
-- to the error handler.
--
-- This routine should be a lot smarter about the reading.  One character at
-- a time is grossly inefficient.  Read a buffer full, split the packets and
-- decode each.
function _M.socketACallback()
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
        _M.dbg.debug(_M.socketA:getpeername(), '>>>', msg)
        local addr, cmd, reg, data, e, excess = rinMsg.processMsg(msg, nil)
        if e then
            rinMsg.handleError(addr, cmd, reg, data, e)
            data = nil
        elseif excess ~= nil and excess ~= '' then
            -- since we're reading character at a time and cheching delimiters,
            -- this should never happen but let's be a bit paranoid just in case.
            _M.dbg.warn("excess data after message", excess)
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

    _M.dbg.error("Receive failed: ", err)
    if err == "closed" or err == "Transport endpoint is not connected" then
    	sockets.removeSocket(_M.socketA)
        _M.dbg.fatal("Critical error. Exiting.", err)
        os.exit(1)
    end
    return nil, err
end

-------------------------------------------------------------------------------
-- Disconnect from the R400
function _M.disconnect()
    _M.socketA:close()
    _M.socketA = nil
    _M.socketB:close()
    _M.socketB = nil
end

-------------------------------------------------------------------------------
-- Sends a raw message
-- @param raw  string to send
function _M.sendRaw(raw)
   sockets.writeSocket(_M.socketA, raw)
end

-------------------------------------------------------------------------------
-- Sends a message with delimiters added optionally with CRC
-- @param msg  message string to send
-- @param crc  if crc = 'crc' then SOH msg CRC EOT sent, msg CRLF otherwise (default)
function _M.sendMsg(msg, crc)
    _M.sendRaw(rinMsg.encapsulateMsg(msg, crc or ''))
end

-------------------------------------------------------------------------------
-- Sends a structured message built up from individual parameters as follows
-- @param addr Indicator address (0x00 to 0x1F)
-- @param cmd Command (CMD_*)
-- @param reg Register (REG_*)
-- @param data Data to be sent
-- @param reply - 'reply' (default) if reply required, sent with ADDR_NOREPLY otherwise
-- @param crc - 'crc' if message sent with crc, false (default) otherwise
function _M.send(addr, cmd, reg, data, reply, crc)
    _M.sendMsg(rinMsg.buildMsg(addr, cmd, reg, data, reply), crc)
end

-------------------------------------------------------------------------------
-- Return a function allowing for repeatable commands
-- @param reg register  (REG_*)
-- @param cmd command   (CMD_*)
-- @param reply - 'reply' (default) if reply required, sent with ADDR_NOREPLY otherwise
-- @param crc - 'crc' if message sent with crc, false (default) otherwise
-- @return preconfigured function
function _M.preconfigureMsg(reg, cmd, reply, crc)
    return function (data) _M.send(nil, cmd, reg, data, reply, crc) end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- This section is for functions associated with binding registers
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

-------------------------------------------------------------------------------
-- Get the binding for a specified device register
-- @return Device register binding
function _M.getDeviceRegister(r)
    return deviceRegisters[r]
end

-------------------------------------------------------------------------------
-- Set up a callback for when data on a specific register is received
-- @param reg Register to give callback, (REG_*), 0 is used to match anything received that has no other binding
-- @param callback Function to be run when data is received
function _M.bindRegister(reg, callback)
    deviceRegisters[reg] = callback
end

-------------------------------------------------------------------------------
-- Unbind a register
-- @param reg Register to remove callback, (REG_*)
function _M.unbindRegister(reg)
    deviceRegisters[reg] = nil
end

local function serBProcess(err)
    local msg = table.concat(serBBuffer)
    _M.dbg.debug(_M.socketB:getpeername(), '-->', msg, err)
    if SerBCallback then
        SerBCallback(msg,err)
    end
    sockets.writeSet("uni", msg)
    serBBuffer = {}
end
-------------------------------------------------------------------------------
-- Designed to be registered with rinSystem.
--
-- This routine should be a lot smarter about the reading.  One character at
-- a time is grossly inefficient.
function _M.socketBCallback()

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
              _M.dbg.warn("Receive SERB:", "Large message -- incorrect message delimiters?")
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
           _M.system.timers.removeTimer(serBTimer)
        end
        return nil, nil
    elseif err == 'timeout' then  -- partial message received
        _M.system.timers.removeTimer(serBTimer)
        if serBTimeout > 0 then
            serBTimer = _M.system.timers.addTimer(0, serBTimeout, serBProcess,'timeout')
        else
            serBTimer = nil
        end
        return nil, nil
    end
    _M.dbg.error("Receive SERB failed: ", err)
    return nil, err
end


-------------------------------------------------------------------------------
-- Set delimiters for messages received from the socket linked to SERB
-- E.g. for \r\n delimiting use parameters: nil, '\r', '\n'
-- @param start start character, nil if not used
-- @param end1 first end character, nil if not used
-- @param end2 second end character, nil if not used
-- @param t is a timeout in seconds to return any message received without
-- matching delimiters.  If 0 then partial messages are never returned
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
   serBTimeout = tonumber(t) or 0

end

-------------------------------------------------------------------------------
-- Set callback function for the SerB data stream
-- @param f callback function that takes a message string as an argument
-- optional second argument is 'timeout' if message is partial
function _M.setSerBCallback(f)
  SerBCallback = f
end

-------------------------------------------------------------------------------
-- Callback when a new connection is incoming on the external debug stream.
-- @param sock The newly connected socket
-- @param ip The source IP address of the socket
-- @param port The source port of the socket
function _M.socketDebugAcceptCallback(sock, ip, port)
	sockets.addSocket(sock, sockets.flushReadSocket)
    sockets.setSocketTimeout(sock, 0.001)
    sockets.addSocketSet("debug", sock, function (s, m) return m end, true)
    _M.dbg.info('debug connection from', ip, port)
end

end
