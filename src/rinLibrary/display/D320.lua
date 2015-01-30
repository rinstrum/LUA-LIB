-------------------------------------------------------------------------------
-- D320 LCD Services
-- Functions to add the D320 LCD to the display fields
-- @module rinLibrary.display.D320
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local ipairs = ipairs

local dispHelp = require "rinLibrary.displayHelper"
local naming = require 'rinLibrary.namings'

local canonical = naming.canonicalisation

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
    curMotion = dispHelp.rangerCFunc('motion', 'notmotion'),
    curZero = dispHelp.rangerCFunc('zero', 'notzero'),
    curRange = dispHelp.rangerCFunc('range', 'none'),
    curUnits1 = dispHelp.rangerCFunc('units', 'none'),
    curUnits2 = nil,
    mirrorStatus = false,
    writeStatus = function (...)  
                    dispHelp.writeStatus(displayTable[prefix], ...)
                    displayTable[prefix].transmit(false)
                    end,
    setAnnun = function (...) 
                    dispHelp.setAnnun(displayTable[prefix], ...) 
                    return displayTable[prefix].transmit(false)
                    end,
    clearAnnun = function (...) 
                    dispHelp.clearAnnun(displayTable[prefix], ...) 
                    return displayTable[prefix].transmit(false)
                 end,
    writeUnits = function (units1)
                    local val, e = dispHelp.rangerCFunc('units', units1)
                    
                    if (val == nil) then
                      return val, e
                    end
        
                    displayTable[prefix].curUnits1 = val
                    displayTable[prefix].transmit(false)
                    
                    return units1, nil
                  end,
    write = function (s, sync)
                  displayTable[prefix].curString = s
                  displayTable[prefix].transmit(sync)
                end,
    transmit = function (sync)
                  local me = displayTable[prefix]
                  local toSend = dispHelp.frameRangerC(me)
                  return dispHelp.writeRegHex(private, sync, me.reg, toSend)
                end
  }
  
  return displayTable
 
end

return _M
