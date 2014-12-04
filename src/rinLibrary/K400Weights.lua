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
-- @return err error string if error received, nil otherwise
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
-- @return err error string if error received, nil otherwise
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
-- @return err error string if error received, nil otherwise
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
-- @return err error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getNet
-- @see getGross
-- @usage
-- local tare = getTare()
function _M.getTare()
    return private.readReg 'tare'
end

private.registerDeviceInitialiser(function()
-------------------------------------------------------------------------------
-- Get alternative gross weight from instrument.
--
-- This function is only available on non batching units.
-- @function getAltGross
-- @return alternative gross weight
-- @return err error string if error received, nil otherwise
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
-- @return err error string if error received, nil otherwise
-- @see rinLibrary.K400Stream.addStream
-- @see getNet
-- @usage
-- local net = getAltNet()
    private.exposeFunction('getAltNet', private.nonbatching(true), function()
        return private.readReg 'altnet'
    end)
end)

end
