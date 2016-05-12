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
    "C500Dialog", 
    "GenericFSM",
    "GenericWeights",
}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Module factory function begins here
return function (model)
    return loader(model, "c500", modules)
end
