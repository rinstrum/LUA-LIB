-------------------------------------------------------------------------------
-- R400 LCD Services
-- Functions to add the R400 LCD to the display fields
-- @module rinLibrary.display.R400
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

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
    units = nil,
    auto = nil,
    saveAuto = 0,
    writeSync = function (s) return private.writeRegHex(_M.REG_DISP_TOP_LEFT, s) end,
    writeAsync = function (s) return private.writeRegHexAsync(_M.REG_DISP_TOP_LEFT, s) end
  }

  displayTable[prefix .. "topright"] = {
      top = true, right = true, localDisplay = true,
      length = 4,
      rightJustify = function(s) return dispHelp.rightJustify(s, 4) end,
      reg = _M.REG_DISP_TOP_RIGHT,
      strlen = dispHelp.strLenLCD, -- need to fix these to match the weird display '8.8-8.8'
      finalFormat = dispHelp.padDots,
      strsub = dispHelp.strSubLCD,
      writeSync = function (s) return private.writeRegHex(_M.REG_DISP_TOP_RIGHT, s) end,
      writeAsync = function (s) return private.writeRegHexAsync(_M.REG_DISP_TOP_RIGHT, s) end
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
      units = nil,
      auto = nil,
      saveAuto = 0,
      writeSync = function (s) return private.writeRegHex(_M.REG_DISP_BOTTOM_LEFT, s) end,
      writeAsync = function (s) return private.writeRegHexAsync(_M.REG_DISP_BOTTOM_LEFT, s) end
  }
  
  displayTable[prefix .. "bottomright"] = {
      bottom = true,  right = true, localDisplay = true,
      length = 8,
      rightJustify = function(s) return dispHelp.rightJustify(s, 8) end,
      reg = _M.REG_DISP_BOTTOM_RIGHT,
      strlen = dispHelp.strLenLCD,
      finalFormat = dispHelp.padDots,
      strsub = dispHelp.strSubLCD,
      writeSync = function (s) return private.writeRegHex(_M.REG_DISP_BOTTOM_RIGHT, s) end,
      writeAsync = function (s) return private.writeRegHexAsync(_M.REG_DISP_BOTTOM_RIGHT, s) end
  }
  
  return displayTable

end
    
return _M