-------------------------------------------------------------------------------
-- Library for K400 application support.
-- Provides wrappers for all device services
-- @module rinLibrary.K400
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

-- submodules are merged in as follows:
-- rinCon
-- K400Reg
-- K400Util
-- K400Stream
-- K400Status
-- K400Keys
-- K400LCD
-- K400Dialog
-- K400RTC
-- K400Analog
-- K400Setpoint
-- K400Print
-- K400Command

-- build rest of K400 on top of rinCon
local tmp = require "rinLibrary.K400Command"
local _M = tmp  
package.loaded["rinLibrary.K400Command"] = nil

return _M
