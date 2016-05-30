-------------------------------------------------------------------------------
---  General Utilities.
-- General Functions for configuring the instrument
-- @module rinLibrary.Device.Util
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local string = string
local format = string.format
local tonumber = tonumber
local type = type
local floor = math.floor
local ipairs = ipairs
local unpack = unpack
local error = error
local os = os
local bit32         = require "bit"
local powersOfTen   = require "rinLibrary.powersOfTen"
local system        = require 'rinSystem'
local dbg           = require "rinLibrary.rinDebug"
local naming        = require 'rinLibrary.namings'
local lpeg          = require 'rinLibrary.lpeg'
local utils         = require 'rinSystem.utilities'

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

local REG_RESTART           = 0x0016
local REG_SAVESETTING       = 0x0010
local REG_COMMS_START       = 0x0309
local REG_REINITIALISE      = 0x030B
local REG_SOFTMODEL         = 0x0003
local REG_SOFTVER           = 0x0004
private.REG_SERIALNO        = 0x0005
local REG_DUAL_RANGE        = 0x1120

local REG_PRIMARY_DISPMODE   = 0x0306
local REG_SECONDARY_DISPMODE = 0x0307
local REG_INSTRUMENT_BEGIN   = 0x032D

local DISPMODE_PRIMARY      = 1
local DISPMODE_PIECES       = 2
local DISPMODE_SECONDARY    = 3

local displayModeMap = {
    primary   = DISPMODE_PRIMARY,
    pieces    = DISPMODE_PIECES,
    secondary = DISPMODE_SECONDARY
}

local units = {"  ", "kg", "lb", "t ", "g ", "oz", "N ", "  ", "p ", "l ", "  "}
local countby = {1, 2, 5, 10, 20, 50, 100, 200, 500}

local settings = {
    fullscale = 3000,
    dispmode = {
        [DISPMODE_PRIMARY] =   { reg = REG_PRIMARY_DISPMODE,   units = units[2], dp = 0, countby = {1, 2, 5}},
        [DISPMODE_PIECES] =    { reg = 0,                      units = units[9], dp = 0, countby = {1, 1, 1}},
        [DISPMODE_SECONDARY] = { reg = REG_SECONDARY_DISPMODE, units = units[3], dp = 0, countby = {2, 5, 10}}
    },
    curDispMode = DISPMODE_PRIMARY,
    hiRes = false,
    curRange = 1,
    dualRange = 'single'
}

local instrumentModel = nil
local instrumentSerialNumber = nil
local instrumentSoftwareVersion = nil

--- Reinitialisation options
--
-- These are various subsystems that can be reinitialised individually.
--@table ReinitialisationOptions
-- @field io The digital IO ports
-- @field all Everything
local initialisation_options = {
    io      = 0x00000001,
    all     = 0xffffffff
}

-------------------------------------------------------------------------------
-- Called to connect the K400 library to a socket and a system
-- The rinApp framework takes care of calling this function for you.
-- @param sockA TCP sockets to connect SERA port
-- @param sockB TCP sockets to connect SERB port
-- @param app application framework
-- @usage
-- local sockets = require "rinSystem.rinSockets"
-- local me = {}
--
-- local sA = sockets.createTCPsocket('1.1.1.1', 2222, 0.001)
-- local sB = sockets.createTCPsocket('1.1.1.1', 2223, 0.001)
--
-- device.connect(sA, sB, me)
function _M.connect(sockA, sockB, app)
    _M.socketA = sockA
    _M.socketB = sockB
    _M.app = app
    local ip, port = sockA:getpeername()

    -- Force the instrument to a known initial state
    private.exRegAsync(REG_INSTRUMENT_BEGIN)
end

-------------------------------------------------------------------------------
-- Called to disconnect the K400 library and clean everything up
-- The rinApp framework takes care of calling this function for you.
-- @usage
-- device.terminate()
function _M.terminate()
    _M.restoreLcd()
    _M.lcdControl('default')
    _M.streamCleanup()
    _M.endKeys()
    private.exReg(REG_INSTRUMENT_BEGIN)     -- synchronous operation last
end

-------------------------------------------------------------------------------
-- Called to save any changed settings and re-initialise instrument
-- @usage
-- device.saveSettings()
function _M.saveSettings()
    private.exReg(REG_SAVESETTING)
    _M.waitStatus('init', 5)
end

-------------------------------------------------------------------------------
-- Reinitialise the specified subsystems
-- @param ... Names of subsystems to be reinitialised (none = reinitialise everything)
-- @see ReinitialisationOptions
-- @usage
-- device.reinitialise 'io'
function _M.reinitialise(...)
    local b = 0
    for _, i in ipairs{...} do
        b = bit32.bor(naming.convertNameToValue(i, initialisation_options, 0), b)
    end
    private.exReg(REG_REINITIALISE, b ~= 0 and b or initialisation_options.all)
end

-------------------------------------------------------------------------------
-- Query if the data stream is high resolution or not
-- @return true if high resolution
-- @usage
-- if device.isHiRes() then
--     print('high resolution readings')
-- end
function _M.isHiRes()
    return settings.hiRes
end

-------------------------------------------------------------------------------
-- Query if we're in single range, dual interval or dual range mode
-- @return String describing the range setting
-- @see DualRangeModes
-- @usage
-- print('Device is in '..device.dualRangeMode()..' range mode')
function _M.dualRangeMode()
    return settings.dualRange
end

--- Dual range modes
-- @table DualRangeModes
-- @field single Single range mode
-- @field dual.i Dual interval mode
-- @field dual.r Dual range mode
-- @see dualRangeMode

-------------------------------------------------------------------------------
-- Query the current setting of a given field in the specified display mode
-- @param display The display mode: 'primary', 'secondary' or 'pieces'.
-- @param field 'dp', 'units' or 'countby'
-- @param default default return value if something goes awry
-- @return The given field.
-- @usage
-- print(device.getDispModeDP('primary')..' decimal places in the primary display')
local function querySettings(display, field, default)
    local d = naming.convertNameToValue(display, displayModeMap, nil,
                                            DISPMODE_PRIMARY, DISPMODE_SECONDARY)
    if d ~= nil then
        return settings.dispmode[d][field] or default
    end
    return default
end

-------------------------------------------------------------------------------
-- Query the current number of decimal places in the specified display mode
-- @param display The display mode: 'primary', 'secondary' or 'pieces'.
-- @return The number of decimal places.
-- @usage
-- print(device.getDispModeDP('primary')..' decimal places in the primary display.')
function _M.getDispModeDP(display)
    return querySettings(display, 'dp', 0)
end

-------------------------------------------------------------------------------
-- Query the current units in the specified display mode
-- @param display The display mode: 'primary', 'secondary' or 'pieces'.
-- @return The units being used.
-- @usage
-- print(device.getDispModeUnits('primary')..' are the primary units.')
function _M.getDispModeUnits(display)
    return querySettings(display, 'units', nil)
end

-------------------------------------------------------------------------------
-- Query the current count by setting in the specified display mode
-- @param display The display mode: 'primary', 'secondary' or 'pieces'.
-- @return The countby setting as a three element unpacked vector.
-- @usage
-- local countby = { device.getDispModeCountBy('primary') }
-- for i = 1, #countby do
--     print(i, countby[i])
-- end
function _M.getDispModeCountBy(display)
    return unpack(querySettings(display, 'countby', nil))
end

-------------------------------------------------------------------------------
-- Update the curent settings for hi resolution, display mode and range.
-- @function updateSettings
-- @param hiRes High resolution (boolean)
-- @param mode Display mode
-- @param range Range
-- @local
function private.updateSettings(hiRes, mode, range)
    settings.hiRes       = hiRes
    settings.curDispMode = mode
    settings.curRange    = range
end

-------------------------------------------------------------------------------
-- Called to load settings
-- @local
function private.readSettings()
    settings.fullscale = private.readReg('fullscale')
    settings.dualRange = string.lower(private.readReg(REG_DUAL_RANGE) or 'single')

    for mode, cur in ipairs(settings.dispmode) do
        if cur.reg ~= 0 then
            local data, err = private.readRegHex(cur.reg)
            if data and not err then
                data = tonumber(data, 16)
                if data ~= nil then
                    cur.dp         = bit32.band(data, 0x0000000F)
                    cur.units      = units  [1 + bit32.band(bit32.rshift(data,  4), 0x0000000F)]
                    cur.countby[3] = countby[1 + bit32.band(bit32.rshift(data,  8), 0x000000FF)]
                    cur.countby[2] = countby[1 + bit32.band(bit32.rshift(data, 16), 0x000000FF)]
                    cur.countby[1] = countby[1 + bit32.band(bit32.rshift(data, 24), 0x000000FF)]
                else
                    dbg.warn('Bad settings data: ', data)
                end
            else
                dbg.warn('Incorrect read: ',data,err)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Called to initially set up the instrument library
-- The rinApp framework takes care of calling this function for you.
-- @return nil if ok or error string if model doesn't match
-- @usage
-- device.initialisation('K401')
function _M.initialisation(model)
    local s, err = private.readRegLiteral(REG_SOFTMODEL)
    if not err then
        instrumentModel = s
        instrumentSerialNumber, err = private.readRegLiteral(private.REG_SERIALNO)
    end
    dbg.info(instrumentModel, instrumentSerialNumber)

    if err then
        instrumentModel = ''
        return err
    elseif model ~= nil and model ~= instrumentModel then
        dbg.warn('Device:', 'wrong software model '..model..' (device is '..instrumentModel..')')
    end

    private.deviceType = string.lower(instrumentModel)
    private.processDeviceInitialisers()
    return nil
end

-------------------------------------------------------------------------------
-- Called to configure the instrument library
-- The rinApp framework takes care of calling this function for you.
-- @usage
-- device.configure()
function _M.configure()
    private.readSettings()
    private.exRegAsync(REG_COMMS_START)  -- clear start message
end

-------------------------------------------------------------------------------
-- Query the instrument's model number, e.g. "K401"
-- @return Unit model number
function _M.getModel()
    return instrumentModel
end

-------------------------------------------------------------------------------
-- Query the instrument's serial number
-- @return Unit serial number
function _M.getSerialNumber()
    return instrumentSerialNumber
end

-------------------------------------------------------------------------------
-- Query the instrument's software version, e.g. "V1.00"
-- @return Unit software version
function _M.getVersion()
    if instrumentSoftwareVersion == nil then
        instrumentSoftwareVersion = private.readRegLiteral(REG_SOFTVER)
    end
    return instrumentSoftwareVersion
end

-------------------------------------------------------------------------------
-- Called to convert a floating point value to a decimal integer based on then
-- primary instrument weighing settings
-- @param v is value to convert
-- @param dp decimal position (if nil then instrument dp used)
-- @return floating point value suitable for a WRFINALDEC
-- @usage
-- local curWeight = 0
-- device.addStream('grossnet', function(data, err) curWeight = data end, 'change')
-- ...
-- device.writeReg('usernum3', device.toPrimary(curWeight))
function _M.toPrimary(v, dp)
    local dp = dp or settings.dispmode[settings.curDispMode].dp  -- use instrument dp if not specified otherwise

    if type(v) == 'string' then
        v = tonumber(v)
    end                              -- TODO: how to handle non-numbers elegantly here?
    return floor(0.5 + v * powersOfTen[dp])
end

-------------------------------------------------------------------------------
-- Format a value using the current display mode.
-- The value is correctly rounded in the final digit.
-- @param display The display mode: 'primary', 'secondary' or 'pieces'.
-- @param value The floating point value to format.
-- @param dp Decimal point position (integer >= 0). If specified, this overrides the display value.
-- @param countby The minimum change in the final decimal point value (integer). If specified, this overrides the display value.
-- @param units The units string. If specified (3 chars max), this overrides the display value. If false, no units will be displayed.
-- @return Formatted string.
-- @usage
-- print('Weight is', device.formatValue('primary', currentWeight))
-- print('Weight is', device.formatValue(nil, 15.9532, 3, 2, false)) -- Returns 15.954
function _M.formatValue(display, value, dp, countby, units)
    
    -- Get dp (factor in hi-res)
    if dp == nil then
      if _M.isHiRes then
        dp = _M.getDispModeDP(display) + 1
      end
      dp = _M.getDispModeDP(display)
    end
    
    -- Get countby value
    if countby == nil then
      if _M.anyStatusSet('range1') then
        countby = _M.getDispModeCountBy(display)[1]
      else
        countby = _M.getDispModeCountBy(display)[2]
      end
    end

    -- Check units
    if units == false then
      units = ''
    else
      units = ' ' .. (units or _M.getDispModeUnits(display))
    end
    
    local w
    
    if powersOfTen[dp] > countby then
      w = floor(value * (powersOfTen[dp]/countby) + 0.5) * countby
    else
      w = floor(value / (countby/powersOfTen[dp]) + 0.5) * countby
    end
    
    local v = string.format('%.0f', w)
    local f = '.' .. (('0'):rep(dp) .. v):sub(-dp)
    local i = v:sub(1, -dp-1)
    return format('%s%s%.4s', i~='' and i or '0', dp>0 and f or '', units)
end

-------------------------------------------------------------------------------
-- Restart the display and this module
-- @param what Which devices to reboot, nil or 'lua' for the lua host,
-- 'all' for everything.
-- @usage
-- device.restart()
-- -- This line is never executed
function _M.restart(what)
    local w = what or 'lua'

    if w == 'all' then
        -- The trick here is after we tell the display to restart, our power will
        -- be dropped at some not well determined point.  Thus we've got to do
        -- this as cleanly as possible

        local Cb, Cg, P, R = lpeg.Cb, lpeg.Cg, lpeg.P, lpeg.R
        local pat = P'/dev/' * Cg(P'sd' * R'az' * R'09'^1, 'dv') *
                    P' /mnt/' * (Cb'dv' / function(m) os.execute('umount -f /mnt/'..m) end)

        for mount in io.lines('/proc/mounts') do
            pat:match(mount)
        end

        utils.sync()
        system.sleep(0.5)
        utils.sync()

        private.exRegAsync(REG_RESTART)
        _M.app.delay(0.5)
    end

    utils.reboot()
    system.sleep(300)
    error('Restart failed')
end

end
