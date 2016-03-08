-------------------------------------------------------------------------------
--- Weight Query Functions.
--
-- Functions to read gross and net weights and tare.
--
-- These functions are not usually the ideal way to gather this
-- information.  Generally, it is better to use the streaming
-- support and to cache the current values of interest locally.  This
-- avoids pauses and delays when these values require access.
-- @module rinLibrary.K400Weights
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local ccitt = require "rinLibrary.rinCCITT"

local pairs = pairs
local tostring = tostring

return function (_M, private, deprecated)
-------------------------------------------------------------------------------
-- Get gross or net weight from instrument.
--
-- This is the value that is usually displayed in the top left of the screen.
-- @return gross or net weight
-- @return error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getGross
-- @see getNet
-- @usage
-- local weight = device.getGrossNet()
function _M.getGrossNet()
    return private.readReg 'grossnet'
end

-------------------------------------------------------------------------------
-- Get gross weight from instrument.
-- @return gross weight
-- @return error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getNet
-- @see getAltGross
-- @usage
-- local gross = device.getGross()
function _M.getGross()
    return private.readReg 'gross'
end

-------------------------------------------------------------------------------
-- Get net weight from instrument.
-- @return net weight
-- @return error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getGross
-- @see getAltNet
-- @usage
-- local net = device.getNet()
function _M.getNet()
    return private.readReg 'net'
end

-------------------------------------------------------------------------------
-- Get tare from instrument.
-- @return tare
-- @return error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getNet
-- @see getGross
-- @usage
-- local tare = device.getTare()
function _M.getTare()
    return private.readReg 'tare'
end

-------------------------------------------------------------------------------
-- Get full scale reading from instrument.
-- @return full scale
-- @return error string if error received, nil otherwise
-- @usage
-- local fullScale = device.getFullScale()
function _M.getFullScale()
    return private.readReg 'fullscale'
end

-------------------------------------------------------------------------------
-- Get raw mV/V from instrument.
-- @return mV/V
-- @return error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getRawADC
-- @usage
-- local mvv = device.getMVV()
function _M.getMVV()
    return private.readReg 'absmvv'
end

-------------------------------------------------------------------------------
-- Get raw ADC reading from instrument.
-- @return raw ADC reading
-- @return error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getMVV
-- @usage
-- local rawAdc = device.getRawADC()
function _M.getRawADC()
    return private.readReg 'rawadc'
end

local traceableRegisters = {
    'tracevalid', 'traceid', 'traceweight', 'traceweightalt', 'tracetare', 
    'tracept', 'traceyear', 'tracemonth', 'traceday', 'tracehour', 
    'traceminute', 'tracesecond'
}

-------------------------------------------------------------------------------
-- Calculate the checksum of a table, table keys will be processed by keyorder
-- @return Checksum
-- @local
local function calcTableChecksum(tbl, keyorder)
  local str = ""
  
  for i = 1,#keyorder do
    str = str .. keyorder[i] .. tostring(tbl[keyorder[i]])
  end
  
  return ccitt(str)
end

-------------------------------------------------------------------------------
-- Get traceable weight data
-- @return Table containing traceable ADC data. Keys: 'tracevalid', 'traceid', 
-- 'traceweight', 'traceweightalt', 'tracetare', 
-- 'tracept', 'traceyear', 'tracemonth', 'traceday', 'tracehour', 
-- 'traceminute', 'tracesecond'. Converts flags to booleans.
-- @return error string if any error received, nil otherwise
-- @see checkTraceable
-- @usage
-- local traceable = device.getTraceable()
function _M.getTraceable()
    local tab = {}
    local err = nil
    
    -- Read each register
    for k, register in pairs(traceableRegisters) do
      tab[register], err = private.readReg(register)
      
      -- Add the failed register to the error message if it exists
      if (err ~= nil) then
        err = register .. ": " .. err
        break
      end
    end
    
    -- Convert flags to booleans.
    tab.tracevalid = tab.tracevalid == 1
    tab.tracept = tab.tracept == 1
    
    tab.crc = calcTableChecksum(tab, traceableRegisters)
  
    return  tab, err
end

-------------------------------------------------------------------------------
-- Check traceable weight data
-- @return True if traceable table is valid, false otherwise
-- @see getTraceable
-- @usage
-- local traceable = device.getTraceable()
-- assert(device.checkTraceable(traceable) == true)
function _M.checkTraceable(traceable)
  return calcTableChecksum(traceable, traceableRegisters) == traceable.crc
end

private.registerDeviceInitialiser(function()
-------------------------------------------------------------------------------
-- Get alternative gross weight from instrument.
--
-- This function is only available on non batching units.
-- @function getAltGross
-- @return alternative gross weight
-- @return error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getGross
-- @usage
-- local gross = device.getAltGross()
    private.exposeFunction('getAltGross', private.nonbatching(true), function()
        return private.readReg 'altgross'
    end)

-------------------------------------------------------------------------------
-- Get alternative net weight from instrument.
--
-- This function is only available on non batching units.
-- @function getAltNet
-- @return alternative net weight
-- @return error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getNet
-- @usage
-- local net = device.getAltNet()
    private.exposeFunction('getAltNet', private.nonbatching(true), function()
        return private.readReg 'altnet'
    end)
end)

end
