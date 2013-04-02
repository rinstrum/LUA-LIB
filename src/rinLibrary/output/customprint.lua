-------------------------------------------------------------------------------
-- Handles custom print string output
-- @module customprint
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

-- Custom Print Strings

_M.REG_PRINTPORT		= 0x0317
_M.REG_PRINTTOKENSTR	= 0x004C
_M.REG_REPLYTOKENSTR	= 0x004D

_M.PRINT_SER1A          = 0
_M.PRINT_SER1B          = 1
_M.PRINT_SER2A          = 2
_M.PRINT_SER2B          = 3
_M.REG_PRINTPORT		= 0x0317
_M.curPrintPort         = 0xFF

----------------------------------------------------------------------------------------------------------------
-- Send custom print token string to instrument comms port
-- @param tokenStr  string containing custom print tokens
-- @param comPort - port to use PRINT_SER1A (default) .. PRINT_SER2B
function _M.printCustomTransmit(tokenStr, comPort)
    local comPort = comPort or _M.PRINT_SER1A
	if comPort ~= _M.curPrintPort  then
	    _M.curPrintPort = comPort
		_M.send(nil,_M.CMD.WRFINALHEX, _M.REG_PRINTPORT, comPort, 'noReply')
		_M.send(nil,_M.CMD.EX, _M.REG_SAVESETTING,0)
	end	
    _M.send(nil,_M.CMD_WRFINALHEX, _M.REG_PRINTTOKENSTR, tokenStr, 'noReply')
end

return _M
