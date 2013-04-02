-------------------------------------------------------------------------------
-- Handles analogue output
-- @module analogue
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local math = math

_M.REG_ANALOGUE_DATA = 0x0323
_M.REG_ANALOGUE_TYPE = 0xA801
_M.REG_ANALOGUE_CLIP = 0xA806
  
_M.CUR = 0
_M.VOLT = 1

_M.curAnalogType = _M.CUR 
 
_M.writeAnalogRaw   = _M.preconfigureMsg(_M.REG_ANALOG_DATA, _M.CMD_WRFINALDEC, "noReply")
_M.setAnalogClip    = _M.preconfigureMsg(_M.REG_ANALOG_CLIP, _M.CMD_WRFINALDEC, "noReply")

-------------------------------------------------------------------------------
-- Sets the analogue type to either current or voltage
-- @param type _M.CUR or _M.VOLT
function _M.setAnalogType(type)
	local prev = _M.curAnalogType
	
	if type == _M.CUR then
		_M.curAnalogType = _M.CUR
	else
		_M.curAnalogType = _M.VOLT
	end  
	
   if _M.curAnalogType ~= prev then  
		_M.send(nil,_M.CMD_WRFINALDEC,_M.REG_ANALOG_TYPE,_M.curAnalogType,"noReply")
   end
end   

-------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0 through to maximum 1.0
-- @param val = value 0.0 to 1.0
function _M.setAnalogVal(val)
	_M.writeAnalogRaw(math.floor((50000*val)+0.5))
end

 -------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0% through to maximum 100%
-- @param val = value 0 to 100 %
function _M.setAnalogPC(val)
	val = val / 100
	_M.setAnalogVal(val)
end

 -------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0V through to maximum 10.0V
-- @param val = value 0.0 to 10.0
function _M.setAnalogVolt(val)
	_M.setAnalogType(_M.VOLT)
	val = val / 10 
	_M.setAnalogVal(val)
end

 -------------------------------------------------------------------------------
-- Sets the analogue output to minimum 4.0 through to maximum 20.0 mA
-- @param val = value 4.0 to 20.0
function _M.setAnalogCur(val)
	_M.setAnalogType(_M.CUR)
	val = (val - 4)/20
	_M.setAnalogVal(val)
end

return _M