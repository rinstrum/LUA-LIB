-------------------------------------------------------------------------------
-- Creates a connection to the M4223 
-- @module rinLibrary.rincon
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local sockets = require "rinSystem.rinSockets.Pack"
local bit32 = require "bit"
local bxor = bit32.bxor
local floor = math.floor

local str = string
local byte = str.byte
local table = table
local assert = assert
local tonum = tonumber
local pairs = pairs
local type = type
local string = string

local _M = {}
_M.socketA = nil   -- must be set to a connected socket for the module to work
_M.socketB = nil   -- must be set to a connected socket for the module to work

_M.dbg = require "rinLibrary.rinDebug"

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

_M.typStrings = 
{
  [0x00] = "char",
  [0x01] = "unsigned char",
  [0x02] = "short",
  [0x03] = "unsigned short",
  [0x04] = "long",
  [0x05] = "unsigned long",
  [0x06] = "string",
  [0x07] = "option",
  [0x08] = "menu",
  [0x09] = "weight",
  [0x0A] = "blob",
  [0x0B] = "execute",
  [0x0C] = "unknown",
  [0x0D] = "unknown",
  [0x0E] = "unknown",
  [0x0F] = "unknown",
  [0x10] = "unknown" ,
}

--  Errors
_M.ERR_UNKNOWN          = 0xC000
_M.ERR_NOTIMPLMN        = 0xA000
_M.ERR_ACCESSDENIED     = 0x9000
_M.ERR_DATAUNDRNG       = 0x8800
_M.ERR_DATAOVRRNG       = 0x8400
_M.ERR_ILLVALUE         = 0x8200
_M.ERR_ILLOP            = 0x8100
_M.ERR_BADPARAM         = 0x8040
_M.ERR_MENUINUSE        = 0x8020
_M.ERR_VIEWMODEREQ      = 0x8010
_M.ERR_CHECKSUMREQ      = 0x8008

_M.errStrings = 
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

_M.deviceRegisters = {}

-------------------------------------------------------------------------------
-- Default Error Handler, logs error to debug at WARN level with error string 
-- and received command  
-- takes arguments: Address, Command, Register, Data, Err String
-- from message processing 
function _M.defaultErrHandler(addr, cmd, reg, data, s)
  
  local tmps
  
  if addr == nil then
    tmps = str.format("%s (broken message)", s)
  else
    tmps = str.format("%s (%02d%02d%04d:%s)", s, tonum(addr), tonum(cmd), tonum(reg), data) 
  end
   
  _M.dbg.warn('rinCMD Error: ',tmps) 

end

_M.errHandler = _M.defaultErrHandler

-------------------------------------------------------------------------------
-- Set your own routine to handle errors reported from the instrument
-- @param errHandler Function for handling errors, 
-- should take arguments: Address, Command, Register, Data, Err String.
function _M.setErrHandler(errHandler)

    _M.errHandler = errHandler
end

-------------------------------------------------------------------------------
-- Removes the error handler
-- @return original registered handler
function _M.removeErrHandler()
    local f = _M.errHandler
    _M.errHandler = nil
    return f
end

-------------------------------------------------------------------------------
-- Designed to be registered with rinSystem. If a message error occurs, pass it
-- to the error handler.
function _M.socketACallback()
	local msg, e = _M.recMsg(_M.socketA)

    if e == "closed" or e == "Transport endpoint is not connected" then
        _M.dbg.fatal("Critical error. Exiting.", e)
        os.exit(1)
    end

    local addr, cmd, reg, data, err = _M.processMsg(msg, e)
    
    if err then
        if _M.errHandler then
            _M.errHandler(addr, cmd, reg, data, err)
        end
        data = nil
    end
    
    if _M.deviceRegisters[reg] then
        _M.deviceRegisters[reg](data, err)
    elseif _M.deviceRegisters[0] then
        _M.deviceRegisters[0](data, err)
    end
	sockets.writeSet("bi", msg, cmd, reg, data, err)
    
    return data, err
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
-- Receive a rinCMD message from a socket linked to SERA.
-- Receives one byte at a time, and ends the message based on specified 
-- delimiters
-- @param sock A readable socket that has pending data
-- @return A string bounded by delimiters (nil if error)
-- @return An error message (nil if no error)
function _M.recMsg(sock)
    local char, prevchar, err
    local buffer = {}
    local msg

    while true do
        prevchar = char
        char, err = sock:receive(1)

        if err then break end
        
        if char == '\01' then
            buffer = {}
        end

        table.insert(buffer,char)

        -- Check for delimiters.
        if buffer[1] == '\01' then
            if char == '\04' then
                break
            end
        elseif (prevchar == '\r' and char == '\n') or char == ';' then
            break
        end
    end
    
    if err == nil then
        msg = table.concat(buffer)
        _M.dbg.debug(sock:getpeername(), '>>>', msg) 
        return msg, nil
    end
    
    _M.dbg.error("Receive failed: ", err)
    
    if err == "closed" or err == "Transport endpoint is not connected" then
    	sockets.removeSocket(sock)
    end
    
    return nil, err
end

-- -- ---------------------------------------------------------------------------
-- Initialise the CRC-CCITT lookup table for use by the subsequent function
--
-- This table was generated by this C++ fragment:
--
-- 	for (int x=1; x<256; x++) {
-- 		int y = x ^ (x >> 4);
-- 		printf("0x%04x, ", 0xffff & (y<<12) ^ (y<<5) ^ y));
-- 	}
--
local crcTable = {
-- Indicies in comments are in octal, add the row index to the column index.
--    000     001     002     003     004     005     006     007
            0x1021, 0x2042, 0x3063, 0x4084, 0x50A5, 0x60C6, 0x70E7,	-- 000
    0x8108, 0x9129, 0xA14A, 0xB16B, 0xC18C, 0xD1AD, 0xE1CE, 0xF1EF,	-- 010
    0x1231, 0x0210, 0x3273, 0x2252, 0x52B5, 0x4294, 0x72F7, 0x62D6,	-- 020
    0x9339, 0x8318, 0xB37B, 0xA35A, 0xD3BD, 0xC39C, 0xF3FF, 0xE3DE,	-- 030
    0x2462, 0x3443, 0x0420, 0x1401, 0x64E6, 0x74C7, 0x44A4, 0x5485,	-- 040
    0xA56A, 0xB54B, 0x8528, 0x9509, 0xE5EE, 0xF5CF, 0xC5AC, 0xD58D,	-- 050
    0x3653, 0x2672, 0x1611, 0x0630, 0x76D7, 0x66F6, 0x5695, 0x46B4,	-- 060
    0xB75B, 0xA77A, 0x9719, 0x8738, 0xF7DF, 0xE7FE, 0xD79D, 0xC7BC,	-- 070
    0x48C4, 0x58E5, 0x6886, 0x78A7, 0x0840, 0x1861, 0x2802, 0x3823,	-- 100
    0xC9CC, 0xD9ED, 0xE98E, 0xF9AF, 0x8948, 0x9969, 0xA90A, 0xB92B,	-- 110
    0x5AF5, 0x4AD4, 0x7AB7, 0x6A96, 0x1A71, 0x0A50, 0x3A33, 0x2A12,	-- 120
    0xDBFD, 0xCBDC, 0xFBBF, 0xEB9E, 0x9B79, 0x8B58, 0xBB3B, 0xAB1A,	-- 130
    0x6CA6, 0x7C87, 0x4CE4, 0x5CC5, 0x2C22, 0x3C03, 0x0C60, 0x1C41,	-- 140
    0xEDAE, 0xFD8F, 0xCDEC, 0xDDCD, 0xAD2A, 0xBD0B, 0x8D68, 0x9D49,	-- 150
    0x7E97, 0x6EB6, 0x5ED5, 0x4EF4, 0x3E13, 0x2E32, 0x1E51, 0x0E70,	-- 160
    0xFF9F, 0xEFBE, 0xDFDD, 0xCFFC, 0xBF1B, 0xAF3A, 0x9F59, 0x8F78,	-- 170
    0x9188, 0x81A9, 0xB1CA, 0xA1EB, 0xD10C, 0xC12D, 0xF14E, 0xE16F,	-- 200
    0x1080, 0x00A1, 0x30C2, 0x20E3, 0x5004, 0x4025, 0x7046, 0x6067,	-- 210
    0x83B9, 0x9398, 0xA3FB, 0xB3DA, 0xC33D, 0xD31C, 0xE37F, 0xF35E,	-- 220
    0x02B1, 0x1290, 0x22F3, 0x32D2, 0x4235, 0x5214, 0x6277, 0x7256,	-- 230
    0xB5EA, 0xA5CB, 0x95A8, 0x8589, 0xF56E, 0xE54F, 0xD52C, 0xC50D,	-- 240
    0x34E2, 0x24C3, 0x14A0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,	-- 250
    0xA7DB, 0xB7FA, 0x8799, 0x97B8, 0xE75F, 0xF77E, 0xC71D, 0xD73C,	-- 260
    0x26D3, 0x36F2, 0x0691, 0x16B0, 0x6657, 0x7676, 0x4615, 0x5634,	-- 270
    0xD94C, 0xC96D, 0xF90E, 0xE92F, 0x99C8, 0x89E9, 0xB98A, 0xA9AB,	-- 300
    0x5844, 0x4865, 0x7806, 0x6827, 0x18C0, 0x08E1, 0x3882, 0x28A3,	-- 310
    0xCB7D, 0xDB5C, 0xEB3F, 0xFB1E, 0x8BF9, 0x9BD8, 0xABBB, 0xBB9A,	-- 320
    0x4A75, 0x5A54, 0x6A37, 0x7A16, 0x0AF1, 0x1AD0, 0x2AB3, 0x3A92,	-- 330
    0xFD2E, 0xED0F, 0xDD6C, 0xCD4D, 0xBDAA, 0xAD8B, 0x9DE8, 0x8DC9,	-- 340
    0x7C26, 0x6C07, 0x5C64, 0x4C45, 0x3CA2, 0x2C83, 0x1CE0, 0x0CC1,	-- 350
    0xEF1F, 0xFF3E, 0xCF5D, 0xDF7C, 0xAF9B, 0xBFBA, 0x8FD9, 0x9FF8,	-- 360
    0x6E17, 0x7E36, 0x4E55, 0x5E74, 0x2E93, 0x3EB2, 0x0ED1, 0x1EF0 	-- 370
}
crcTable[0] = 0;

-------------------------------------------------------------------------------
-- Creates a CRC-CCITT (0xFFFF) of the given ASCII data
-- @param data Data to be processed
-- @return CRC-CCITT (0xFFFF) of message
--
-- This code is relatively slow.  Further speed gains will require a switch
-- to C which should bump the speed a thousand fold.
function _M.CCITT(data)
    local crc = 0xffff
    local char
    
    for c = 1, #data do
        char = byte(data, c)
        local x = bxor(floor(crc * 0.00390625), char)   -- (crc >> 8) ^ char               producing an eight bit result
        crc = bxor(crc * 256, crcTable[x]) % 65536      -- ((crc << 8) ^ magic) & 0xffff   producing a sixteen bit result
    end
    
    return crc
end

-------------------------------------------------------------------------------
-- Processes the message and feeds back the individual parts
-- @param msg Message to be processed
-- @param err Error in receive (nil if none)
-- @return address (0x00 to 0x1F)
-- @return command  (CMD_*)
-- @return register (REG_*)
-- @return data
-- @return error
function _M.processMsg(msg, err)
    local validDelim = nil
    local newMsg
    local addr, cmd, reg, data
    
    if msg == nil and err == "closed" then
        return nil, nil, nil, nil, err
    end
    
    if msg == nil and err == "Transport endpoint is not connected" then
        return nil, nil, nil, nil, err
    end
    
    if msg == nil then
        return nil, nil, nil, nil, "msg was nil"
    end
    
    if str.sub(msg,1,1) == '\01' then
        if str.sub(msg,-1,-1) == '\04' then
            validDelim = "CRC"
            newMsg = str.sub(msg, 2, -6)    
        end
 
    elseif str.sub(msg, -2, -1) == '\r\n' then
        validDelim = "NORM"
        newMsg = str.sub(msg, 1, -3)
   
    elseif str.sub(msg, -1, -1) == '\r' then
        validDelim = "NORM"
        newMsg = str.sub(msg, 1, -2)
 
    elseif str.sub(msg,-1,-1) == ';' then
        validDelim = "NORM"
        newMsg = str.sub(msg, 1, -2)
    end
  
    if validDelim == nil then 
        return nil, nil, nil, nil, "bad delimiters" 
        
    elseif validDelim == "CRC" 
            and str.sub(msg,-5,-2) == _M.CCITT(newMsg) then
        return nil, nil, nil, nil, "bad crc"
    end
    
    local semiPos = str.find(msg, ':')
    
    if semiPos == nil then
        return nil, nil, nil, nil, "no separator found"
    end
    
    addr = tonum(str.sub(newMsg, 1, 2), 16)
    cmd = tonum(str.sub(newMsg,3,4), 16)
    reg = tonum(str.sub(newMsg, 5, 8), 16)
    data = str.sub(newMsg, semiPos+1, -1)

    if not (addr and cmd and reg and data) then
        return nil, nil, nil, nil, "non-hex msg"
    end
            
    if bit32.band(addr, _M.ADDR_ERR) == _M.ADDR_ERR then
        addr = bit32.band(addr, 0x1F)
        return addr, cmd, reg, data, _M.errStrings[tonum(data,16)] 
    end
    
    addr = bit32.band(addr, 0x1F)
    
    return addr, cmd, reg, data
    
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
    local crc = crc or ''
    
    if crc == 'crc' then
        _M.sendRaw(table.concat({'\01', 
                                    msg, 
                                    str.format("%04X", _M.CCITT(msg)), 
                                    '\04'}))
    else
        _M.sendRaw(table.concat({msg,'\13\10'}))
    end 
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
    local addr = addr or _M.ADDR_BROADCAST
    local cmd = cmd or _M.CMD_RDFINALHEX
    local data = data or ""
    local reply = reply or 'reply'
    if reply == 'reply' then addr = bit32.bor(addr,_M.ADDR_REPLY) end

    if cmd == _M.CMD_WRFINALHEX then
        if type(data) == 'number' then
           data = str.format("%X",data)
        end   
     end 
     
    _M.sendMsg((str.format("%02X%02X%04X:%s", 
                    addr, 
                    cmd, 
                    reg, 
                    data)),crc)
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
-- Set up a callback for when data on a specific register is received
-- @param reg Register to give callback, (REG_*), 0 is used to match anything received that has no other binding
-- @param callback Function to be run when data is received
function _M.bindRegister(reg, callback)
    _M.deviceRegisters[reg] = callback
end

-------------------------------------------------------------------------------
-- Unbind a register
-- @param reg Register to remove callback, (REG_*)
function _M.unbindRegister(reg)
    _M.deviceRegisters[reg] = nil
end

_M.start = nil
_M.end1 = '\13'
_M.end2 = '\10'

-------------------------------------------------------------------------------
-- Designed to be registered with rinSystem. 
function _M.socketBCallback()

    local char, prevchar, err
    local buffer = {}
    local msg

    while true do
        prevchar = char
        char, err = _M.socketB:receive(1)

        if err then break end
        if char == _M.start then
            buffer = {}
        end
        table.insert(buffer,char)
        if #buffer > 50 then
           break
        end   
        if (_M.end2) then
           if (prevchar == _M.end1 and char == _M.end2) then
            break
           end
         elseif (char == _M.end1) then
            break       
        end          
    end
    
    if err == nil or (err == 'timeout' and #buffer > 0) then
        msg = table.concat(buffer)
        _M.dbg.debug(_M.socketB:getpeername(), '-->', msg) 
        if _M.SerBCallback then
            _M.SerBCallback(msg)
        end
        sockets.writeSet("uni", msg)
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
function _M.setDelimiters(start, end1, end2)
   if type(start) == 'number' then
      start = string.char(start)
    end
   if type(end1) == 'number' then
      end1 = string.char(end1)
    end
   if type(end2) == 'number' then
      end2 = string.char(end2)
    end
   _M.start = start
   _M.end1 = end1
   _M.end2 = end2
end

-------------------------------------------------------------------------------
-- Set delimiters for messages received from the socket linked to SERB 
-- E.g. for \r\n delimiting use parameters: nil, '\r', '\n'
-- @param f callback function that takes a message string as an argument
function _M.setSerBCallback(f)
  _M.SerBCallback = f
end
return _M
