-------------------------------------------------------------------------------
---  General Utilities.
-- General Functions for configuring the instrument
-- @module rinLibrary.K400Util
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local string        = string
local tonumber      = tonumber
local type          = type
local floor         = math.floor
local bit32         = require "bit"
local powersOfTen   = require "rinLibrary.powersOfTen"
local system        = require 'rinSystem.Pack'
local dbg           = require "rinLibrary.rinDebug"
local naming        = require 'rinLibrary.namings'
local lpeg          = require 'lpeg'
local system        = require 'rinSystem.Pack'

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

local REG_RESTART           = 0x0016
local REG_SAVESETTING       = 0x0010
local REG_COMMS_START       = 0x0309
local REG_SOFTMODEL         = 0x0003
local REG_SOFTVER           = 0x0004
private.REG_SERIALNO        = 0x0005

local REG_PRIMARY_DISPMODE   = 0x0306
local REG_SECONDARY_DISPMODE = 0x0307

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
    curRange = 1
}

local instrumentModel = ''
local instrumentSerialNumber = nil
local instrumentSoftwareVersion = nil

-------------------------------------------------------------------------------
-- Called to connect the K400 library to a socket and a system
-- The rinApp framework takes care of calling this function for you.
-- @param model Software model expected for the instrument (eg "K401")
-- @param sockA TCP sockets to connect SERA port
-- @param sockB TCP sockets to connect SERB port
-- @param app application framework
-- @usage
-- local sockets = require "rinSystem.rinSockets.Pack"
-- local me = {}
--
-- local sA = sockets.createTCPsocket('1.1.1.1', 2222, 0.001)
-- local sB = sockets.createTCPsocket('1.1.1.1', 2223, 0.001)
--
-- device.connect('K401', sA, sB, me)
function _M.connect(model, sockA, sockB, app)
    instrumentModel = model
    _M.socketA = sockA
    _M.socketB = sockB
    _M.app = app
    local ip, port = sockA:getpeername()
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
end

-------------------------------------------------------------------------------
-- Called to save any changed settings and re-initialise instrument
-- @function saveSettings
-- @local
function private.saveSettings()
    private.exReg(REG_SAVESETTING)
end

-------------------------------------------------------------------------------
-- Query if the data stream is high resolution or not
-- @return true iff high resolution
-- @usage
-- if device.isHiRes() then
--     print('high resolution readings')
-- end
function _M.isHiRes()
    return settings.hiRes
end

-------------------------------------------------------------------------------
-- Query the current number of decimal places in the specified display mode
-- @param display The display mode: 'primary', 'secondary' or 'pieces'.
-- @return The number of decimal places.
-- @usage
-- print(device.getDispModeDP('primary')..' decimal places in the primary display')
function _M.getDispModeDP(display)
    local d = naming.convertStringToValue(display, displayModeMap, nil,
                                            DISPMODE_PRIMARY, DISPMODE_SECONDARY)

    if d ~= nil then
        return settings.dispmode[d].dp
    end
    return 0
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
local function readSettings()
    settings.fullscale = private.readReg('fullscale')
    for mode = DISPMODE_PRIMARY, DISPMODE_SECONDARY do
        if settings.dispmode[mode].reg ~= 0 then
            local data, err = private.readRegHex(settings.dispmode[mode].reg)
            if data and not err then
                data = tonumber(data, 16)
                if data ~= nil then
                    local cur = settings.dispmode[mode]
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
    _M.saveAutoLeft()
end

-------------------------------------------------------------------------------
-- Called to configure the instrument library
-- The rinApp framework takes care of calling this function for you.
-- @return nil if ok or error string if model doesn't match
-- @usage
-- device.configure('K401')
function _M.configure(model)
    local s, err = private.readRegLiteral(REG_SOFTMODEL)
    if not err then
        instrumentModel = s
        instrumentSerialNumber, err = private.readRegLiteral(private.REG_SERIALNO)
    end

    dbg.info(instrumentModel, instrumentSerialNumber)

    readSettings()

    private.exReg(REG_COMMS_START)  -- clear start message

    if err then
        instrumentModel = ''
        return err
    elseif model ~= instrumentModel then
        return "Wrong Software Model"
    else
        return nil
    end
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

        os.execute('sync')
        system.sleep(0.5)
        os.execute('sync')

        private.exRegAsync(REG_RESTART)
    end

    os.execute('reboot')
    system.sleep(300)
    dbg.warn('Reboot failed')
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_PRIMARY_DISPMODE     = REG_PRIMARY_DISPMODE
deprecated.REG_SECONDARY_DISPMODE   = REG_SECONDARY_DISPMODE
deprecated.REG_SOFTMODEL            = REG_SOFTMODEL
deprecated.REG_SOFTVER              = REG_SOFTVER
deprecated.REG_SERIALNO             = private.REG_SERIALNO

deprecated.readSettings = readSettings
deprecated.saveSettings = private.saveSettings
deprecated.system = system
deprecated.settings = settings
deprecated.units = units
deprecated.countby = countby

deprecated.DISPMODE_PRIMARY      = DISPMODE_PRIMARY
deprecated.DISPMODE_PIECES       = DISPMODE_PIECES
deprecated.DISPMODE_SECONDARY    = DISPMODE_SECONDARY

end
