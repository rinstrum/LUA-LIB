-------------------------------------------------------------------------------
-- C500 LCD Services
-- Functions to add the C500 LCD to the display fields
-- @module rinLibrary.Device.LCD
-- @author Merrick Heley
-- @copyright 2016 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local math = math
local pairs = pairs

local bit32 = require "bit"
local naming = require 'rinLibrary.namings'
local dispHelp = require "rinLibrary.displayHelper"

--LCD display registers
_M.REG_DISP_TOP_LEFT        = 0x00B0    -- Takes string
_M.REG_DISP_TOP_ANNUN       = 0x00B2
_M.REG_DISP_TOP_UNITS       = 0x00B3    -- Takes string

_M.REG_DISP_AUTO_TOP_ANNUN  = 0x00B6    -- Register

local unitAnnunciators = {
    none      = 0,
    kg        = 0x01,
    lb        = 0x02,
    t         = 0x03,
    g         = 0x04,
    oz        = 0x05,
    n         = 0x06,
    arrow_l   = 0x07,
    p         = 0x08,
    l         = 0x09,
    arrow_h   = 0x0A
}

--- LCD Annunciators
-- These are the definitions of all the annunciators top, bottom, and remote.
-- Some displays may not support all annunciators. If an annunciator is not
-- supported, no action will occur.
--@table Annunciators
-- @field all All annunciators top and bottom
-- @field coz Centre-of-zero (above zero key)
-- @field motion Motion (above tare key)
-- @field gross Gross annun
-- @field net Net annun (above select key)
-- @field zero Zero band (above f1 key)
-- @field hold Hold (above f2 key)
-- @field spare Square ligth (above f3 key)
-- @field range1 Range annuns (above main lcd)
-- @field range2 Range annuns (above main lcd)
-- @field range3 Range annuns (above main lcd)
-- @field check_under2 Under2 annun (left of main lcd)
-- @field check_under1 Under1 annun (left of main lcd)
-- @field check_pass Pass annun (left of main lcd)
-- @field check_over1 Over1 annun (left of main lcd)
-- @field check_over2 Over2 annun (left of main lcd)
-- @field io1 io1 annun (above main lcd)
-- @field io2 io2 annun (above main lcd)
-- @field io3 io3 annun (above main lcd)
-- @field io4 io4 annun (above main lcd)
-- @field io5 io5 annun (above main lcd)
-- @field io6 io6 annun (above main lcd)
-- @field io7 io7 annun (above main lcd)
-- @field io8 io8 annun (above main lcd)
-- @field redlight Turn on the red traffic light (remote)
-- @field greenlight Turn on the green traffic light (remote)

-- REG_DISP_TOP_ANNUN BIT SETTINGS
local annunciatorMap = {
    none            = { v=0x00000000, locn='top'},
    coz             = { v=0x00000001, locn='top'},
    motion          = { v=0x00000002, locn='top'},
    gross           = { v=0x00000004, locn='top'},
    net             = { v=0x00000008, locn='top'},
    zero            = { v=0x00000010, locn='top'},
    hold            = { v=0x00000020, locn='top'},
    spare           = { v=0x00000040, locn='top'},
    range1          = { v=0x00000080, locn='top'},
    range2          = { v=0x00000100, locn='top'},
    range3          = { v=0x00000200, locn='top'},
    check_under2    = { v=0x00000400, locn='top'},
    check_under1    = { v=0x00000800, locn='top'},
    check_pass      = { v=0x00001000, locn='top'},
    check_over1     = { v=0x00002000, locn='top'},
    check_over2     = { v=0x00004000, locn='top'},
    io1             = { v=0x00008000, locn='top'},
    io2             = { v=0x00010000, locn='top'},
    io3             = { v=0x00020000, locn='top'},
    io4             = { v=0x00040000, locn='top'},
    io5             = { v=0x00080000, locn='top'},
    io6             = { v=0x00100000, locn='top'},
    io7             = { v=0x00200000, locn='top'},
    io8             = { v=0x00400000, locn='top'},
    spare2          = { v=0x00800000, locn='top'},
    spare3          = { v=0x01000000, locn='top'},
    all             = { v=0xFFFFFFFF, locn='all'}
}

local botAnnunState = 0
local topAnnunState = 0
local waitPos = 1

-------------------------------------------------------------------------------
-- Convert the annunciator bit maps to a list of values
-- @param l List of annunciators
-- @return table of bit mask values for 'top' and 'bottom'
-- @local
local function convertAnnunciatorBits(l)
    local res = { top = 0, bottom = 0, unknown = 0, all = 0 }
    local missing = { v=1, locn='unknown' }

    for _, v in pairs(l) do
        local bit = naming.convertNameToValue(v, annunciatorMap, missing)
        res[bit.locn] = bit32.bor(res[bit.locn], bit.v)
    end
    if res.all ~= 0 then
        for k, _ in pairs(res) do
            local a = 0
            for b, v in pairs(annunciatorMap) do
                if k == v.locn then
                    res[k] = bit32.bor(res[k], v.v)
                end
            end
        end
    end
    return res
end

-----------------------------------------------------------------------------
-- Set the annunciators
-- @local
local function setAnnunLocal(private, ...)
    local bits = convertAnnunciatorBits{...}

    if bits.top ~= 0 then
        topAnnunState = bit32.bor(topAnnunState, bits.top)
        private.writeRegHexAsync(_M.REG_DISP_TOP_ANNUN, topAnnunState)
    end
end

-----------------------------------------------------------------------------
-- Clear the annunciators
-- @local
local function clearAnnunLocal(private, ...)
    local bits = convertAnnunciatorBits{...}

    if bits.top ~= 0 then
        topAnnunState = bit32.band(topAnnunState, bit32.bnot(bits.top))
        private.writeRegHexAsync(_M.REG_DISP_TOP_ANNUN, topAnnunState)
    end
end

-------------------------------------------------------------------------------
-- Add the R400 to the displayTable. This will add 4 display fields
-- (prefix followed by topLeft, topRight, bottomLeft, and bottomRight) to the
-- table of writable displays.
-- @param private Functions from rinLibrary
-- @param displayTable displayTable used by rinLibrary
-- @param prefix Prefix to place before the field name, e.g. prefixtopLeft
-- @return Updated displayTable
-- @local
function _M.add(private, displayTable, prefix)

  displayTable[prefix .. "topleft"] = {
    top = true, left = true, localDisplay = true,
    length = 6,
    rightJustify = function(s) return dispHelp.rightJustify(s, 6) end,
    reg = _M.REG_DISP_TOP_LEFT,
    regUnits = _M.REG_DISP_TOP_UNITS,
    regAuto = nil,
    strlen = dispHelp.strLenLCD,
    finalFormat = dispHelp.padDots,
    strsub = dispHelp.strSubLCD,
    units1 = nil,
    auto = nil,
    saveAuto = 0,
    write = function (s, sync) return dispHelp.writeRegHex(private, sync, _M.REG_DISP_TOP_LEFT, s) end,
    writeUnits = function (units1)
                local me = displayTable[prefix .. "topleft"]
                local v = naming.convertNameToValue(units1, unitAnnunciators, 0)

                if me.units1 ~= v then
                  private.writeReg(me.regUnits, v)
                  me.units1 = v
                end

                return units1, nil
              end,
      setAnnun = function (...) return setAnnunLocal(private, ...) end,
      clearAnnun = function (...) return clearAnnunLocal(private, ...) end,
      rotWait = function (...) return false end,
  }

  return displayTable

end

return _M
