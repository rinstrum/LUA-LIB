-------------------------------------------------------------------------------
--- Axle scle functions.
-- Functions to support the K422 Axle Weigher
-- @module rinLibrary.Device.Axle
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local naming = require 'rinLibrary.namings'

return function (_M, private, deprecated)

local REG_DYNAMIC_MODE      = 0xA708

private.registerDeviceInitialiser(function()
    private.addRegisters{
        dynamic_scale           = private.k422(0xA713),
        axle_timeout            = private.k422(0xA705)
    }
end)

--- Axle Modes.
--@table axleModes
-- @field dynamic Dynamic axle detection
-- @field off No axle detection
-- @field static Static axle detection
local axleModeOptions = {
    dynamic = 0,    static = 1,     off = 2
}

-------------------------------------------------------------------------------
-- Function to change the axle detection mode
-- @function setAxleMode
-- @param mode Axle mode to change to
-- @see axleModes
-- @usage
-- device.setAxleMode('off')
-- device.selectOption(...)
-- device.setAxleMode('dynamic')
private.registerDeviceInitialiser(function()
    private.exposeFunction('setAxleMode', private.k422(true), function(mode)
        local s = naming.convertNameToValue(mode, axleModeOptions, 0, 0, 2)
        private.writeReg(REG_DYNAMIC_MODE, s)
    end)
end)

end
