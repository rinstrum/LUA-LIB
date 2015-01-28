-------------------------------------------------------------------------------
-- R400 LCD Services
-- Functions to add the R400 LCD to the display fields
-- @module rinLibrary.display.R400
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
    writeStatus = function (anyStatusSet, allStatusSet, dualRangeMode)
                    local me = displayTable[prefix]
                    
                    if anyStatusSet('error') then
                      me.curStatus = dispHelp.rangerCFunc('status', 'error')
                    elseif anyStatusSet('uload') then
                      me.curStatus = dispHelp.rangerCFunc('status', 'uload')
                    elseif anyStatusSet('oload') then
                      me.curStatus = dispHelp.rangerCFunc('status', 'oload')
                    elseif anyStatusSet('gross') then     
                      me.curStatus = dispHelp.rangerCFunc('status', 'gross')
                    elseif anyStatusSet('net') then
                      me.curStatus = dispHelp.rangerCFunc('status', 'net')
                    else
                      me.curStatus = dispHelp.rangerCFunc('status', 'none')
                    end
                    
                    if anyStatusSet('motion') then
                      me.curMotion = dispHelp.rangerCFunc('motion', 'motion')
                    else
                      me.curMotion = dispHelp.rangerCFunc('motion', 'notmotion')
                    end
                    
                    if anyStatusSet('zero') then
                      me.curZero = dispHelp.rangerCFunc('zero', 'zero')
                    else
                      me.curZero = dispHelp.rangerCFunc('zero', 'notzero')
                    end
                    
                    if (dualRangeMode == 'single') then
                      me.curRange = dispHelp.rangerCFunc('range', 'none')
                    else
                      if anyStatusSet('range1') then
                        me.curRange = dispHelp.rangerCFunc('range', 'range1')
                      elseif anyStatusSet('range2') then
                        me.curRange = dispHelp.rangerCFunc('range', 'range2')
                      else
                        me.curRange = dispHelp.rangerCFunc('range', 'none')
                      end
                    end
                    
                    return me.transmit(false)
                    
                  end,
    setAnnun = function (...)
                    local me = displayTable[prefix]
                    local argi
                                      
                    for i,v in ipairs(arg) do
                      argi = canonical(v)
                      
                      if (argi == 'all') then 
                        me.curStatus = dispHelp.rangerCFunc('status', 'net')
                        me.curMotion = dispHelp.rangerCFunc('motion', 'motion')
                        me.curZero = dispHelp.rangerCFunc('zero', 'zero')
                        me.curRange = dispHelp.rangerCFunc('range', 'range1')
                      elseif (argi == 'net' ) then
                        me.curStatus = dispHelp.rangerCFunc('status', 'net')
                      elseif (argi == 'motion') then
                        me.curMotion = dispHelp.rangerCFunc('motion', 'motion')
                      elseif (argi == 'zero') then
                        me.curZero = dispHelp.rangerCFunc('zero', 'zero')
                      elseif (argi == 'range1') then
                        me.curRange = dispHelp.rangerCFunc('range', 'range1')
                      elseif (argi == 'range2') then
                        me.curRange = dispHelp.rangerCFunc('range', 'range2')
                      end                        
                    end                    
                    
                    return me.transmit(false)
                  end,
    clearAnnun = function (...)
                    local me = displayTable[prefix]
                    local argi
                                      
                    for i,v in ipairs(arg) do
                      argi = canonical(v)
                      
                      if (argi == 'all') then 
                        me.curStatus = dispHelp.rangerCFunc('status', 'gross')
                        me.curMotion = dispHelp.rangerCFunc('motion', 'notmotion')
                        me.curZero = dispHelp.rangerCFunc('zero', 'notzero')
                        me.curRange = dispHelp.rangerCFunc('range', 'none')  
                      elseif (argi == 'net' ) then
                        me.curStatus = dispHelp.rangerCFunc('status', 'gross')
                      elseif (argi == 'motion') then
                        me.curMotion = dispHelp.rangerCFunc('motion', 'notmotion')
                      elseif (argi == 'zero') then
                        me.curZero = dispHelp.rangerCFunc('zero', 'notzero')
                      elseif (argi == 'range1') then
                        me.curRange = dispHelp.rangerCFunc('range', 'none')
                      elseif (argi == 'range2') then
                        me.curRange = dispHelp.rangerCFunc('range', 'none')
                      end                        
                    end
                    
                    return me.transmit(false)
                  end, 
    writeUnits = function (units1, units2)
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
