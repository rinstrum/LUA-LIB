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
local timers = require 'rinSystem.rinTimers.Pack'
local dbg = require "rinLibrary.rinDebug"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, depricated)

private.REG_IO_STATUS     = 0x0051
local REG_IO_ENABLE       = 0x0054

local REG_SETP_NUM        = 0xA400

-- add Repeat to each registers below for each setpoint 0..15
local REG_SETP_REPEAT     = 0x0020
local REG_SETP_TYPE       = 0xA401
local REG_SETP_OUTPUT     = 0xA402
local REG_SETP_LOGIC      = 0xA403
local REG_SETP_ALARM      = 0xA404
local REG_SETP_NAME       = 0xA40E
local REG_SETP_SOURCE     = 0xA406
local REG_SETP_HYS        = 0xA409
local REG_SETP_SOURCE_REG = 0xA40A

-- There are no wrapper functions for these five yet.
_M.REG_SETP_TIMING        = 0xA410
_M.REG_SETP_RESET         = 0xA411
_M.REG_SETP_PULSE_NUM     = 0xA412
_M.REG_SETP_TIMING_DELAY  = 0xA40C
_M.REG_SETP_TIMING_ON     = 0xA40D

-- targets are stored in the product database rather than the setpoint one
local REG_SETP_TARGET     = 0xB080  -- add setpoint offset (0..15) for the other 16 setpoint targets

local LOGIC_HIGH = 0
local LOGIC_LOW  = 1

local logicMap = {
    high = LOGIC_HIGH,
    low  = LOGIC_LOW
}

local ALARM_NONE   = 0
local ALARM_SINGLE = 1
local ALARM_DOUBLE = 2
local ALARM_FLASH  = 3

local alarmTypeMap = {
    none = ALARM_NONE,
    single = ALARM_SINGLE,
    double = ALARM_DOUBLE,
    flash = ALARM_FLASH
}

_M.TIMING_LEVEL = 0
_M.TIMING_EDGE  = 1
_M.TIMING_PULSE = 2
_M.TIMING_LATCH = 3

local SOURCE_GROSS      = 0
local SOURCE_NET        = 1
local SOURCE_DISP       = 2
local SOURCE_ALT_GROSS  = 3
local SOURCE_ALT_NET    = 4
local SOURCE_ALT_DISP   = 5
local SOURCE_PIECE      = 6
local SOURCE_REG        = 7

local sourceMap = {
    gross =     SOURCE_GROSS,
    net =       SOURCE_NET,
    disp =      SOURCE_DISP,
    alt_gross = SOURCE_ALT_GROSS,
    alt_net =   SOURCE_ALT_NET,
    alt_disp =  SOURCE_ALT_DISP,
    piece =     SOURCE_PIECE,
    reg =       SOURCE_REG
}

local TYPE_OFF      = 0
local TYPE_ON       = 1
local TYPE_OVER     = 2
local TYPE_UNDER    = 3
local TYPE_COZ      = 4
local TYPE_ZERO     = 5
local TYPE_NET      = 6
local TYPE_MOTION   = 7
local TYPE_ERROR    = 8
local TYPE_LGC_AND  = 9
local TYPE_LGC_OR   = 10
local TYPE_LGC_XOR  = 11
local TYPE_BUZZER   = 12

local typeMap = {
    off =       TYPE_OFF,
    on =        TYPE_ON,
    over =      TYPE_OVER,
    under =     TYPE_UNDER,
    coz =       TYPE_COZ,
    zero =      TYPE_ZERO,
    net =       TYPE_NET,
    motion =    TYPE_MOTION,
    error =     TYPE_ERROR,
    logic_and = TYPE_LGC_AND,
    logic_or =  TYPE_LGC_OR,
    logic_xor = TYPE_LGC_XOR,
    buzzer =    TYPE_BUZZER
}

local lastOutputs = nil
local timedOutputs = 0   -- keeps track of which IO are already running off timers
-- bits set if under LUA control, clear if under instrument control
local lastIOEnable = nil

local NUM_SETP = 16

-------------------------------------------------------------------------------
-- Write the bit mask of the IOs, bits must first be enabled for comms control.
-- @param 32 bit mask of IOs
-- @see setOutputEnable
-- @usage
-- -- set IO3 on
-- setOutputEnable(0x04)
-- setOutputs(0x04)
-- @local
local function setOutputs(outp)
    if outp ~= lastOutputs then
        _M.sendReg(_M.CMD_WRFINALDEC, private.REG_IO_STATUS, outp)
        lastOutputs = outp
    end
end

-------------------------------------------------------------------------------
-- Enable IOs for comms control.
-- @param 32 bit mask of IOs
-- @see setOutputs
-- @usage
-- -- set IO3 on
-- setOutputEnable(0x04)
-- setOutputs(0x04)
-- @local
local function setOutputEnable(en)
    if en ~= lastIOEnable then
        _M.sendReg(_M.CMD_WRFINALDEC, REG_IO_ENABLE, en)
        lastIOEnable = en
    end
end

-------------------------------------------------------------------------------
-- Turns IO Output on.
-- @param ... list of IO to turn on 1..32
-- @see enableOutput
-- @usage
-- -- set IOs 3 and 4 on
-- device.turnOn(3, 4)
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
-- Turns IO Output off.
-- @param ... list of IO to turn off 1..32
-- @see enableOutput
-- @usage
-- -- set IOs 3 and 4 off
-- device.turnOff(3, 4)
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
-- Turns IO Output on for a period of time.
-- @param IO is output 1..32
-- @param t is time in seconds
-- @see enableOutput
-- @usage
-- -- turn IO 1 on for 5 seconds
-- device.turnOnTimed(1, 5)
function _M.turnOnTimed(IO, t)
  local IOMask =  bit32.lshift(0x0001,(IO-1))
  if bit32.band(timedOutputs, IOMask) == 0 then
      _M.turnOn(IO)
      timers.addTimer(0, t,
             function ()
                   timedOutputs = bit32.band(timedOutputs, bit32.bnot(IOMask))
                   _M.turnOff(IO)
             end)
      timedOutputs = bit32.bor(timedOutputs, IOMask)
  else
     dbg.warn('IO Timer overlap: ', IO)
  end
end

-------------------------------------------------------------------------------
-- Sets IO Output under LUA control.
-- @param ... list of IO to enable (input 1..32)
-- @see releaseOutput
-- @usage
-- device.enableOutput(1,2,3,4)
-- device.turnOn(1)
-- device.turnOff(2)
-- device.turnOnTimed(3, 0.500)  -- pulse output 3 for 500 milliseconds
-- device.releaseOutput(1,2,3,4)

function _M.enableOutput(...)
    local curIOEnable = lastIOEnable or 0

    for i,v in ipairs(arg) do
        v = tonumber(v)
        curIOEnable = bit32.bor(curIOEnable, bit32.lshift(0x0001,(v-1)))
       end

    setOutputEnable(curIOEnable)
end

-------------------------------------------------------------------------------
-- Sets IO Output under instrument control.
-- @param ... list of IO to release to the instrument(input 1..32)
-- @see enableOutput
-- @usage
-- device.enableOutput(1, 2, 3, 4)
-- device.turnOn(1)
-- device.turnOff(2)
-- device.turnOnTimed(3, 0.500)  -- pulse output 3 for 500 milliseconds
-- device.releaseOutput(1, 2, 3, 4)
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
-- Returns actual register address for a particular setpoint parameter.
-- @param setp is setpoint 1..16
-- @param register is REG_SETP_*
-- @return address of this register for setpoint setp
-- @usage
-- -- edit the target for setpoint 3
-- device.editReg(device.setpRegAddress(3, device.REG_SETP_TARGET))
function _M.setpRegAddress(setp, register)
    local reg = private.getRegisterNumber(register)

    if (setp > NUM_SETP) or (setp < 1) then
        dbg.error('Setpoint Invalid: ', setp)
        return 0
    elseif reg == REG_SETP_TARGET then
        return reg+setp-1
    else
        return reg+((setp-1)*REG_SETP_REPEAT)
    end
end

--------------------------------------------------------------------------------
-- Write to a set point register.
-- @param setp Setpoint 1 .. 16
-- @param reg Register (REG_SETP_*)
-- @param v Value to write
-- @local
local function setpParam(setp, reg, v)
    local r = private.getRegisterNumber(reg)
    _M.sendRegWait(_M.CMD_WRFINALDEC, _M.setpRegAddress(setp, r), v)
end

-------------------------------------------------------------------------------
-- Set the number of enabled Setpoints.
-- this disables all setpoints above the set number
-- @param n is the number of setpoints 0..16
-- @usage
-- -- reduce the number of active setpoints to setpoints 1 to 4 temporarily
-- device.setNumSetp(4)
-- ...
-- -- re-enable previously disabled setpoints
-- device.setNumSetp(8)
function _M.setNumSetp(n)
    _M.sendRegWait(_M.CMD_WRFINALDEC, REG_SETP_NUM, n)
end

-------------------------------------------------------------------------------
-- Set Target for setpoint.
-- @param setp Setpoint 1..16
-- @param target Target value
-- @usage
-- -- set the target for setpoint 5 to 150
-- device.setpTarget(5, 150)
function _M.setpTarget(setp,target)
    _M.sendRegWait(_M.CMD_WRFINALDEC, _M.setpRegAddress(setp, REG_SETP_TARGET), target)
end

-------------------------------------------------------------------------------
-- Set which Output the setpoint controls.
-- @param setp is setpoint 1..16
-- @param IO is output 1..32, 0 for none
-- @usage
-- -- make setpoint 12 use IO 3
-- device.setpIO(12, 3)
function _M.setpIO(setp, IO)
    setpParam(setp, REG_SETP_OUTPUT, IO)
end

--- Setpoint Types.
--@table Types
-- @field OFF setpoint is always inactive
-- @field ON setpoint is always active
-- @field OVER setpoint is active when the source is over the target amount
-- @field UNDER setpoint is active when the source is under the target amount
-- @field COZ setpoint is active when the source is in the centre of zero
-- @field ZERO setpoint is active when the source is in the zero band
-- @field NET setpoint is active when net weight is displayed
-- @field MOTION setpoint is active when the weight is unstable
-- @field ERROR setpoint is active when there is an error
-- @field LOGIC_AND a binary logic AND is performed on the source with the mask value
-- @field LOGIC_OR a binary logic OR is performed on the source with the mask value
-- @field LOGIC_XOR a binary logic XOR is performed on the source with the mask value
-- @field BUZZER setpoint is active when the buzzer is beeping

-------------------------------------------------------------------------------
-- Set the TYPE of the setpoint controls.
-- @param setp is setpoint 1..16
-- @param sType is setpoint type
-- @usage
-- -- set setpoint 10 to over
-- device.setpType(10, 'over')
function _M.setpType(setp, sType)
    local v = private.convertNameToValue(sType, typeMap)
    setpParam(setp, REG_SETP_TYPE, v)
end

-------------------------------------------------------------------------------
-- Set the Logic for the setpoint controls.
-- High means the output will be on when the setpoint is active and
-- low means the output will be on when the setpoint is inactive.
-- @param setp is setpount 1..16
-- @param lType is setpoint logic type "high" or "low"
-- @usage
-- -- make setpoint 4 active high
-- device.setpLogic(4, 'high')
function _M.setpLogic(setp, lType)
    local v = private.convertNameToValue(lType, logicMap)
    setpParam(setp, REG_SETP_LOGIC, v)
end

--- Setpoint Alarms Types.
--@table Alarms
-- @field NONE no alarm
-- @field SINGLE beep once per second
-- @field DOUBLE beep twice per second
-- @field FLASH flash the display

-------------------------------------------------------------------------------
-- Set the Alarm for the setpoint.
-- The alarm can beep once a second, twice a second or flash the display when
-- the setpoint is active
-- @param setp is setpoint 1..16
-- @param aType is alarm type
-- @usage
-- -- disable the alarm on setpoint 11
-- device.setpAlarm(11, 'none')
function _M.setpAlarm(setp, aType)
    local v = private.convertNameToValue(aType, alarmTypeMap)
    setpParam(setp, REG_SETP_ALARM, v)
end

-------------------------------------------------------------------------------
-- Set the Name of the setpoint.
-- this name will be displayed when editing targets via the keys
-- @param setp is setpoint 1..16
-- @param v is setpoint name (8 character string)
-- @usage
-- -- name setpoint 6 fred
-- device.setpName(6, 'fred')
function _M.setpName(setp, v)
    setpParam(setp, REG_SETP_NAME, v)
end

--- Setpoint Source Types.
--@table Source
-- @field GROSS setpoint uses the gross weight
-- @field NET setpoint uses the net weight
-- @field DISP setpoint uses the displayed weight
-- @field ALT_GROSS setpoint uses the gross weight in secondary units
-- @field ALT_NET setpoint uses the net weight in secondary units
-- @field ALT_DISP setpoint uses the displayed weight in secondary units
-- @field PIECE setpoint uses the peice count value
-- @field REG setpoint uses the value from the supplied register

-------------------------------------------------------------------------------
-- Set the data source of the setpoint controls.
-- @param setp is setpoint 1..16
-- @param sType is setpoint source type (string)
-- @param reg is register address for setpoints using .SOURCE_REG type source data.
-- For other setpoint source types parameter reg is not required.
-- @usage
-- -- set setpoint 1 to use the displayed weight
-- device.setpSource(1, 'disp')
--
-- -- set setpoint 2 to use the total weight
-- device.setpSource(2, 'reg', device.REG_GRANDTOTAL)
function _M.setpSource(setp, sType, reg)
    local v = private.convertNameToValue(sType, sourceMap)

    setpParam(setp, REG_SETP_SOURCE, v)
    if (v == SOURCE_REG) and reg then
        setpParam(setp, REG_SETP_SOURCE_REG, private.getRegisterNumber(reg))
    end
end

-------------------------------------------------------------------------------
-- Set the Hysteresis for of the setpoint controls.
-- @param setp is setpoint 1..16
-- @param v is setpoint hysteresis
-- @usage
-- -- set setpoint 1 target to 1200 and hysteresis to 10
-- device.setTarget(1, 1200)
-- device.setpHys(1, 10)
function _M.setpHys(setp, v)
    setpParam(setp, REG_SETP_HYS, _M.toPrimary(v))
end

-------------------------------------------------------------------------------
-- Query the number of set points that are available.
-- @return The number of set points
-- @usage
-- local n = device.setPointCount()
function _M.setPointCount()
    return NUM_SETP
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the depricated fields
depricated.REG_IO_STATUS            = private.REG_IO_STATUS
depricated.REG_IO_ENABLE            = REG_IO_ENABLE
depricated.REG_SETP_NUM             = REG_SETP_NUM
depricated.REG_SETP_REPEAT          = REG_SETP_REPEAT
depricated.REG_SETP_TYPE            = REG_SETP_TYPE
depricated.REG_SETP_OUTPUT          = REG_SETP_OUTPUT
depricated.REG_SETP_LOGIC           = REG_SETP_LOGIC
depricated.REG_SETP_ALARM           = REG_SETP_ALARM
depricated.REG_SETP_NAME            = REG_SETP_NAME
depricated.REG_SETP_SOURCE          = REG_SETP_SOURCE
depricated.REG_SETP_HYS             = REG_SETP_HYS
depricated.REG_SETP_SOURCE_REG      = REG_SETP_SOURCE_REG
depricated.REG_SETP_TARGET          = REG_SETP_TARGET

depricated.NUM_SETP                 = NUM_SETP

depricated.LOGIC_HIGH               = LOGIC_HIGH
depricated.LOGIC_LOW                = LOGIC_LOW

depricated.ALARM_NONE               = ALARM_NONE
depricated.ALARM_SINGLE             = ALARM_SINGLE
depricated.ALARM_DOUBLE             = ALARM_DOUBLE
depricated.ALARM_FLASH              = ALARM_FLASH

depricated.SOURCE_GROSS             = SOURCE_GROSS
depricated.SOURCE_NET               = SOURCE_NET
depricated.SOURCE_DISP              = SOURCE_DISP
depricated.SOURCE_ALT_GROSS         = SOURCE_ALT_GROSS
depricated.SOURCE_ALT_NET           = SOURCE_ALT_NET
depricated.SOURCE_ALT_DISP          = SOURCE_ALT_DISP
depricated.SOURCE_PIECE             = SOURCE_PIECE
depricated.SOURCE_REG               = SOURCE_REG

depricated.TYPE_OFF                 = TYPE_OFF
depricated.TYPE_ON                  = TYPE_ON
depricated.TYPE_OVER                = TYPE_OVER
depricated.TYPE_UNDER               = TYPE_UNDER
depricated.TYPE_COZ                 = TYPE_COZ
depricated.TYPE_ZERO                = TYPE_ZERO
depricated.TYPE_NET                 = TYPE_NET
depricated.TYPE_MOTION              = TYPE_MOTION
depricated.TYPE_ERROR               = TYPE_ERROR
depricated.TYPE_LGC_AND             = TYPE_LGC_AND
depricated.TYPE_LGC_OR              = TYPE_LGC_OR
depricated.TYPE_LGC_XOR             = TYPE_LGC_XOR
depricated.TYPE_BUZZER              = TYPE_BUZZER

end

