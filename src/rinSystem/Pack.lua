-------------------------------------------------------------------------------
-- Wrapper for backwards compatibility
--
-- Instead use:
--     require 'rinSystem'
-- @module rinSystem.Pack
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local dbg = require "rinLibrary.rinDebug"

dbg.warn('rinSystem:', 'system accessed via deprecated interface, use rinSystem')

return require('rinSystem')

