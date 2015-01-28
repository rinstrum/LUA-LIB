-------------------------------------------------------------------------------
-- R400 LCD Services
-- Functions to add the R400 LCD to the display fields
-- @module rinLibrary.display.R400
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local math = math
local pairs = pairs

local bit32 = require "bit"
local naming = require 'rinLibrary.namings'
local dispHelp = require "rinLibrary.displayHelper"

--LCD display registers
_M.REG_DISP_BOTTOM_LEFT     = 0x000E    -- Takes string
_M.REG_DISP_BOTTOM_RIGHT    = 0x000F    -- Takes string
_M.REG_DISP_TOP_LEFT        = 0x00B0    -- Takes string
_M.REG_DISP_TOP_RIGHT       = 0x00B1    -- Takes string
_M.REG_DISP_TOP_ANNUN       = 0x00B2
_M.REG_DISP_TOP_UNITS       = 0x00B3    -- Takes string
_M.REG_DISP_BOTTOM_ANNUN    = 0x00B4
_M.REG_DISP_BOTTOM_UNITS    = 0x00B5

_M.REG_DISP_AUTO_TOP_ANNUN  = 0x00B6    -- Register
_M.REG_DISP_AUTO_TOP_LEFT   = 0x00B7    -- Register
_M.REG_DISP_AUTO_BOTTOM_LEFT= 0x00B8    -- Register

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

-- REG_DISP_BOTTOM_ANNUN BIT SETTINGS
local WAIT      = 0x0040
local WAIT45    = 0x0100
local WAIT90    = 0x0200
local WAIT135   = 0x0080
local WAITALL   = 0x03C0
local WAIT_SEGS = { WAIT, WAIT45, WAIT90, WAIT135 }

-- REG_DISP_TOP_ANNUN BIT SETTINGS
local annunciatorMap = {
    sigma           = { v=0x00001,  locn='top' },
    balance         = { v=0x00002,  locn='top' },
    coz             = { v=0x00004,  locn='top' },
    hold            = { v=0x00008,  locn='top' },
    motion          = { v=0x00010,  locn='top' },
    net             = { v=0x00020,  locn='top' },
    range           = { v=0x00040,  locn='top' },
    zero            = { v=0x00080,  locn='top' },
    bal_sega        = { v=0x00100,  locn='top' },
    bal_segb        = { v=0x00200,  locn='top' },
    bal_segc        = { v=0x00400,  locn='top' },
    bal_segd        = { v=0x00800,  locn='top' },
    bal_sege        = { v=0x01000,  locn='top' },
    bal_segf        = { v=0x02000,  locn='top' },
    bal_segg        = { v=0x04000,  locn='top' },
    range_segadg    = { v=0x08000,  locn='top' },
    range_segc      = { v=0x10000,  locn='top' },
    range_sege      = { v=0x20000,  locn='top' },
    battery         = { v=0x0001,   locn='bottom' },
    clock           = { v=0x0002,   locn='bottom' },
    bat_lo          = { v=0x0004,   locn='bottom' },
    bat_midl        = { v=0x0008,   locn='bottom' },
    bat_midh        = { v=0x0010,   locn='bottom' },
    bat_hi          = { v=0x0020,   locn='bottom' },
    bat_full        = { v=0x003D,   locn='bottom' },
    wait            = { v=WAIT,     locn='bottom' },
    wait45          = { v=WAIT45,   locn='bottom' },
    wait90          = { v=WAIT90,   locn='bottom' },
    wait135         = { v=WAIT135,  locn='bottom' },
    waitall         = { v=WAITALL,  locn='bottom' },
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

    if bits.bottom ~= 0 then
        botAnnunState = bit32.bor(botAnnunState, bits.bottom)
        private.writeRegHexAsync(_M.REG_DISP_BOTTOM_ANNUN, botAnnunState)
    end

    if bits.top ~= 0 then
        topAnnunState = bit32.bor(topAnnunState, bits.top)
        private.writeRegHexAsync(_M.REG_DISP_TOP_ANNUN, topAnnunState)
    end
end

local function clearAnnunLocal(private, ...)
    local bits = convertAnnunciatorBits{...}

    if bits.bottom ~= 0 then
        botAnnunState = bit32.band(botAnnunState, bit32.bnot(bits.bottom))
        private.writeRegHexAsync(_M.REG_DISP_BOTTOM_ANNUN, botAnnunState)
    end

    if bits.top ~= 0 then
        topAnnunState = bit32.band(topAnnunState, bit32.bnot(bits.top))
        private.writeRegHexAsync(_M.REG_DISP_TOP_ANNUN, topAnnunState)
    end
end

local function rotWaitLocal(private, dir)
    if dir ~= 0 then
        waitPos = (waitPos - dir / math.abs(dir)) % #WAIT_SEGS
        if waitPos == 0 then waitPos = #WAIT_SEGS end
    end

    botAnnunState = bit32.band(botAnnunState, bit32.bnot(WAITALL))
    botAnnunState = bit32.bor(botAnnunState, WAIT_SEGS[waitPos])
    
    private.writeRegHexAsync(_M.REG_DISP_BOTTOM_ANNUN, botAnnunState)
end

-------------------------------------------------------------------------------
-- Add the R400 to the displayTable. This will add 4 display fields
-- (prefix followed by topLeft, topRight, bottomLeft, and bottomRight) to the 
-- table of writable displays.
-- @local
-- @param private functions for rinLibrary
-- @param displayTable used by rinLibrary
-- @param prefix to place before the field name, e.g. prefixtopLeft
-- @return Updated displayTable
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
    units2 = nil,
    auto = nil,
    saveAuto = 0,
    write = function (s, sync) return dispHelp.writeRegHex(private, sync, _M.REG_DISP_TOP_LEFT, s) end,
    writeUnits = function (units1, units2)
    
                local me = displayTable[prefix .. "topleft"]
                
                local u = naming.convertNameToValue(units1, unitAnnunciators, 0x00)
                local o = naming.convertNameToValue(units2, otherAunnuncitors, 0x00)
                local v = bit32.bor(bit32.lshift(o, 8), u)
                
                if me.units1 ~= units1 or me.units2 ~= units2 then
                  private.writeReg(me.regUnits, v)
                  me.units1 = units1
                  me.units2 = units2
                end
                
                return units1, units2
              end,
      setAnnun = function (...) return setAnnunLocal(private, ...) end,
      clearAnnun = function (...) return clearAnnunLocal(private, ...) end,
      rotWait = function (...) return rotWaitLocal(private, ...) end, 
  }

  displayTable[prefix .. "topright"] = {
      top = true, right = true, localDisplay = true,
      length = 4,
      rightJustify = function(s) return dispHelp.rightJustify(s, 4) end,
      reg = _M.REG_DISP_TOP_RIGHT,
      strlen = dispHelp.strLenLCD, -- need to fix these to match the weird display '8.8-8.8'
      finalFormat = dispHelp.padDots,
      strsub = dispHelp.strSubLCD,
      write = function (s, sync) return dispHelp.writeRegHex(private, sync, _M.REG_DISP_TOP_RIGHT, s) end,
      setAnnun = function (...) return setAnnunLocal(private, ...) end,
      clearAnnun = function (...) return clearAnnunLocal(private, ...) end
  }
  
  displayTable[prefix .. "bottomleft"] = {
      bottom = true,  left = true, localDisplay = true,
      length = 9,
      rightJustify = function(s) return dispHelp.rightJustify(s, 9) end,
      reg = _M.REG_DISP_BOTTOM_LEFT,
      regUnits = _M.REG_DISP_BOTTOM_UNITS,
      regAuto = _M.REG_DISP_AUTO_BOTTOM_LEFT,
      strlen = dispHelp.strLenLCD,
      finalFormat = dispHelp.padDots,
      strsub = dispHelp.strSubLCD,
      units1 = nil,
      units2 = nil,
      auto = nil,
      saveAuto = 0,
      write = function (s, sync) return dispHelp.writeRegHex(private, sync, _M.REG_DISP_BOTTOM_LEFT, s) end,
      writeUnits = function (units1, units2)

            local me = displayTable[prefix .. "bottomleft"]
            
            local u = naming.convertNameToValue(units1, unitAnnunciators, 0x00)
            local o = naming.convertNameToValue(units2, otherAunnuncitors, 0x00)
            local v = bit32.bor(bit32.lshift(o, 8), u)
            
            if me.units1 ~= units1 or me.units2 ~= units2 then
              private.writeReg(me.regUnits, v)
              me.units1 = units1
              me.units2 = units2
            end
            
            return units1, units2
          end,
      setAnnun = function (...) return setAnnunLocal(private, ...) end,
      clearAnnun = function (...) return clearAnnunLocal(private, ...) end,
      rotWait = function (...) return rotWaitLocal(private, ...) end, 
  }
  
  displayTable[prefix .. "bottomright"] = {
      bottom = true,  right = true, localDisplay = true,
      length = 8,
      rightJustify = function(s) return dispHelp.rightJustify(s, 8) end,
      reg = _M.REG_DISP_BOTTOM_RIGHT,
      strlen = dispHelp.strLenLCD,
      finalFormat = dispHelp.padDots,
      strsub = dispHelp.strSubLCD,
      write = function (s, sync) return dispHelp.writeRegHex(private, sync, _M.REG_DISP_BOTTOM_RIGHT, s) end,
      setAnnun = function (...) return setAnnunLocal(private, ...) end,
      clearAnnun = function (...) return clearAnnunLocal(private, ...) end,
      rotWait = function (...) return rotWaitLocal(private, ...) end, 
  }
  
  return displayTable

end
    
return _M
