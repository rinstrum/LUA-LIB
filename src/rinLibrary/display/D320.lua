-------------------------------------------------------------------------------
-- R400 LCD Services
-- Functions to add the R400 LCD to the display fields
-- @module rinLibrary.display.R400
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local dispHelp = require "rinLibrary.displayHelper"

_M.REG_AUTO_OUT = 0xA205

function _M.add(private, displayTable, prefix)
  
  displayTable[prefix] = {
    remote = true,
    length = 6,
    reg = _M.REG_AUTO_OUT,
    strlen = dispHelp.strLenLCD,
    finalFormat = dispHelp.padDots,
    strsub = dispHelp.strSubLCD,
    curString = 'none', 
    curStatus = 'stable',
    curMotion = 'nonzero',
    curRange = 'none',
    curUnits = 'none',
    --writeUnits = , -- Function here
    writeSync = function (s) return private.writeRegHex(_M.REG_AUTO_OUT, dispHelp.rangerC(s, 'net', 'stable', 'nonzero', 'none', 'kg')) end,
    writeAsync = function (s) return private.writeRegHexAsync(_M.REG_AUTO_OUT, dispHelp.rangerC(s, 'net', 'stable', 'nonzero', 'none', 'kg')) end
  }
  
  return displayTable
 
end

return _M
