-------------------------------------------------------------------------------
-- Handles setpoints and digital IO
-- @module setpoints
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local bit32 = bit

_M.REG_IO_STATUS    = 0x0051
_M.REG_IO_ENABLE    = 0x0054

_M.REG_SETP_NUM     = 0xA400

_M.REG_SETP_REPEAT  = 0x0020    -- add Repeat to each registers below for each setpoint 0..15
_M.REG_SETP_TYPE    = 0xA401
_M.REG_SETP_OUTPUT  = 0xA402
_M.REG_SETP_LOGIC   = 0xA403
_M.REG_SETP_ALARM   = 0xA404
_M.REG_SETP_NAME    = 0xA40E
_M.REG_SETP_SOURCE  = 0xA406
_M.REG_SETP_TARGET  = 0xA408
_M.REG_SETP_HYS     = 0xA409

_M.LOGIC_HIGH = 0
_M.LOGIC_LOW = 1

_M.ALARM_NONE = 0
_M.ALARM_SINGLE = 1
_M.ALARM_DOUBLE = 2
_M.ALARM_FLASH = 3

_M.GROSS = 0
_M.NET = 1
_M.DISP = 2
_M.ALT_GROSS = 3
_M.ALT_NET = 4
_M.ALT_DISP = 5
_M.PIECE = 6
_M.REG = 7

_M.lastOutputs = 0
_M.lastIOEnable = 0     -- bits set if under LUA control, clear if under instrument control

_M.setp = {}

_M.NUM_SETP = 16
 
 _M.setOutputs   		= _M.preconfigureMsg(_M.REG_IO_STATUS, _M.CMD_WRFINALDEC)
 _M.setOutputEnable    	= _M.preconfigureMsg(_M.REG_IO_ENABLE, _M.CMD_WRFINALDEC)
 
-------------------------------------------------------------------------------
-- turns IO Output on
-- @param IO is output 1..32
function _M.turnOn(IO)
   local curOutputs = bit32.bor(_M.lastOutputs, bit32.lshift(0x0001,(IO-1)))
   if (curOutputs ~= _M.lastOutputs) then
      _M.setOutputs(curOutputs)
      _M.lastOutputs = curOutputs
	  end
    
end

-------------------------------------------------------------------------------
-- turns IO Output off
-- @param IO is output 1..32
function _M.turnOff(IO)
 local curOutputs = bit32.band(_M.lastOutputs,bit32.bnot(bit32.lshift(0x0001,(IO-1))))
 if (curOutputs ~= _M.lastOutputs) then
      _M.setOutputs(curOutputs)
      _M.lastOutputs = curOutputs
	  end
  	  
end

-------------------------------------------------------------------------------
-- sets IO Output under LUA control
-- @param IO is input 1..32
function _M.enableOutput(IO)
   local curIOEnable =  bit32.bor(_M.lastIOEnable, bit32.lshift(0x0001,(IO-1)))
   if (curIOEnable ~= _M.lastIOEnable) then
      _M.setOutputEnable(curIOEnable)
      _M.lastIOEnable = curIOEnable
    end  
    
end

-------------------------------------------------------------------------------
-- sets IO Output under instrument control
-- @param IO is output 1..32
function _M.releaseOutput(IO)
local curIOEnable =  bit32.band(_M.lastIOEnable,bit32.bnot(bit32.lshift(0x0001,(IO-1))))
   if (curIOEnable ~= _M.lastIOEnable) then
      _M.setOutputEnable(curIOEnable)
      _M.lastIOEnable = curIOEnable
    end 
end

-------------------------------------------------------------------------------
-- Private function
local function setpParam(setp,reg,v)
   _M.send(nil, _M.CMD_WRFINALDEC, reg+((setp-1)*_M.REG_SETP_REPEAT), v, "noReply")
end

-------------------------------------------------------------------------------
-- set Target for setpoint
-- @param setp is setpount 1..16
-- @param v is target value
function _M.setpTarget(setp,target)
   setpParam(setp,_M.REG_SETP_TARGET, target)
end

-------------------------------------------------------------------------------
-- set which Output the setpoint controls
-- @param setp is setpount 1..16
-- @param IO is output 1..32
function _M.setpIO(setp, IO)
  setpParam(setp,_M.REG_SETP_OUTPUT, IO)
end

-------------------------------------------------------------------------------
-- set the TYPE of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint type

function _M.setpType(setp, v)
  setpParam(setp,_M.REG_SETP_TYPE, v)
  
end

-------------------------------------------------------------------------------
-- set the Logic for the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint logic type
function _M.setpLogic(setp, v)
  setpParam(setp,_M.REG_SETP_LOGIC, v)
 
end

-------------------------------------------------------------------------------
-- set the Alarm for the setpoint
-- @param setp is setpount 1..16
-- @param v is alarm type
function _M.setpAlarm(setp, v)
 setpParam(setp,_M.REG_SETP_ALARM, v)
end

-------------------------------------------------------------------------------
-- set the Name of the setpoint
-- @param setp is setpount 1..16
-- @param v is setpoint name
function _M.setpName(setp, v)
  setpParam(setp,_M.REG_SETP_NAME, v)
end

-------------------------------------------------------------------------------
-- set the data source of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint source type
function _M.setpSource(setp, v)
  setpParam(setp,_M.REG_SETP_SOURCE, v)
end

-------------------------------------------------------------------------------
-- set the Hysteresis for of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint hysteresis
function _M.setpHys(setp, v)
  setpParam(setp,_M.REG_SETP_HYS, v)
end

-------------------------------------------------------------------------------
-- set the number of Setpoints 
-- @param n is the number of setpoints 0..16
function _M.setNumSetp(n)
  _M.send(nil,_M.CMD_WRFINALDEC,_M.REG_SETP_NUM,n, "noReply")
end

return _M