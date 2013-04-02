-------------------------------------------------------------------------------
-- handles binding of registers to callbacks
-- @module binding
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

_M.deviceRegisters = {}
_M.errHandler = nil

-------------------------------------------------------------------------------
-- Return a function allowing for repeatable commands
-- @param reg register	(REG_*)
-- @param cmd command	(CMD_*)
-- @param reply - 'reply' (default) if reply required, sent with ADDR_NOREPLY otherwise
-- @param crc - 'crc' if message sent with crc, false (default) otherwise
-- @return preconfigured function
function _M.preconfigureMsg(reg, cmd, reply, crc)
	return function (data) _M.send(nil, cmd, reg, data, reply, crc) end
end

-------------------------------------------------------------------------------
-- Set up a callback for when data on a specific register is received
-- @param reg Register to give callback, (_M.REG_*), 0 is used to match anything received that has no other binding
-- @param callback Function to be run when data is received
function _M.bindRegister(reg, callback)
	_M.deviceRegisters[reg] = callback
end

-------------------------------------------------------------------------------
-- Unbind a register
-- @param reg Register to remove callback, (_M.REG_*)
function _M.unbindRegister(reg)
	_M.deviceRegisters[reg] = nil
end

-------------------------------------------------------------------------------
-- Handles errors that are not register related (e.g. bad CRC, bad delimiters)
-- @param errHandler Function for handling errors, should take one argument.
function _M.setErrHandler(errHandler)
	_M.errHandler = errHandler
end

-------------------------------------------------------------------------------
-- Removes the error handler
function _M.removeErrHandler()
	_M.errHandler = nil
end

return _M