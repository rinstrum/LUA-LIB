-------------------------------------------------------------------------------
--- Printing Functions.
-- Functions to control instrument printing
-- @module rinLibrary.K400Print
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local bit32 = require "bit"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M)

-- Custom Print Strings

_M.REG_PRINTPORT        = 0xA317
_M.REG_PRINTTOKENSTR    = 0x004C
_M.REG_REPLYTOKENSTR    = 0x004D

_M.PRINT_SER1A          = 0
_M.PRINT_SER1B          = 1
_M.PRINT_SER2A          = 2
_M.PRINT_SER2B          = 3

local curPrintPort      = 0xFF

-------------------------------------------------------------------------------
-- Takes a string s and returns a formatted CustomTransmit string with all 
-- non-printable characters escaped in \xx format
-- @param s  string to convert
-- @return string with all non-printable characters escaped in \xx format
function _M.expandCustomTransmit(s)

  return string.format('%s',string.gsub(s,"[^\32-\126]",      
                        function(x) 
                            return string.format("\\%02X",string.byte(x))
                        end))
end

-------------------------------------------------------------------------------
-- Send custom print token string to instrument comms port
-- @param tokenStr  string containing custom print tokens
-- @param comPort - port to use PRINT_SER1A (default) .. PRINT_SER2B
function _M.printCustomTransmit(tokenStr, comPort)
    local comPort = comPort or _M.PRINT_SER1A
    if comPort ~= curPrintPort  then
        curPrintPort = comPort
        _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_PRINTPORT, comPort)
        _M.sendRegWait(_M.CMD_EX, _M.REG_SAVESETTING,0)
    end 
    tokenStr = _M.expandCustomTransmit(tokenStr)
    _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_PRINTTOKENSTR, tokenStr)
end

-------------------------------------------------------------------------------
-- Called to request response based on custom transmit token string
-- @param tokenStr  custom token string
function _M.reqCustomTransmit(tokenStr)
    s =  _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_REPLYTOKENSTR, '8112004D:'..tokenStr, 1000)
    _M.dbg.printVar(s)
    -- return string.sub(s,10,-1)
    return s
end

end

