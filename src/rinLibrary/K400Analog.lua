-------------------------------------------------------------------------------
--- Analogue Functions.
-- Functions to control M4401 analogue output
-- @module rinLibrary.K400Analog
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local math = math
local bit32 = require "bit"

-- build rest of K400 on top of rinCon
local tmp = require "rinLibrary.K400RTC"
local _M = tmp  
package.loaded["rinLibrary.K400RTC"] = nil

-------------------------------------------------------------------------------
--- Analogue Output Control.
-- Functions to configure and control the analogue output module
-- @section analogue

_M.REG_ANALOGUE_DATA = 0x0323
_M.REG_ANALOGUE_TYPE = 0xA801
_M.REG_ANALOGUE_CLIP = 0xA806
_M.REG_ANALOGUE_SOURCE = 0xA805  -- must be set to option 3 "COMMS" if we are to control it via the comms
  
_M.CUR = 0
_M.VOLT = 1

_M.curAnalogType = -1 

_M.ANALOG_COMMS = 3
-------------------------------------------------------------------------------
-- Set the analog output type
-- @param src Source for output.  
-- Must be set to ANALOG_COMMS to control directly
function _M.setAnalogSource(src)
   _M.sendRegWait(_M.CMD_WRFINALDEC,
                _M.REG_ANALOGUE_SOURCE,
                src)
  _M.saveSettings()                
end
                                         
-------------------------------------------------------------------------------
-- Set the analog output type
-- @param typ Type for output (.CUR or .VOLT)
function _M.setAnalogType(typ)
    local prev = _M.curAnalogType
    
    if typ == _M.CUR then
        _M.curAnalogType = _M.CUR
    else
        _M.curAnalogType = _M.VOLT
    end  
    
    if _M.curAnalogType ~= prev then 
        _M.sendRegWait(_M.CMD_WRFINALDEC,
                _M.REG_ANALOGUE_TYPE,
                _M.curAnalogType) 
    end
end   

-------------------------------------------------------------------------------
-- Control behaviour of analog output outside of normal range.
-- If clip is active then output will be clipped to the nominal range 
-- otherwise the output will drive to the limit of the hardware
-- @function setAnalogClip
-- @param c 0 for clipping disabled, 1 for clipping enabled
_M.setAnalogClip = _M.preconfigureMsg(  _M.REG_ANALOGUE_CLIP, 
                                        _M.CMD_WRFINALDEC, "noReply")
-------------------------------------------------------------------------------
-- Sets the analog output to minimum 0 through to maximum 50,000
-- @param raw value in raw counts (0..50000)
function _M.setAnalogRaw(raw)
   if _M.lastAnalogue ~= raw then 
       _M.sendReg(_M.CMD_WRFINALDEC, _M.REG_ANALOGUE_DATA, raw)
       _M.lastAnalogue = raw
   end    
end                                         
-------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0 through to maximum 1.0
-- @param val value 0.0 to 1.0
function _M.setAnalogVal(val)
   _M.setAnalogRaw(math.floor((50000*val)+0.5))
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0% through to maximum 100%
-- @param val value 0 to 100 %
function _M.setAnalogPC(val)
  val = val / 100
  _M.setAnalogVal(val)
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0V through to maximum 10.0V
-- @param val value 0.0 to 10.0
function _M.setAnalogVolt(val)
  _M.setAnalogType(_M.VOLT)
  val = val / 10 
 _M.setAnalogVal(val)
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 4.0 through to maximum 20.0 mA
-- @param val value 4.0 to 20.0
function _M.setAnalogCur(val)
  _M.setAnalogType(_M.CUR)
  val = (val - 4)/16
 _M.setAnalogVal(val)
end

return _M
