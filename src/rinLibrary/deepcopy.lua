-------------------------------------------------------------------------------
--- Depricated deep object copy.
-- A function that deeply copies an object.
-- @module rinLibrary.deepcopy
-- @author Pauli
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local dbg = require 'rinLibrary.rinDebug'
dbg.warn('deepcopy', "this mododule is depreated, use rinSysrinSystem.utilitiestils.deepcopy instead")

return require('rinSystem.utilities').deepcopy
