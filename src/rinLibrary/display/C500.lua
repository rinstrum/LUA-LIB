-------------------------------------------------------------------------------
-- C500 LCD Services
-- Functions to add the C500 LCD to the display fields
-- @module rinLibrary.display.C500
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
_M.REG_DISP_AUTO_TOP_LEFT   = 0x00B7    -- Register

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

local otherAunnuncitors = {
    none    = 0,
    per_h   = 0x14,
    per_m   = 0x11,
    per_s   = 0x12,
    percent = 0x30,     pc  = 0x30,
    total   = 0x08,     tot = 0x08,
    second  = 0x02,     s = 0x02,
    minute  = 0x01,     m = 0x01,
    hour    = 0x04,     h = 0x04,
    slash   = 0x10
}

-- REG_DISP_TOP_ANNUN BIT SETTINGS
local annunciatorMap = {
    coz             = { v=0x00004,  locn='top' },
    hold            = { v=0x00008,  locn='top' },
    motion          = { v=0x00010,  locn='top' },
    net             = { v=0x00020,  locn='top' },
    zero            = { v=0x00080,  locn='top' },
    all             = { v=1,        locn='all'  }
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
    regAuto = _M.REG_DISP_AUTO_TOP_LEFT,
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
