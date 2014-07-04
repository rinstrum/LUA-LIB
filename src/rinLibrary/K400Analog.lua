-------------------------------------------------------------------------------
--- Analogue Functions.
-- Functions to control M4401 analogue output
-- @module rinLibrary.K400Analog
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local math = math
local bit32 = require "bit"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, depricated)

-------------------------------------------------------------------------------
--- Analogue Output Control.
-- Functions to configure and control the analogue output module
-- @section analogue

local REG_ANALOGUE_DATA = 0x0323
local REG_ANALOGUE_TYPE = 0xA801
local REG_ANALOGUE_CLIP = 0xA806
local REG_ANALOGUE_SOURCE = 0xA805  -- must be set to option 3 "COMMS" if we are to control it via the comms

local CUR = 0
local VOLT = 1

local analogTypes = {   current = CUR,      volt = VOLT     }
local analogNames = {   [CUR] = 'current',  [VOLT] = 'volt' }

local curAnalogType = -1
local lastAnalogue = nil

local ANALOG_COMMS = 3
local analogSourceMap = {   comms = ANALOG_COMMS    }

-------------------------------------------------------------------------------
-- Set the analog output type
-- @param src Source for output.
-- Must be set to 'comms' to control directly
-- @usage
-- device.setAnalogSource('comms')
function _M.setAnalogSource(src)
    if type(src) == 'string' then
        src = analogSourceMap[src]
    end
    _M.sendRegWait(_M.CMD_WRFINALDEC, REG_ANALOGUE_SOURCE, src)
    private.saveSettings()
end

-------------------------------------------------------------------------------
-- Set the analog output type
-- @param typ Type for output 'current' or 'volt'
-- @return The previous analog output type
-- @usage
-- device.setAnalogType('volt')
function _M.setAnalogType(typ)
    local prev = curAnalogType

    if type(typ) == 'string' then
        typ = analogTypes[typ]
    end
    if typ == CUR then
        curAnalogType = CUR
    else
        curAnalogType = VOLT
    end

    if curAnalogType ~= prev then
        _M.sendRegWait(_M.CMD_WRFINALDEC,
                REG_ANALOGUE_TYPE,
                curAnalogType)
    end
    return analogNames[prev]
end

local setAnalogClipMsg = _M.preconfigureMsg(REG_ANALOGUE_CLIP,
                                            _M.CMD_WRFINALDEC, "noReply")
-------------------------------------------------------------------------------
-- Control behaviour of analog output outside of normal range.
-- If clip is active then output will be clipped to the nominal range
-- otherwise the output will drive to the limit of the hardware
-- @function setAnalogClip
-- @param c clipping enabled?
function _M.setAnalogClip(c)
    if c == true then c = 1 elseif c == false then c = 0 end
    setAnalogClipMsg(c)
end

-------------------------------------------------------------------------------
-- Sets the analog output to minimum 0 through to maximum 50,000
-- @param raw value in raw counts (0..50000)
-- @usage
-- device.setAnalogRaw(25000)   -- mid scale
function _M.setAnalogRaw(raw)
    if lastAnalogue ~= raw then
        _M.sendReg(_M.CMD_WRFINALDEC, REG_ANALOGUE_DATA, raw)
        lastAnalogue = raw
    end
end

-------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0 through to maximum 1.0
-- @param val value 0.0 to 1.0
-- @usage
-- device.setAnalogVal(0.5)     -- mid scale
function _M.setAnalogVal(val)
    _M.setAnalogRaw(math.floor((50000*val)+0.5))
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0% through to maximum 100%
-- @param val value 0 to 100 %
-- @usage
-- device.setAnalogPC(50)       -- mid scale
function _M.setAnalogPC(val)
    _M.setAnalogVal(val / 100)
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0V through to maximum 10.0V
-- @param val value 0.0 to 10.0
-- @usage
-- device.setAnalogVolt(5)      -- mid scale
function _M.setAnalogVolt(val)
    _M.setAnalogType(VOLT)
    _M.setAnalogVal(val / 10)
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 4.0 through to maximum 20.0 mA
-- @param val value 4.0 to 20.0
-- @usage
-- device.setAnalogCur(12)      -- mid scale
function _M.setAnalogCur(val)
    _M.setAnalogType(CUR)
    _M.setAnalogVal((val - 4) * 0.0625)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the depricated fields
depricated.CUR = CUR
depricated.VOLT = VOLT
depricated.ANALOG_COMMS = ANALOG_COMMS

depricated.REG_ANALOGUE_DATA = REG_ANALOGUE_DATA
depricated.REG_ANALOGUE_TYPE = REG_ANALOGUE_TYPE
depricated.REG_ANALOGUE_CLIP = REG_ANALOGUE_CLIP
depricated.REG_ANALOGUE_SOURCE = REG_ANALOGUE_SOURCE

end
