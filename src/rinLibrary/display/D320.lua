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

_M.REG_AUTO_OUT = 4

-------------------------------------------------------------------------------
-- Add the D320 to the displayTable. This will add a remote display field to 
-- the displayTable
-- @param private Functions from rinLibrary
-- @param displayTable displayTable used by rinLibrary
-- @param prefix Prefix to place before the field name, e.g. prefixD323
-- @param settings Settings table for the display
-- @return Updated displayTable
-- @local
function _M.add(private, displayTable, prefix, settings)

  displayTable[prefix] = {
    remote = true,
    length = 6,
    reg = settings.reg + _M.REG_AUTO_OUT,
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
    sock = nil,
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
  
  if (settings and settings.type == 'usb') then
    dispHelp.addUSB(displayTable[prefix], settings)
  end
  
  return displayTable
 
end

return _M
