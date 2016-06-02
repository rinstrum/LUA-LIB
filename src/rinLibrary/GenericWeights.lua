-------------------------------------------------------------------------------
--- Weight Query Functions.
--
-- Functions to read gross and net weights and tare.
--
-- These functions are not usually the ideal way to gather this
-- information.  Generally, it is better to use the streaming
-- support and to cache the current values of interest locally.  This
-- avoids pauses and delays when these values require access.
-- @module rinLibrary.Device.Weights
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
-- @treturn int Gross or net weight
-- @treturn string Error string if error received, nil otherwise
-- @see rinLibrary.Device.Stream.addStream
-- @see getGross
-- @see getNet
-- @usage
-- local weight = device.getGrossNet()
function _M.getGrossNet()
    return private.readReg 'grossnet'
end

-------------------------------------------------------------------------------
-- Get gross weight from instrument.
-- @treturn int Gross weight
-- @treturn string Error string if error received, nil otherwise
-- @see rinLibrary.Device.Stream.addStream
-- @see getNet
-- @see getAltGross
-- @usage
-- local gross = device.getGross()
function _M.getGross()
    return private.readReg 'gross'
end

-------------------------------------------------------------------------------
-- Get net weight from instrument.
-- @treturn int Net weight
-- @treturn string Error string if error received, nil otherwise
-- @see rinLibrary.Device.Stream.addStream
-- @see getGross
-- @see getAltNet
-- @usage
-- local net = device.getNet()
function _M.getNet()
    return private.readReg 'net'
end

-------------------------------------------------------------------------------
-- Get tare from instrument.
-- @treturn int Tare
-- @treturn string Error string if error received, nil otherwise
-- @see rinLibrary.Device.Stream.addStream
-- @see getNet
-- @see getGross
-- @usage
-- local tare = device.getTare()
function _M.getTare()
    return private.readReg 'tare'
end

-------------------------------------------------------------------------------
-- Get full scale reading from instrument.
-- @treturn int Full scale
-- @return error String if error received, nil otherwise
-- @usage
-- local fullScale = device.getFullScale()
function _M.getFullScale()
    return private.readReg 'fullscale'
end

-------------------------------------------------------------------------------
-- Get raw mV/V from instrument.
-- @treturn number mV/V
-- @treturn string Error string if error received, nil otherwise
-- @see rinLibrary.Device.Stream.addStream
-- @see getRawADC
-- @usage
-- local mvv = device.getMVV()
function _M.getMVV()
    return private.readReg 'absmvv'
end

-------------------------------------------------------------------------------
-- Get raw ADC reading from instrument.
-- @treturn int raw ADC reading
-- @treturn string Error string if error received, nil otherwise
-- @see rinLibrary.Device.Stream.addStream
-- @see getMVV
-- @usage
-- local rawAdc = device.getRawADC()
function _M.getRawADC()
    return private.readReg 'rawadc'
end

--- Traceable weight table
-- @table Traceable
-- @field valid Boolean, is traceable table valid or not?
-- @field id Traceable id
-- @field weight Weight displayed on screen
-- @field wightalt Weight in alternate units
-- @field tare Tare for traceable weight
-- @field pt Boolean for preset tare
-- @field year Year traceable was obtained
-- @field month Month traceable was obtained
-- @field day Day traceable was obtained
-- @field hour Hour traceable was obtained
-- @field minute Minute traceable was obtained
-- @field second Second traceable was obtained
-- @field crc CRC used to determine whether traceable weight table information is valid.

local traceableRegisters = {
    'valid', 'id', 'weight', 'weightalt', 'tare', 
    'pt', 'year', 'month', 'day', 'hour', 
    'minute', 'second'
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
-- @treturn Traceable Traceable weight table
-- @treturn string Error string if any error received, nil otherwise
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
    tab.valid = tab.valid == 1
    tab.pt = tab.pt == 1
    
    tab.crc = calcTableChecksum(tab, traceableRegisters)
  
    return  tab, err
end

-------------------------------------------------------------------------------
-- Check traceable weight data
-- @tparam Traceable traceable Traceable weight table
-- @treturn bool True if traceable table is valid, false otherwise
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
-- @treturn int alternative gross weight
-- @treturn string Error string if error received, nil otherwise
-- @see rinLibrary.Device.Stream.addStream
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
-- @treturn int alternative net weight
-- @treturn string Error string if error received, nil otherwise
-- @see rinLibrary.Device.Stream.addStream
-- @see getNet
-- @usage
-- local net = device.getAltNet()
    private.exposeFunction('getAltNet', private.nonbatching(true), function()
        return private.readReg 'altnet'
    end)
end)

end
