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

_M.REG_AUTO_OUT = 0xA205

-- NOTE: THIS HAS TRAFFIC LIGHT SUPPORT BUILT INTO ANNUNCIATORS THAT MUST BE DOCUMENTED

function _M.add(private, displayTable, prefix, address, port)

  local sock, err = socks.createTCPsocket(address, port or 10001, 0.001)
  
  if (sock == nil) then
    return displayTable, err
  end
  
  socks.addSocket(sock, function (sock)
                          local m, err = socks.readSocket(sock)
                          if err ~= nil then
                               socks.removeSocket(sock)
                          end
                        end)

  displayTable[prefix] = {
    remote = true,
    length = 6,
    reg = _M.REG_AUTO_OUT,
    strlen = dispHelp.strLenLCD,
    finalFormat = dispHelp.padDots,
    strsub = dispHelp.strSubLCD,
    curString = "       ", 
    curRed = false,
    curGreen = false,
    curStatus = dispHelp.rangerCFunc('status', 'none'),
    curMotion = dispHelp.rangerCFunc('motion', 'notmotion'),
    curZero = dispHelp.rangerCFunc('zero', 'notzero'),
    curRange = dispHelp.rangerCFunc('range', 'none'),
    curUnits1 = dispHelp.rangerCFunc('units', 'none'),
    curUnits2 = nil,
    mirrorStatus = false,
    writeStatus = function (...) dispHelp.writeStatus(displayTable[prefix], ...) end,
    setAnnun = function (...) 
                  dispHelp.setAnnun(displayTable[prefix], ...)
                  dispHelp.handleTraffic(displayTable[prefix], true, ...)
               end,
    clearAnnun = function (...)
                  dispHelp.clearAnnun(displayTable[prefix], ...)
                  dispHelp.handleTraffic(displayTable[prefix], false, ...)
               end,
    writeUnits = function (units1)
                    local val, e = dispHelp.rangerCFunc('units', units1)
                    
                    if (val == nil) then
                      return val, e
                    end
        
                    displayTable[prefix].curUnits1 = val
                    
                    return units1, nil
                  end,
    write = function (s, sync)
                  displayTable[prefix].curString = s
                end,
    sock = sock,
    transmit = function (sync)
                  local me = displayTable[prefix]
                  local toSend = dispHelp.frameRangerC(me, true)
                  return socks.writeSocket(sock, toSend)
                end
  }
  
  timers.addTimer(0.2, 0.2, displayTable[prefix].transmit, false)

  return displayTable
 
end

return _M
