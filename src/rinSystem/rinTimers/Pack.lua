-------------------------------------------------------------------------------
-- Wrapper for backwards compatibility
--
-- Instead use:
--     require 'rinSystem.rinTimers'
-- @module rinSystem.rinTimers.Pack
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local dbg = require "rinLibrary.rinDebug"

dbg.warn('rinTimers:', 'timers accessed via deprecated interface, use rinSystem.rinTimers')

return require('rinSystem.rinTimers')

