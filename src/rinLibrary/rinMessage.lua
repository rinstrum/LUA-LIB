-------------------------------------------------------------------------------
-- Creates a connection to the M4223
-- @module rinLibrary.rinMessage
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local bit32  = require "bit"
local lpeg   = require "lpeg"
local ccitt  = require "rinLibrary.rinCCITT"
local dbg    = require "rinLibrary.rinDebug"

local str    = string
local table  = table
local tonum  = tonumber
local C, P, R, S, V = lpeg.C, lpeg.P, lpeg.R, lpeg.S, lpeg.V

local _M = {}

-- Addresses control bits
_M.ADDR_RESP            = 0x80
_M.ADDR_ERR             = 0x40
_M.ADDR_REPLY           = 0x20
_M.ADDR_NOREPLY         = 0x00
_M.ADDR_BROADCAST       = 0x00
--- Instrument Commands.
-- @table rinCMD
-- @field CMD_RDTYPE       Read Register Type
-- @field CMD_RDRANGEMIN   Read data range minimum
-- @field CMD_RDRANGEMAX   Read data range maximum
-- @field CMD_RDRAW        Read Raw data
-- @field CMD_RDLIT        Read literal data
-- @field CMD_WRRAW        Write Raw data
-- @field CMD_RDDEFAULT    Read default setting
-- @field CMD_RDNAME       Read Name
-- @field CMD_RDITEM       Read Item from item list
-- @field CMD_RDPERMISSION Read register permissions
-- @field CMD_RDFINALHEX   Read data in hexadecimal format
-- @field CMD_RDFINALDEC   Read data in decimal format
-- @field CMD_WRFINALHEX   Write data in hexadecimal format
-- @field CMD_WRFINALDEC   Write data in decimal format
-- @field CMD_EX           Execute with data as execute parameter

-- Commands
_M.CMD_RDTYPE           = 0x01
_M.CMD_RDRANGEMIN       = 0x02
_M.CMD_RDRANGEMAX       = 0x03
_M.CMD_RDRAW            = 0x04

_M.CMD_RDLIT            = 0x05
_M.CMD_WRRAW            = 0x06
_M.CMD_RDDEFAULT        = 0x07
_M.CMD_RDNAME           = 0x09
_M.CMD_RDITEM           = 0x0D
_M.CMD_RDPERMISSION     = 0x0F

_M.CMD_RDFINALHEX       = 0x11
_M.CMD_RDFINALDEC       = 0x16
_M.CMD_WRFINALHEX       = 0x12
_M.CMD_WRFINALDEC       = 0x17
_M.CMD_EX               = 0x10

-- Register Types
_M.TYP_CHAR             = 0x00
_M.TYP_UCHAR            = 0x01
_M.TYP_SHORT            = 0x02
_M.TYP_USHORT           = 0x03
_M.TYP_LONG             = 0x04
_M.TYP_ULONG            = 0x05
_M.TYP_STRING           = 0x06
_M.TYP_OPTION           = 0x07
_M.TYP_MENU             = 0x08
_M.TYP_WEIGHT           = 0x09
_M.TYP_BLOB             = 0x0A
_M.TYP_EXECUTE          = 0x0B
_M.TYP_BITFIELD         = 0x0C

-- Unused currently
-- _M.typStrings =
-- {
--   [0x00] = "char",
--   [0x01] = "unsigned char",
--   [0x02] = "short",
--   [0x03] = "unsigned short",
--   [0x04] = "long",
--   [0x05] = "unsigned long",
--   [0x06] = "string",
--   [0x07] = "option",
--   [0x08] = "menu",
--   [0x09] = "weight",
--   [0x0A] = "blob",
--   [0x0B] = "execute",
--   [0x0C] = "unknown",
--   [0x0D] = "unknown",
--   [0x0E] = "unknown",
--   [0x0F] = "unknown",
--   [0x10] = "unknown" ,
-- }

--  Errors
local ERR_UNKNOWN          = 0xC000
local ERR_NOTIMPLMN        = 0xA000
local ERR_ACCESSDENIED     = 0x9000
local ERR_DATAUNDRNG       = 0x8800
local ERR_DATAOVRRNG       = 0x8400
local ERR_ILLVALUE         = 0x8200
local ERR_ILLOP            = 0x8100
local ERR_BADPARAM         = 0x8040
local ERR_MENUINUSE        = 0x8020
local ERR_VIEWMODEREQ      = 0x8010
local ERR_CHECKSUMREQ      = 0x8008

local errStrings =
{
    [ERR_UNKNOWN]       = "Unknown error",
    [ERR_NOTIMPLMN]     = "Feature not implemented",
    [ERR_ACCESSDENIED]  = "Access denied",
    [ERR_DATAUNDRNG]    = "Data under range",
    [ERR_DATAOVRRNG]    = "Data over range",
    [ERR_ILLVALUE]      = "Illegal value",
    [ERR_ILLOP]         = "Illegal operation",
    [ERR_BADPARAM]      = "Bad parameter",
    [ERR_MENUINUSE]     = "Menu in use",
    [ERR_VIEWMODEREQ]   = "Viewer mode required",
    [ERR_CHECKSUMREQ]   = "Checksum required"
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
    crc = tonum(string.sub(s, -4), 16)
    data = string.sub(s, 1, -5)
end

local msgpat = P({
              (V"crc" + V"rns" + 1) * (P(1)^0   / function(s) excess = s end),
    crc     = P"\1" * (V"msgcrc" / function(s) delim="CRC"; tocrc = string.sub(s, 1, -5) end) * P"\4",
    msgcrc  = V"header" * ((P(1)-P"\4")^4       / datacrc),
    rns     = V"msgrns" * (P"\r\n" + S"\r\n;")  / function(s) delim = "NORM"      end,
    msgrns  = V"header" * ((P(1)-S"\r\n;")^0    / function(s) data = s            end),
    header  = V"addr" * V"cmd" * V"reg" * V"hd"^0 * P':',
    addr    = V"hd2"                            / function(s) addr = tonum(s, 16) end,
    cmd     = V"hd2"                            / function(s) cmd  = tonum(s, 16) end,
    reg     = V"hd4"                            / function(s) reg  = tonum(s, 16) end,
    hd      = R("AF", "09"),     hd2 = V"hd" * V"hd",    hd4 = V"hd2" * V"hd2"
})

-------------------------------------------------------------------------------
-- Processes the message and feeds back the individual parts
-- You should not need to call this directly.  The rinLibrary takes care of this.
-- @param msg Message to be processed
-- @param err Error in receive (nil if none)
-- @return address (0x00 to 0x1F)
-- @return command  (CMD_*)
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
    elseif bit32.band(addr, _M.ADDR_ERR) == _M.ADDR_ERR then
        return addr % 32, cmd, reg, data, errStrings[tonum(data, 16)], excess
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
        return table.concat({'\01', msg, str.format("%04X", ccitt(msg)), '\04'})
    else
        return msg .. '\13\10'
    end
end

-------------------------------------------------------------------------------
-- Formats a structured message built up from individual parameters as follows
-- You should not need to call this directly.  The rinLibrary takes care of this.
-- @param addr Indicator address (0x00 to 0x1F)
-- @param cmd Command (CMD_*)
-- @param reg Register (REG_*)
-- @param data Data to be sent
-- @param reply - 'reply' (default) if reply required, sent with ADDR_NOREPLY otherwise
-- @return The formatted message suitable for formatMsg
-- @usage
-- local msg = require "rinLibrary.rinMessage"
--
-- print('message is:', msg.buildMsg(0x01, 0x12, 0x0090, "ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn", 'no reply')
function _M.buildMsg(addr, cmd, reg, data, reply)
    local addr = addr or _M.ADDR_BROADCAST
    local cmd = cmd or _M.CMD_RDFINALHEX
    local data = data or ""
    local reply = reply or 'reply'

    if reply == 'reply' then
        addr = bit32.bor(addr, _M.ADDR_REPLY)
    end

    if cmd == _M.CMD_WRFINALHEX or cmd == _M.CMD_EX then
        if type(data) == 'number' then
            data = str.format("%X", data)
        end
    end

    return str.format("%02X%02X%04X:%s", addr, cmd, reg, data)
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
        tmps = str.format("%s (broken message)", s)
    else
        tmps = str.format("%s (%02X%02X%04X:%s)", s, tonum(addr), tonum(cmd), tonum(reg), data)
    end

    dbg.warn('rinCMD Error: ', tmps)
end

-------------------------------------------------------------------------------
-- Set your own routine to handle errors reported from the instrument.
-- The user error handling function should take arguments:
--      Address, Command, Register, Data, Err String.
-- @param errHandler Function for handling errors,
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

-------------------------------------------------------------------------------
-- Copy all relocated fields to a specified table.  This is for backwards
-- compatibility.
-- There is typically no need to call this function directly.  The rinLibrary
-- framework does this on your behalf.
-- @param t Table to add fields to
-- @usage
-- local msg = require "rinLibrary.rinMessage"
--
-- local t = {}
--
-- msg.copyRelocatedFields(t)
function _M.copyRelocatedFields(t)
    -- No precompilation of the pattern here, this function is only called
    -- at startup.  It is also usually called but once and at most only a small
    -- number of times.
    local pat = ((P"ADDR" + P"CMD" + P"TYP" + P"ERR") * P"_" * R("AZ", "09")^1) * -1

    for k, v in pairs(_M) do
        if type(k) == "string" and pat:match(k) then
            t[k] = v
        end
    end
end

return _M
