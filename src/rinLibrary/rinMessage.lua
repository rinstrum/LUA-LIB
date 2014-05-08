-------------------------------------------------------------------------------
-- Creates a connection to the M4223
-- @module rinLibrary.rincon
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

local rinMsg = {}

-- Addresses control bits
rinMsg.ADDR_RESP            = 0x80
rinMsg.ADDR_ERR             = 0x40
rinMsg.ADDR_REPLY           = 0x20
rinMsg.ADDR_NOREPLY         = 0x00
rinMsg.ADDR_BROADCAST       = 0x00
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
rinMsg.CMD_RDTYPE           = 0x01
rinMsg.CMD_RDRANGEMIN       = 0x02
rinMsg.CMD_RDRANGEMAX       = 0x03
rinMsg.CMD_RDRAW            = 0x04

rinMsg.CMD_RDLIT            = 0x05
rinMsg.CMD_WRRAW            = 0x06
rinMsg.CMD_RDDEFAULT        = 0x07
rinMsg.CMD_RDNAME           = 0x09
rinMsg.CMD_RDITEM           = 0x0D
rinMsg.CMD_RDPERMISSION     = 0x0F

rinMsg.CMD_RDFINALHEX       = 0x11
rinMsg.CMD_RDFINALDEC       = 0x16
rinMsg.CMD_WRFINALHEX       = 0x12
rinMsg.CMD_WRFINALDEC       = 0x17
rinMsg.CMD_EX               = 0x10

-- Register Types
rinMsg.TYP_CHAR             = 0x00
rinMsg.TYP_UCHAR            = 0x01
rinMsg.TYP_SHORT            = 0x02
rinMsg.TYP_USHORT           = 0x03
rinMsg.TYP_LONG             = 0x04
rinMsg.TYP_ULONG            = 0x05
rinMsg.TYP_STRING           = 0x06
rinMsg.TYP_OPTION           = 0x07
rinMsg.TYP_MENU             = 0x08
rinMsg.TYP_WEIGHT           = 0x09
rinMsg.TYP_BLOB             = 0x0A
rinMsg.TYP_EXECUTE          = 0x0B
rinMsg.TYP_BITFIELD         = 0x0C

-- Unused currently
-- rinMsg.typStrings =
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
rinMsg.ERR_UNKNOWN          = 0xC000
rinMsg.ERR_NOTIMPLMN        = 0xA000
rinMsg.ERR_ACCESSDENIED     = 0x9000
rinMsg.ERR_DATAUNDRNG       = 0x8800
rinMsg.ERR_DATAOVRRNG       = 0x8400
rinMsg.ERR_ILLVALUE         = 0x8200
rinMsg.ERR_ILLOP            = 0x8100
rinMsg.ERR_BADPARAM         = 0x8040
rinMsg.ERR_MENUINUSE        = 0x8020
rinMsg.ERR_VIEWMODEREQ      = 0x8010
rinMsg.ERR_CHECKSUMREQ      = 0x8008

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

local function datacrc(s)
    crc = tonum(string.sub(s, -4), 16)
    data = string.sub(s, 1, -5)
end

local msgpat = {
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
}

-------------------------------------------------------------------------------
-- Processes the message and feeds back the individual parts
-- @param msg Message to be processed
-- @param err Error in receive (nil if none)
-- @return address (0x00 to 0x1F)
-- @return command  (CMD_*)
-- @return register (REG_*)
-- @return data (string)
-- @return error (nil if not error, string otherwise)
-- @return excess (string containing left over residue characters)
function rinMsg.processMsg(msg, err)
    if msg == nil and (err == "closed" or "Transport endpoint is not connected") then
        return nil, nil, nil, nil, err, nil
    elseif msg == nil then
        return nil, nil, nil, nil, "msg was nil", nil
    elseif not lpeg.match(msgpat, msg) then
        return nil, nil, nil, nil, "bad message", excess
    elseif delim == "CRC" and ccitt(tocrc) ~= crc then
        return nil, nil, nil, nil, "bad crc", excess
    elseif not (addr and cmd and reg and data) then
        return nil, nil, nil, nil, "non-hex message", excess
    elseif bit32.band(addr, rinMsg.ADDR_ERR) == rinMsg.ADDR_ERR then
        addr = addr % 32
        return addr, cmd, reg, data, errStrings[tonum(data, 16)]
    end
    addr = addr % 32
    return addr, cmd, reg, data, nil, excess
end

-------------------------------------------------------------------------------
-- Formats a message with delimiters added optionally with CRC
-- @param msg  message string to send
-- @param crc  if crc = 'crc' then SOH msg CRC EOT sent, msg CRLF otherwise (default)
-- @return The message wrappered up and ready to send
function rinMsg.encapsulateMsg(msg, crc)
    if crc == 'crc' then
        return table.concat({'\01', msg, str.format("%04X", ccitt(msg)), '\04'})
    else
        return msg .. '\13\10'
    end
end

-------------------------------------------------------------------------------
-- Formats a structured message built up from individual parameters as follows
-- @param addr Indicator address (0x00 to 0x1F)
-- @param cmd Command (CMD_*)
-- @param reg Register (REG_*)
-- @param data Data to be sent
-- @param reply - 'reply' (default) if reply required, sent with ADDR_NOREPLY otherwise
-- @return The formatted message suitable for formatMsg
function rinMsg.buildMsg(addr, cmd, reg, data, reply)
    local addr = addr or rinMsg.ADDR_BROADCAST
    local cmd = cmd or rinMsg.CMD_RDFINALHEX
    local data = data or ""
    local reply = reply or 'reply'

    if reply == 'reply' then
        addr = bit32.bor(addr, rinMsg.ADDR_REPLY)
    end

    if cmd == rinMsg.CMD_WRFINALHEX or cmd == rinMsg.CMD_EX then
        if type(data) == 'number' then
            data = str.format("%X", data)
        end
    end

    return str.format("%02X%02X%04X:%s", addr, cmd, reg, data)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Default Error Handler, logs error to debug at WARN level with error string
-- and received command
-- takes arguments: Address, Command, Register, Data, Err String
-- from message processing
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
function rinMsg.setErrHandler(eh)
    local f = errHandler
    errHandler = eh
    return f
end

-------------------------------------------------------------------------------
-- Removes the error handler
-- @return original registered handler
function rinMsg.removeErrHandler()
    return rinMsg.setErrHandler(nil)
end

-------------------------------------------------------------------------------
-- Error handler which calls currently specified error handling routine.
-- @param addr Address
-- @param cmd Command
-- @param reg Register
-- @param data Data
-- @param e Err String
function rinMsg.handleError(addr, cmd, reg, data, e)
    if errHandler ~= nil then
        errHandler(addr, cmd, reg, data, e)
    end
end

-------------------------------------------------------------------------------
-- Copy all relocated fields to a specified table.  This is for backwards
-- compatibility.
-- @param t Table to add fields to
function rinMsg.copyRelocatedFields(t)
    -- No precompilation of the pattern here, this function is only called
    -- at startup.  It is also usually called but once and at most only a small
    -- number of times.
    local pvar = (P"ADDR" + P"CMD" + P"TYP" + P"ERR") * P"_" * R("AZ", "09")^1
    local pfnc = (P"set" + P"remove") * P"ErrHandler"
    local pat  = (pvar + pfnc) * -1

    for k, v in pairs(rinMsg) do
        if type(k) == "string" and pat:match(k) then
            t[k] = v
        end
    end
end

return rinMsg
