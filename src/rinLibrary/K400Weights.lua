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
-- local weight = getGrossNet()
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
-- local gross = getGross()
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
-- local net = getNet()
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
-- local tare = getTare()
function _M.getTare()
    return private.readReg 'tare'
end

-------------------------------------------------------------------------------
-- Get full scale reading from instrument.
-- @return full scale
-- @return error string if error received, nil otherwise
-- @usage
-- local fullScale = getFullScale()
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
-- local mvv = getMVV()
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
-- local rawAdc = getRawADC()
function _M.getRawADC()
    return private.readReg 'rawadc'
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
-- local gross = getAltGross()
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
-- local net = getAltNet()
    private.exposeFunction('getAltNet', private.nonbatching(true), function()
        return private.readReg 'altnet'
    end)
end)

end
