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
    curMotion = dispHelp.rangerCFunc('motion', 'notmotion'),
    curZero = dispHelp.rangerCFunc('zero', 'notzero'),
    curRange = dispHelp.rangerCFunc('range', 'none'),
    curUnits = dispHelp.rangerCFunc('units', 'none'),
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
    --writeUnits = , -- Function here
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
