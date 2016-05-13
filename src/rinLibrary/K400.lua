-------------------------------------------------------------------------------
-- Library for K400 application support.
-- Provides wrappers for all device services
-- @module rinLibrary.K400
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local loader = require('rinLibrary.deviceLoader')

-- submodules are merged in as follows (and in this order):
local modules = {
    "rinCon",
    "K400Reg",
    "GenericReg",
    "GenericUtil",
    "GenericStream",
    "GenericStatus",
    "K400Axle",
    "GenericKeys",
    "GenericBuzz",
    "GenericLCD",
    "K400Dialog",
    "GenericFSM",
    "K400Menu",
    "GenericRTC",
    "GenericAnalog",
    "K400Batch",
    "K400Setpoint",
    "K400Print",
    "K400Command",
    "K400Users",
    "K400Passcode",
    "K400USB",
    "GenericWeights"
}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Module factory function begins here
return function (model)
    return loader(model, "k400", modules)
end
