-------------------------------------------------------------------------------
-- Creates a connection to the M4223
-- @module rinLibrary.rinMessage
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local bit32  = require "bit"
local lpeg   = require "rinLibrary.lpeg"
local ccitt  = require "rinLibrary.rinCCITT"
local dbg    = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local canon  = naming.canonicalisation
local invert = require('rinSystem.utilities').invert

local string    = string
local table     = table
local tonumber  = tonumber
local type      = type
local C, P, R, S, V = lpeg.C, lpeg.P, lpeg.R, lpeg.S, lpeg.V

local _M = {}

-- Addresses control bits
local ADDR_RESP         = 0x80
local ADDR_ERR          = 0x40
local ADDR_REPLY        = 0x20
local ADDR_NOREPLY      = 0x00
local ADDR_BROADCAST    = 0x00

--- Instrument Commands.
-- @table rinCMD
-- @field rdtype Read Register Type
-- @field rdrangemin Read data range minimum
-- @field rdrangemax Read data range maximum
-- @field rdraw Read Raw data
-- @field rdlit Read literal data
-- @field wrraw Write Raw data
-- @field rddefault Read default setting
-- @field rdname Read Name
-- @field rditem Read Item from item list
-- @field rdpermission Read register permissions
-- @field rdfinalhex Read data in hexadecimal format
-- @field rdfinaldec Read data in decimal format
-- @field wrfinalhex Write data in hexadecimal format
-- @field wrfinaldec Write data in decimal format
-- @field ex Execute with data as execute parameter
local commandMap = {
    rdtype              = 0x01,
    rdrangemin          = 0x02,
    rdrangemax          = 0x03,
    rdraw               = 0x04,

    rdlit               = 0x05,
    wrraw               = 0x06,
    rddefault           = 0x07,
    rdname              = 0x09,
    rditem              = 0x0D,
    rdpermission        = 0x0F,

    rdfinalhex          = 0x11,
    rdfinaldec          = 0x16,
    wrfinalhex          = 0x12,
    wrfinaldec          = 0x17,
    ex                  = 0x10
}
local commandUnmap = invert(commandMap)

--  Errors
local errStrings =
{
    [0xC000] = "Unknown error",
    [0xA000] = "Feature not implemented",
    [0x9000] = "Access denied",
    [0x8800] = "Data under range",
    [0x8400] = "Data over range",
    [0x8200] = "Illegal value",
    [0x8100] = "Illegal operation",
    [0x8040] = "Bad parameter",
    [0x8020] = "Menu in use",
    [0x8010] = "Viewer mode required",
    [0x8008] = "Checksum required"
}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Build a grammer to parse and decode the messages.
local delim, addr, cmd, reg, data, crc, excess, tocrc

-------------------------------------------------------------------------------
-- Extract CRC portion of message string.
-- You should not need to call this directly.  The rinLibrary takes care of this.
-- @param s Message string to decode
-- @local
local function datacrc(s)
    crc = tonumber(string.sub(s, -4), 16)
    data = string.sub(s, 1, -5)
end

-------------------------------------------------------------------------------
-- Extract the command number and convert to a command name
-- You should not need to call this directly.  The rinLibrary takes care of this.
-- @param s Command number as a string or a number
-- @return The command name
-- @local
local function getcmd(s)
    local n = tonumber(s, 16)
    cmd = naming.convertValueToName(n, commandUnmap, n)
    if type(cmd) ~= 'string' then
        dbg.warn('rinMessage:', 'unknown command number '..cmd)
    end
end

local msgpat = P{
              (V"crc" + V"rns" + 1) * (P(1)^0   / function(s) excess = s end),
    crc     = P"\1" * (V"msgcrc" / function(s) delim="CRC"; tocrc = string.sub(s, 1, -5) end) * P"\4",
    msgcrc  = V"header" * ((P(1)-P"\4")^4       / datacrc),
    rns     = V"msgrns" * (P"\r\n" + S"\r\n;")  / function(s) delim = "NORM"      end,
    msgrns  = V"header" * ((P(1)-S"\r\n;")^0    / function(s) data = s            end),
    header  = V"addr" * V"cmd" * V"reg" * V"hd"^0 * P':',
    addr    = V"hd2"                            / function(s) addr = tonumber(s, 16) end,
    cmd     = V"hd2"                            / getcmd,
    reg     = V"hd4"                            / function(s) reg  = tonumber(s, 16) end,
    hd      = R("AF", "09"),     hd2 = V"hd" * V"hd",    hd4 = V"hd2" * V"hd2"
}

-------------------------------------------------------------------------------
-- Processes the message and feeds back the individual parts
-- You should not need to call this directly.  The rinLibrary takes care of this.
-- @param msg Message to be processed
-- @param err Error in receive (nil if none)
-- @return address (0x00 to 0x1F)
-- @return command (CMD_*)
-- @return register (REG_*)
-- @return data (string)
-- @return error (nil if not error, string otherwise)
-- @return excess (string containing left over residue characters)
-- @see encapsulateMsg
-- @usage
-- local msg = require "rinLibrary.rinMessage"
--
-- local addr, cmd, reg, data, err = msg.processMsg(message, nil)
-- if err == nil then
-- ...
-- end
function _M.processMsg(msg, err)
    if msg == nil and (err == "closed" or "Transport endpoint is not connected") then
        return nil, nil, nil, nil, err, nil
    elseif msg == nil then
        return nil, nil, nil, nil, "msg was nil", nil
    elseif not msgpat:match(msg) then
        return nil, nil, nil, nil, "bad message", excess
    elseif delim == "CRC" and ccitt(tocrc) ~= crc then
        return nil, nil, nil, nil, "bad crc", excess
    elseif not (addr and cmd and reg and data) then
        return nil, nil, nil, nil, "non-hex message", excess
    elseif bit32.band(addr, ADDR_ERR) == ADDR_ERR then
        return addr % 32, cmd, reg, data, errStrings[tonumber(data, 16)] or data, excess
    end
    return addr % 32, cmd, reg, data, nil, excess
end

-------------------------------------------------------------------------------
-- Formats a message with delimiters added optionally with CRC
-- You should not need to call this directly.  The rinLibrary takes care of this.
-- @param msg  message string to send
-- @param crc  if crc = 'crc' then SOH msg CRC EOT sent, msg CRLF otherwise (default)
-- @return The message wrappered up and ready to send
-- @see processMsg
-- @usage
-- local msg = require "rinLibrary.rinMessage"
--
-- print('wrappered message without crc:', msg.encapsulateMsg('hello'))
-- print('wrappered message with crc:', msg.encapsulateMsg('goodbye', 'crc'))
function _M.encapsulateMsg(msg, crc)
    if crc == 'crc' then
        return table.concat({'\01', msg, string.format("%04X", ccitt(msg)), '\04'})
    else
        return msg .. '\13\10'
    end
end

-------------------------------------------------------------------------------
-- Formats a structured message built up from individual parameters as follows
-- You should not need to call this directly.  The rinLibrary takes care of this.
-- @param addr Indicator address (0x00 to 0x1F) or 'broadcast'
-- @param cmd Command (string)
-- @param reg Register (numeric)
-- @param data Data to be sent
-- @param reply - 'reply' if reply required (default: reply)
-- @return The formatted message suitable for formatMsg, nil is something is amiss
-- @usage
-- local msg = require "rinLibrary.rinMessage"
--
-- print('message is:', msg.buildMsg(0x01, 0x12, 0x0090, "ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn", 'no reply')
function _M.buildMsg(addr, cmd, reg, data, reply)
    if cmd == nil or reg == nil then
        dbg.error('rinMessage:', 'command or register is not defined')
        return nil
    end

    if type(addr) == 'string' and canon(addr) == 'broadcast' then
        addr = ADDR_BROADCAST
    else
        addr = addr or ADDR_BROADCAST
    end

    if type(cmd) == 'string' then
        cmd = naming.convertNameToValue(cmd, commandMap, commandMap.rdfinalhex)
    end

    if reply == nil or reply == 'reply' then
        addr = bit32.bor(addr, ADDR_REPLY)
    end

    if cmd == commandMap.wrfinalhex or cmd == commandMap.ex then
        if type(data) == 'number' then
            data = string.format("%X", data)
        end
    end

    return string.format("%02X%02X%04X:%s", addr, cmd, reg, data or "")
end

-------------------------------------------------------------------------------
-- Default Error Handler, logs error to debug at WARN level with error string
-- and received command.  The arguments come from the standard message processing
-- decode.
-- @param addr Address
-- @param cmd Command
-- @param reg Register
-- @param data Data
-- @param s Error String
-- @local
local errHandler = function(addr, cmd, reg, data, s)
    local tmps

    if addr == nil then
        tmps = string.format("%s (broken message)", s)
    else
        local function format(x, n)
            local r = tonumber(x)
            if r == nil then
                return string.rep('?', n)
            end
            return string.format('%0'..n..'X', r)
        end

        tmps = string.format("%s (%s%s%s:%s)", s, format(addr, 2), format(cmd, 2), format(reg, 4), data)
    end

    dbg.warn('rinCMD Error: ', tmps)
end

-------------------------------------------------------------------------------
-- Set your own routine to handle errors reported from the instrument.
-- The user error handling function should take arguments:
--      Address, Command, Register, Data, Err String.
-- @param eh Function for handling errors,
-- @return previously registered handler
-- @usage
-- local msg = require "rinLibrary.rinMessage"
--
-- function errorHandler(addr, cmd, reg, data, err)
--     print("error", err)
--     print("to", addr)
--     print("command", cmd)
--     print("for", reg)
--     print("payload", data)
-- end
--
-- local oldErrorHandler = msg.setErrHandler(errorHandler)
-- ...
-- msg.setErrHandler(oldErrorHandler)
function _M.setErrHandler(eh)
    local f = errHandler
    errHandler = eh
    return f
end

-------------------------------------------------------------------------------
-- Removes the error handler
-- @return original registered handler
-- @usage
-- local msg = require "rinLibrary.rinMessage"
--
-- local errorHandler = msg.removeErrHandler()
-- ...
-- msg.setErrHandler(errorHandler)
function _M.removeErrHandler()
    return _M.setErrHandler(nil)
end

-------------------------------------------------------------------------------
-- Error handler which calls currently specified error handling routine.
-- You should not need to call this directly.  The rinLibrary takes care of this.
-- @param addr Address
-- @param cmd Command
-- @param reg Register
-- @param data Data
-- @param e Err String
-- @usage
-- -- Insert an error into the system for processing by the error handler
-- msg = require "rinLibrary.rinMessage"
--
-- msg.handleError(0x01, 0x10, 0x0022, 'hello', 'fatal error')
function _M.handleError(addr, cmd, reg, data, e)
    if errHandler ~= nil then
        errHandler(addr, cmd, reg, data, e)
    end
end

return _M
