-------------------------------------------------------------------------------
-- Library for C500 application support.
-- Provides wrappers for all device services
-- @module rinLibrary.C500
-- @author Merrick
-- @copyright 2016 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local loader = require('rinLibrary.deviceLoader')

-- submodules are merged in as follows (and in this order):
local modules = {
    "rinCon",
    "C500Reg",
    "GenericReg",
    "GenericUtil",
    "GenericStream",
    "GenericStatus",
    "GenericKeys",
    "GenericBuzz",
    "GenericLCD",
    "GenericRTC",
    "GenericAnalog",
    "C500Dialog", 
    "GenericFSM",
    "GenericWeights",
    
    -- Not done on C500
    --K400Axle (not done on C500)
    --K400Menu (too complicated for now, and not widely used)
    --K400Batch (recode batching entirely)
    --K400Print (This will all be moved to lua)
    --K400Users (no need in C500)
    
    -- To do
    -- "K400Setpoint", (gut this)
    -- "K400Print",
    -- "K400Command",
    -- "K400Passcode", (wait for Sean to do registers)
    -- "K400USB", (wait for USB hw supprt)
}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Module factory function begins here
return function (model)
    return loader(model, "c500", modules)
end
