-------------------------------------------------------------------------------
-- D840 LCD Services
-- Functions to add the D840 LCD to the display fields
-- @module rinLibrary.display.D840
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local ipairs = ipairs

local dispHelp = require "rinLibrary.displayHelper"
local socks = require "rinSystem.rinSockets"
local timers = require 'rinSystem.rinTimers'

_M.REG_AUTO_OUT = 4

-------------------------------------------------------------------------------
-- Add the D840 to the displayTable. This will add a remote display field to 
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
    length = 7,
    reg = settings.reg+ _M.REG_AUTO_OUT,
    strlen = dispHelp.strLenLCD,
    finalFormat = dispHelp.padDots,
    strsub = dispHelp.strSubLCD,
    curString = "       ", 
    curRed = false,
    curGreen = false,
    curStatus = dispHelp.rangerCFunc('status', 'none'),
    curMotion = dispHelp.rangerCFunc('motion', 'notmotion'),
    curCoz = dispHelp.rangerCFunc('coz', 'notcoz'),
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
                  dispHelp.handleTraffic(displayTable[prefix], true, ...)
                  displayTable[prefix].transmit(false)
               end,
    clearAnnun = function (...)
                  dispHelp.clearAnnun(displayTable[prefix], ...)
                  dispHelp.handleTraffic(displayTable[prefix], false, ...)
                  displayTable[prefix].transmit(false)
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
                  displayTable[prefix].transmit(false)
                end,
    transmit = function (sync)
                 local me = displayTable[prefix]
                 local toSend = dispHelp.frameRangerC(me)
                 return dispHelp.writeRegHex(private, sync, me.reg, toSend)
               end
  }
  
  if (settings and settings.type == 'usb') then
    dispHelp.addUSB(displayTable[prefix])
  elseif (settings and settings.type == 'network') then
    local me = displayTable[prefix]
    local err
  
    me.sock, err = socks.createTCPsocket(settings.addr, settings.port or 10001, 0.001)

    if (me.sock == nil) then
      return displayTable, err
    end
    
    me.transmit = function (sync)
      local toSend = dispHelp.frameRangerC(me, true)
      return socks.writeSocket(me.sock, toSend)
    end
    
    socks.addSocket(me.sock, function (sock)
                            local m, err = socks.readSocket(sock)
                            if err ~= nil then
                                 socks.removeSocket(sock)
                            end
                          end)
    
    
    timers.addTimer(0.2, 0.2, displayTable[prefix].transmit, false)
  end

  return displayTable
 
end

return _M
