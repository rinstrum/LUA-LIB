-------------------------------------------------------------------------------
-- R400 LCD Services
-- Functions to add the R400 LCD to the display fields
-- @module rinLibrary.display.R400
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

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
  }

  displayTable[prefix .. "topright"] = {
      top = true, right = true, localDisplay = true,
      length = 4,
      rightJustify = function(s) return dispHelp.rightJustify(s, 4) end,
      reg = _M.REG_DISP_TOP_RIGHT,
      strlen = dispHelp.strLenLCD, -- need to fix these to match the weird display '8.8-8.8'
      finalFormat = dispHelp.padDots,
      strsub = dispHelp.strSubLCD,
      write = function (s, sync) return dispHelp.writeRegHex(private, sync, _M.REG_DISP_TOP_RIGHT, s) end
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
  }
  
  displayTable[prefix .. "bottomright"] = {
      bottom = true,  right = true, localDisplay = true,
      length = 8,
      rightJustify = function(s) return dispHelp.rightJustify(s, 8) end,
      reg = _M.REG_DISP_BOTTOM_RIGHT,
      strlen = dispHelp.strLenLCD,
      finalFormat = dispHelp.padDots,
      strsub = dispHelp.strSubLCD,
      write = function (s, sync) return dispHelp.writeRegHex(private, sync, _M.REG_DISP_BOTTOM_RIGHT, s) end
  }
  
  return displayTable

end
    
return _M
