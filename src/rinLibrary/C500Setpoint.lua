-------------------------------------------------------------------------------
--- Setpoint Functions.
-- Functions to control setpoint outputs
-- @module rinLibrary.Device.Setpoint
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local math = math
local ipairs = ipairs
local tonumber = tonumber

local bit32 = require "bit"
local timers = require 'rinSystem.rinTimers'
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local pow2 = require 'rinLibrary.powersOfTwo'

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

private.addRegisters{ io_status = 0x0051 }
local REG_IO_ENABLE         = 0x0054

-- add Repeat to each registers below for each setpoint 0..15
local REG_SETP_REPEAT       = 0x0020
local REG_SETP_TYPE         = 0xA401
local REG_SETP_LOCK         = 0xA402
local REG_SETP_LOGIC        = 0xA403
local REG_SETP_ALARM        = 0xA404
local REG_SETP_SOURCE       = 0xA406
local REG_SETP_TARGET       = 0xA408
local REG_SETP_HYS          = 0xA409
local REG_SETP_FLIGHT       = 0xA40A

--- Setpoint Logic Types.
--@table Logic
-- @field high High
-- @field low Low
local logicMap = {
    high = 0,
    low  = 1
}

--- Setpoint Alarms Types.
--@table Alarms
-- @field none No alarm
-- @field single Beep once per second
-- @field double Beep twice per second
-- @field cont Beep continuously
-- @field flash Flash the display
local alarmTypeMap = {
    none    = 0,
    single  = 1,
    double  = 2,
    cont    = 3,
    flash   = 4
}

--- Setpoint Source Types.
--@table Source
-- @field gross Setpoint uses the gross weight
-- @field net Setpoint uses the net weight
local sourceMap
private.registerDeviceInitialiser(function()
    sourceMap = {
        gross     = 0,
        net       = 1,
    }
end)

--- Setpoint Types.
--@table Types
-- @field off Setpoint is always inactive
-- @field on Setpoint is always active
-- @field over Setpoint is active when the source is over the target amount
-- @field under Setpoint is active when the source is under the target amount
-- @field coz Setpoint is active when the source is in the centre of zero
-- @field zero Setpoint is active when the source is in the zero band
-- @field net Setpoint is active when net weight is displayed
-- @field motion Setpoint is active when the weight is unstable
-- @field error Setpoint is active when there is an error
-- @field buzzer Setpoint is active when the buzzer is beeping
local typeMap
private.registerDeviceInitialiser(function()
    typeMap = {
        off         = 0,
        on          = 1,
        over        = 2,
        under       = 3,
        coz         = 4,
        zero        = 5,
        net         = 6,
        motion      = 7,
        error       = 8,
        buzzer      = 9
    }
end)

--- Setpoint Lock Types.
--@table Lock
-- @field off Off
-- @field on On
local lockMap = {
    off = 0,
    on  = 1
}

local lastOutputs = nil
local timedOutputs = 0   -- keeps track of which IO are already running off timers
-- bits set if under LUA control, clear if under instrument control
local lastIOEnable = nil

local NUM_SETP = 8

-------------------------------------------------------------------------------
-- Write the bit mask of the IOs, bits must first be enabled for comms control.
-- @param outp 8 bit mask of IOs
-- @see setOutputEnable
-- @usage
-- -- set IO3 on
-- setOutputEnable(0x04)
-- setOutputs(0x04)
-- @local
local function setOutputs(outp)
    if outp ~= lastOutputs then
        private.writeRegAsync('io_status', outp)
        lastOutputs = outp
    end
end

-------------------------------------------------------------------------------
-- Enable IOs for comms control.
-- @param en 8 bit mask of IOs
-- @see setOutputs
-- @usage
-- -- set IO3 on
-- setOutputEnable(0x04)
-- setOutputs(0x04)
-- @local
local function setOutputEnable(en)
    if en ~= lastIOEnable then
        private.writeRegAsync(REG_IO_ENABLE, en)
        lastIOEnable = en
    end
end

-------------------------------------------------------------------------------
-- Turns IO Output on.
-- @int ... List of IO to turn on 1..8
-- @see enableOutput
-- @usage
-- -- set IOs 3 and 4 on
-- device.turnOn(3, 4)
function _M.turnOn(...)
    local curOutputs = lastOutputs or 0
    for _,v in ipairs{...} do
        if v < 32 and v > 0 and private.checkOutput(v) then
            curOutputs = bit32.bor(curOutputs, pow2[v-1])
        end
    end

    setOutputs(curOutputs)
end

-------------------------------------------------------------------------------
-- Turns IO Output off.
-- @int ... List of IO to turn off 1..8
-- @see enableOutput
-- @usage
-- -- set IOs 3 and 4 off
-- device.turnOff(3, 4)
function _M.turnOff(...)
    local curOutputs = lastOutputs or 0
    for _,v in ipairs{...} do
        if v < 32 and v > 0 and private.checkOutput(v) then
            curOutputs = bit32.band(curOutputs, bit32.bnot(pow2[v-1]))
        end
    end

    setOutputs(curOutputs)
end

-------------------------------------------------------------------------------
-- Turns IO Output on for a period of time.
-- @int IO Output 1..8
-- @int t Time in seconds
-- @see enableOutput
-- @usage
-- -- turn IO 1 on for 5 seconds
-- device.turnOnTimed(1, 5)
function _M.turnOnTimed(IO, t)
    if private.checkOutput(IO) then
        local IOMask = pow2[IO - 1]
        if bit32.band(timedOutputs, IOMask) == 0 then
            _M.turnOn(IO)
            timers.addTimer(0, t, function ()
                timedOutputs = bit32.band(timedOutputs, bit32.bnot(IOMask))
                _M.turnOff(IO)
            end)
            timedOutputs = bit32.bor(timedOutputs, IOMask)
        else
            dbg.warn('IO Timer overlap: ', IO)
        end
    end
end

-------------------------------------------------------------------------------
-- Sets IO Output under LUA control.
-- @int ... List of IO to enable (input 1..8)
-- @see releaseOutput
-- @usage
-- device.enableOutput(1,2,3,4)
-- device.turnOn(1)
-- device.turnOff(2)
-- device.turnOnTimed(3, 0.500) -- pulse output 3 for 500 milliseconds
-- device.releaseOutput(1,2,3,4)

function _M.enableOutput(...)
    local curIOEnable = lastIOEnable or 0

    for i,v in ipairs(arg) do
        v = tonumber(v)
        curIOEnable = bit32.bor(curIOEnable, pow2[v-1])
        private.setIOkind(v, true)
    end

    setOutputEnable(curIOEnable)
end

-------------------------------------------------------------------------------
-- Sets IO Output under instrument control.
-- @int ... List of IO to release to the instrument (input 1..8)
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
        curIOEnable = bit32.band(curIOEnable, bit32.bnot(pow2[v-1]))
        private.setIOkind(v, false)
    end

    setOutputEnable(curIOEnable)
end

--------------------------------------------------------------------------------
-- Returns actual register address for a particular setpoint parameter.
-- @int setp Setpoint 1 .. setPointCount()
-- @tparam register register device.REG_SETP_*
-- @see setPointCount
-- @treturn int Address of this register for setpoint setp
-- @usage
-- -- edit the target for setpoint 3
-- device.editReg(device.setpRegAddress(3, device.REG_SETP_TARGET))
function _M.setpRegAddress(setp, register)
    local reg = private.getRegisterNumber(register)

    if (setp > _M.setPointCount()) or (setp < 1) then
        dbg.error('Setpoint Invalid: ', setp)
        return nil
    elseif reg == REG_SETP_TARGET then
        return reg+setp-1
    else
        return reg+((setp-1)*REG_SETP_REPEAT)
    end
end

--------------------------------------------------------------------------------
-- Write to a set point register.
-- @int setp Setpoint 1 .. setPointCount()
-- @tparam register reg device.REG_SETP_*
-- @int v Value to write
-- @see setPointCount
-- @local
local function setpParam(setp, reg, v)
    local r = private.getRegisterNumber(reg)
    private.writeReg(_M.setpRegAddress(setp, r), v)
end

-------------------------------------------------------------------------------
-- Set Target for setpoint.
-- @int setp Setpoint 1 .. setPointCount()
-- @int target Target value
-- @see setPointCount
-- @usage
-- -- set the target for setpoint 5 to 150
-- device.setpTarget(5, 150)
function _M.setpTarget(setp,target)
    private.writeReg(_M.setpRegAddress(setp, REG_SETP_TARGET), target)
end

-------------------------------------------------------------------------------
-- Set the TYPE of the setpoint controls.
-- @int setp Setpoint 1 .. setPointCount()
-- @tparam Types sType is setpoint type
-- @see setPointCount
-- @usage
-- -- set setpoint 10 to over
-- device.setpType(10, 'over')
function _M.setpType(setp, sType)
    local v = naming.convertNameToValue(sType, typeMap)
    setpParam(setp, REG_SETP_TYPE, v)
end

-------------------------------------------------------------------------------
-- Set the Logic for the setpoint controls.
-- High means the output will be on when the setpoint is active and
-- low means the output will be on when the setpoint is inactive.
-- @int setp Setpoint 1 .. setPointCount()
-- @tparam Logic lType Setpoint logic type "high" or "low"
-- @see setPointCount
-- @usage
-- -- make setpoint 4 active high
-- device.setpLogic(4, 'high')
function _M.setpLogic(setp, lType)
    local v = naming.convertNameToValue(lType, logicMap)
    setpParam(setp, REG_SETP_LOGIC, v)
end

-------------------------------------------------------------------------------
-- Set the Alarm for the setpoint.
-- The alarm can beep once a second, twice a second or flash the display when
-- the setpoint is active
-- @int setp Setpoint 1 .. setPointCount()
-- @tparam Alarms aType is alarm type
-- @see setPointCount
-- @usage
-- -- disable the alarm on setpoint 11
-- device.setpAlarm(11, 'none')
function _M.setpAlarm(setp, aType)
    local v = naming.convertNameToValue(aType, alarmTypeMap)
    setpParam(setp, REG_SETP_ALARM, v)
end

-------------------------------------------------------------------------------
-- Set the data source of the setpoint controls.
-- @int setp Setpoint 1 .. setPointCount()
-- @tparam Source sType Setpoint source type
-- @see setPointCount
-- @usage
-- -- set setpoint 1 to use the gross weight
-- device.setpSource(1, 'gross')
--
-- -- set setpoint 2 to use the net weight
-- device.setpSource(2, 'net')
function _M.setpSource(setp, sType)
    local v = naming.convertNameToValue(sType, sourceMap)
    setpParam(setp, REG_SETP_SOURCE, v)
end

-------------------------------------------------------------------------------
-- Set the Lock for the setpoint.
-- Off means the setpoint is not locked and
-- on means the setpoint is locked.
-- @int setp Setpoint 1 .. setPointCount()
-- @tparam Lock lType Setpoint lock type "off" or "on"
-- @see setPointCount
-- @usage
-- -- lock setpoint 4
-- device.setpLock(4, 'on')
function _M.setpLock(setp, lType)
    local v = naming.convertNameToValue(lType, lockMap)
    setpParam(setp, REG_SETP_LOCK, v)
end

-------------------------------------------------------------------------------
-- Set the Hysteresis for of the setpoint controls.
-- @int setp Setpoint 1 .. setPointCount()
-- @int v Setpoint hysteresis
-- @see setPointCount
-- @usage
-- -- set setpoint 1 target to 1200 and hysteresis to 10
-- device.setTarget(1, 1200)
-- device.setpHys(1, 10)
function _M.setpHys(setp, v)
    setpParam(setp, REG_SETP_HYS, _M.toPrimary(v))
end

-------------------------------------------------------------------------------
-- Set the in-flight for of the setpoint controls.
-- @int setp Setpoint 1 .. setPointCount()
-- @int v Setpoint in-flight
-- @see setPointCount
-- @usage
-- -- set setpoint 1 target to 1200 and flight to 50
-- device.setTarget(1, 1200)
-- device.setpFlight(1, 50)
function _M.setpFlight(setp, v)
    setpParam(setp, REG_SETP_FLIGHT, _M.toPrimary(v))
end

-------------------------------------------------------------------------------
-- Query the number of set points that are available.
-- @treturn int The number of set points
-- @usage
-- local n = device.setPointCount()
function _M.setPointCount()
    return NUM_SETP
end

end

