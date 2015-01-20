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
    curString = "       ", 
    curStatus = dispHelp.rangerCFunc('status', 'none'),
    curMotion = dispHelp.rangerCFunc('motion', 'stable'),
    curZero = dispHelp.rangerCFunc('zero', 'nonzero'),
    curRange = dispHelp.rangerCFunc('range', 'none'),
    curUnits = dispHelp.rangerCFunc('units', 'none'),
    --writeUnits = , -- Function here
    write = function (s, sync)
                  local wf = private[sync and 'writeRegHex' or 'writeRegHexAsync']
                  displayTable[prefix].curString = s 
                  return dispHelp.frameRangerC(displayTable[prefix], wf) 
                end,
  }
  
  return displayTable
 
end

return _M
