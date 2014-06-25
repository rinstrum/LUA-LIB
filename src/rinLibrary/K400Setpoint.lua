-------------------------------------------------------------------------------
--- Setpoint Functions.
-- Functions to control setpoint outputs
-- @module rinLibrary.K400Setpoint
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local math = math
local bit32 = require "bit"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M)

_M.REG_IO_STATUS    = 0x0051
_M.REG_IO_ENABLE    = 0x0054

_M.REG_SETP_NUM     = 0xA400

-- add Repeat to each registers below for each setpoint 0..15
_M.REG_SETP_REPEAT  = 0x0020
_M.REG_SETP_TYPE    = 0xA401
_M.REG_SETP_OUTPUT  = 0xA402
_M.REG_SETP_LOGIC   = 0xA403
_M.REG_SETP_ALARM   = 0xA404
_M.REG_SETP_NAME    = 0xA40E
_M.REG_SETP_SOURCE  = 0xA406
_M.REG_SETP_HYS     = 0xA409
_M.REG_SETP_SOURCE_REG = 0xA40A

_M.REG_SETP_TIMING  = 0xA410
_M.REG_SETP_RESET   = 0xA411
_M.REG_SETP_PULSE_NUM = 0xA412
_M.REG_SETP_TIMING_DELAY  = 0xA40C
_M.REG_SETP_TIMING_ON     = 0xA40D

-- targets are stored in the product database rather than the setpoint one
_M.REG_SETP_TARGET  = 0xB080  -- add setpoint offset (0..15) for the other 16 setpoint targets

_M.LOGIC_HIGH = 0
_M.LOGIC_LOW = 1

_M.ALARM_NONE = 0
_M.ALARM_SINGLE = 1
_M.ALARM_DOUBLE = 2
_M.ALARM_FLASH = 3

_M.TIMING_LEVEL = 0
_M.TIMING_EDGE  = 1
_M.TIMING_PULSE = 2
_M.TIMING_LATCH = 3

_M.SOURCE_GROSS = 0
_M.SOURCE_NET = 1
_M.SOURCE_DISP = 2
_M.SOURCE_ALT_GROSS = 3
_M.SOURCE_ALT_NET = 4
_M.SOURCE_ALT_DISP = 5
_M.SOURCE_PIECE = 6
_M.SOURCE_REG = 7

_M.TYPE_OFF      = 0
_M.TYPE_ON       = 1
_M.TYPE_OVER     = 2
_M.TYPE_UNDER    = 3
_M.TYPE_COZ      = 4
_M.TYPE_ZERO     = 5
_M.TYPE_NET      = 6
_M.TYPE_MOTION   = 7
_M.TYPE_ERROR    = 8
_M.TYPE_LGC_AND  = 9
_M.TYPE_LGC_OR   = 10
_M.TYPE_LGC_XOR  = 11
_M.TYPE_BUZZER   = 12

local lastOutputs = nil
local timedOutputs = 0   -- keeps track of which IO are already running off timers
-- bits set if under LUA control, clear if under instrument control
local lastIOEnable = nil

_M.NUM_SETP = 16

local function setOutputs(outp)
    if outp ~= lastOutputs then
        _M.sendReg(_M.CMD_WRFINALDEC, _M.REG_IO_STATUS,  outp)
        lastOutputs = outp
    end
end

local function setOutputEnable(en)
    if en ~= lastIOEnable then
        _M.sendReg(_M.CMD_WRFINALDEC, _M.REG_IO_ENABLE, en)
        lastIOEnable = en
    end
end

-------------------------------------------------------------------------------
-- Turns IO Output on
-- @param ... list of IO to turn on 1..32
function _M.turnOn(...)
   if arg.n == 0 then
      return
   end
   local curOutputs = lastOutputs or 0
   for _,v in ipairs(arg) do
     if v < 32 and v > 0 then
        curOutputs = bit32.bor(curOutputs, bit32.lshift(0x0001,(v-1)))
     end
   end

   setOutputs(curOutputs)
end

-------------------------------------------------------------------------------
-- Turns IO Output off
-- @param ... list of IO to turn off 1..32
function _M.turnOff(...)
   if arg.n == 0 then
      return
   end
   local curOutputs = lastOutputs or 0
   for _,v in ipairs(arg) do
     if v < 32 and v > 0 then
        curOutputs = bit32.band(curOutputs, bit32.bnot(bit32.lshift(0x0001,(v-1))))
     end
   end

   setOutputs(curOutputs)
end

-------------------------------------------------------------------------------
-- Turns IO Output on
-- @param IO is output 1..32
-- @param t is time in seconds
function _M.turnOnTimed(IO, t)
  local IOMask =  bit32.lshift(0x0001,(IO-1))
  if bit32.band(timedOutputs, IOMask) == 0 then
      _M.turnOn(IO)
      _M.system.timers.addTimer(0, t,
             function ()
                   timedOutputs = bit32.band(timedOutputs, bit32.bnot(IOMask))
                   _M.turnOff(IO)
             end)
      timedOutputs = bit32.bor(timedOutputs, IOMask)
  else
     _M.dbg.warn('IO Timer overlap: ', IO)
  end
end

-------------------------------------------------------------------------------
-- Sets IO Output under LUA control
-- @param ... list of IO to enable (input 1..32)
-- @usage
-- dwi.enableOutput(1,2,3,4)
-- dwi.turnOn(1)
-- dwi.turnOff(2)
-- dwi.turnOnTimed(3, 0.500)  -- pulse output 3 for 500 milliseconds
-- dwi.releaseOutput(1,2,3,4)

function _M.enableOutput(...)
    local curIOEnable = lastIOEnable or 0

    for i,v in ipairs(arg) do
        v = tonumber(v)
        curIOEnable = bit32.bor(curIOEnable, bit32.lshift(0x0001,(v-1)))
       end

    setOutputEnable(curIOEnable)
end

-------------------------------------------------------------------------------
-- Sets IO Output under instrument control
-- @param ... list of IO to release to the instrument(input 1..32)
-- @usage
-- dwi.enableOutput(1,2,3,4)
-- dwi.turnOn(1)
-- dwi.turnOff(2)
-- dwi.turnOnTimed(3, 0.500)  -- pulse output 3 for 500 milliseconds
-- dwi.releaseOutput(1,2,3,4)
function _M.releaseOutput(...)
    local curIOEnable = lastIOEnable or 0

    for i,v in ipairs(arg) do
        v = tonumber(v)
        curIOEnable = bit32.band(curIOEnable,
                                   bit32.bnot(bit32.lshift(0x0001,(v-1))))
       end

    setOutputEnable(curIOEnable)
end

--------------------------------------------------------------------------------
-- returns actual register address for a particular setpoint parameter
-- @param setp is setpoint 1..16
-- @param reg is REG_SETP_*
-- @return address of this registet for setpoint setp
function _M.setpRegAddress(setp,reg)
  if (setp > _M.NUM_SETP) or (setp < 1) then
     _M.dbg.error('Setpoint Invalid: ', setp)
     return(0)
  elseif reg == _M.REG_SETP_TARGET then
     return (reg+setp-1)
  else
     return (reg+((setp-1)*_M.REG_SETP_REPEAT))
  end
end

--------------------------------------------------------------------------------
-- Private function
local function setpParam(setp,reg,v)
   _M.sendRegWait(_M.CMD_WRFINALDEC, _M.setpRegAddress(setp,reg), v)
end

-------------------------------------------------------------------------------
-- Set the number of Setpoints
-- @param n is the number of setpoints 0..8
function _M.setNumSetp(n)
  _M.sendRegWait(_M.CMD_WRFINALDEC,_M.REG_SETP_NUM,n)
end

-------------------------------------------------------------------------------
-- Set Target for setpoint
-- @param setp Setpoint 1..16
-- @param target Target value
function _M.setpTarget(setp,target)
    _M.sendRegWait(_M.CMD_WRFINALDEC, _M.setpRegAddress(setp,_M.REG_SETP_TARGET), target)
end

-------------------------------------------------------------------------------
-- Set which Output the setpoint controls
-- @param setp is setpount 1..16
-- @param IO is output 1..32, 0 for none
function _M.setpIO(setp, IO)
    setpParam(setp,_M.REG_SETP_OUTPUT, IO)
end

--- Setpoint Types.
--@table Types
-- @field TYPE_OFF
-- @field TYPE_ON
-- @field TYPE_OVER
-- @field TYPE_UNDER
-- @field TYPE_COZ
-- @field TYPE_ZERO
-- @field TYPE_NET
-- @field TYPE_MOTION
-- @field TYPE_ERROR
-- @field TYPE_LGC_AND
-- @field TYPE_LGC_OR
-- @field TYPE_LGC_XOR
-- @field TYPE_BUZZER
-------------------------------------------------------------------------------
-- Set the TYPE of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint type
function _M.setpType(setp, v)
  setpParam(setp,_M.REG_SETP_TYPE, v)
end

-------------------------------------------------------------------------------
-- Set the Logic for the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint logic type (.LOGIC_HIGH, .LOGIC_LOW)
function _M.setpLogic(setp, v)
  setpParam(setp,_M.REG_SETP_LOGIC, v)
end

--- Setpoint Alarms Types.
--@table Alarms
-- @field ALARM_NONE
-- @field ALARM_SINGLE
-- @field ALARM_DOUBLE
-- @field ALARM_FLASH

-------------------------------------------------------------------------------
-- Set the Alarm for the setpoint
-- @param setp is setpount 1..16
-- @param v is alarm type
function _M.setpAlarm(setp, v)
 setpParam(setp,_M.REG_SETP_ALARM, v)
end

-------------------------------------------------------------------------------
-- Set the Name of the setpoint
-- @param setp is setpount 1..16
-- @param v is setpoint name (8 character string)
function _M.setpName(setp, v)
  setpParam(setp,_M.REG_SETP_NAME, v)
end

--- Setpoint Source Types.
--@table Source
-- @field SOURCE_GROSS
-- @field SOURCE_NET
-- @field SOURCE_DISP
-- @field SOURCE_ALT_GROSS
-- @field SOURCE_ALT_NET
-- @field SOURCE_ALT_DISP
-- @field SOURCE_PIECE
-- @field SOURCE_REG
-------------------------------------------------------------------------------
-- Set the data source of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint source type
-- @param reg is register address for setpoints using .SOURCE_REG type source data.
-- For other setpoint source types parameter reg is not required.
function _M.setpSource(setp, v, reg)
  setpParam(setp,_M.REG_SETP_SOURCE, v)
  if (v == _M.SOURCE_REG) and reg then
     setpParam(setp,_M.REG_SETP_SOURCE_REG, reg)
  end
end

-------------------------------------------------------------------------------
-- Set the Hysteresis for of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint hysteresis
function _M.setpHys(setp, v)
  setpParam(setp,_M.REG_SETP_HYS, _M.toPrimary(v))
end


end

