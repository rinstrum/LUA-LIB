-------------------------------------------------------------------------------
-- Handles the streaming protocol
-- @module streaming
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local pairs = pairs
local string = string

local bit32 = require "bit"

--	Stream Register Definitions
_M.REG_STREAMDATA		= 0x0040
_M.REG_STREAMMODE		= 0x0041
_M.REG_STREAMREG1		= 0x0042
_M.REG_STREAMREG2		= 0x0043
_M.REG_STREAMREG3		= 0x0044
_M.REG_STREAMREG4		= 0x0045
_M.REG_STREAMREG5		= 0x0046
_M.REG_LUA				= 0x0300	--NOTE: This should be binary or'd with the other stream registers
_M.STM_START			= 1
_M.STM_STOP				= 0

_M.STM_FREQ_MANUAL		= 0
_M.STM_FREQ_AUTO		= 1
_M.STM_FREQ_AUTO10		= 2
_M.STM_FREQ_AUTO3		= 3
_M.STM_FREQ_AUTO1		= 4
_M.STM_FREQ_ONCHANGE	= 5

_M.freq = _M.STM_FREQ_ONCHANGE

_M.availRegisters = {	[_M.REG_STREAMREG1]= {['reg'] = 0, ['callback'] = nil, ['onChange'] = 'change', ['lastData'] = ''}, 
						[_M.REG_STREAMREG2]= {['reg'] = 0, ['callback'] = nil, ['onChange'] = 'change', ['lastData'] = ''}, 
						[_M.REG_STREAMREG3]= {['reg'] = 0, ['callback'] = nil, ['onChange'] = 'change', ['lastData'] = ''}, 
						[_M.REG_STREAMREG4]= {['reg'] = 0, ['callback'] = nil, ['onChange'] = 'change', ['lastData'] = ''}, 
						[_M.REG_STREAMREG5]= {['reg'] = 0, ['callback'] = nil, ['onChange'] = 'change', ['lastData'] = ''}}
_M.streamRegisters = {}

-------------------------------------------------------------------------------
-- Divide the data stream up and run the relevant callbacks
-- @param data Data received from register
-- @param err Potential error message
function _M.streamCallback(data, err)
	for k,v in pairs(_M.availRegisters) do
		if v.reg ~= 0 then
			local ind = (k - _M.REG_STREAMREG1) * 8
			local substr = string.sub(data,ind+1,ind+8)
			
			if substr and substr ~= "" then			
				if (v.onChange ~= 'change') or (v.lastData ~= substr) then  
                     v.lastData = substr				
				     v.callback(substr, err)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Add a stream to the device (must be connected)
-- @param streamReg Register to stream from (_M.REG_*)
-- @param callback Function to bind to streaming register
-- @param onChange = 'change' (default) to run callback only if data received changed, 'always' otherwise
-- return streamReg returned for convenience to be used to cancel it later if required
function _M.addStream(streamReg, callback, onChange)
	local availReg = nil
	
	_M.bindRegister(bit32.bor(_M.REG_LUA, _M.REG_STREAMDATA), _M.streamCallback)
	
	for k,v in pairs(_M.availRegisters) do
		if v.reg == 0 and (availReg == nil or k < availReg) then
			availReg = k
		end
	end

	if availReg == nil then
		return nil, "no more registers available"
	end
	
	_M.availRegisters[availReg].reg = streamReg
	_M.availRegisters[availReg].callback = callback
	_M.availRegisters[availReg].onChange = onChange
	_M.availRegisters[availReg].lastData = ''
	
	_M.streamRegisters[streamReg] = availReg

	_M.send(nil, _M.CMD_WRFINALHEX, bit32.bor(_M.REG_LUA,_M.REG_STREAMMODE), _M.freq, 'noReply')
	_M.send(nil, _M.CMD_WRFINALDEC, bit32.bor(_M.REG_LUA, availReg), streamReg, 'noReply')
	_M.send(nil, _M.CMD_EX, bit32.bor(_M.REG_LUA, _M.REG_STREAMDATA), _M.STM_START, 'noReply')
	
	return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the device 
-- @param streamReg Register to be removed(_M.REG_*)
function _M.removeStream(streamReg)
	local availReg = _M.streamRegisters[streamReg]

	 if availReg == nil then return end   -- stream already removed
	 
	_M.send(nil, _M.CMD_WRFINALDEC,	bit32.bor(_M.REG_LUA, availReg), 0, 'noReply')
	_M.unbindRegister(bit32.bor(_M.REG_LUA, availReg))
	
	_M.availRegisters[availReg].reg = 0
	_M.streamRegisters[streamReg] = nil
end

-------------------------------------------------------------------------------
-- Called to cleanup any unused streaming
function _M.streamCleanup()
   	for k,v in pairs(_M.availRegisters) do 
		_M.send(nil, _M.CMD_WRFINALDEC,	bit32.bor(_M.REG_LUA, k), 0, 'noReply')
		v.reg = 0
	end
	_M.streamRegisters = {}
end

--  Set the frequency used for streaming
-- @param frequency Frequency of streaming (_M.STM_FREQ_*)
function _M.setStreamFreq(freq)
  local freq = freq or _M.freq
  _M.freq = freq
end

return _M