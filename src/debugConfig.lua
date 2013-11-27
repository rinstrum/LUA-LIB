-------------------------------------------------------------------------------
-- Default configuration for the debugger. This can be overridden if the user 
-- calls a script with rinapp with arguments
-- @module debugConfig
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local require = require

local logging = require "logging"

-- Set the logger type 
-- Refer to http://www.keplerproject.org/lualogging/manual.html
require "logging.console"
_M.logger = logging.console("%message\n")

-- Set the logger level
_M.level = logging.INFO

-- Set timestamp option (true if logging is to include date/time stamps)
_M.timestamp = true

return _M