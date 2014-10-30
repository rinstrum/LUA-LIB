-------------------------------------------------------------------------------
-- Wrapper for backwards compatibility.
--
-- Instead use:
--     require 'rinSystem.rinSockets'
-- @module rinSystem.rinSockets.Pack
-- @author Pauli
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local dbg = require "rinLibrary.rinDebug"

dbg.warn('rinSockets:', 'sockets accessed via deprecated interface, use rinSystem.rinSockets')

return require('rinSystem.rinSockets')

