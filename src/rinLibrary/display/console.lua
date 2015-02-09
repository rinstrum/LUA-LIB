-------------------------------------------------------------------------------
-- Console Services
-- Functions to add the console to the display fields
-- @module rinLibrary.display.console
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local len = len
local print = print
local string = string

local dispHelp = require "rinLibrary.displayHelper"

function _M.add(private, displayTable, prefix)
  
  displayTable[prefix .. "console"] = {
    remote = true,
    length = 80,
    rightJustify = function(s) return string.format("%-80s", s) end,
    strlen = function (s) return #s end,
    finalFormat = function (s) return s end,
    strsub = string.sub,
    saveAuto = 0,
    write = function(s, sync) print(s) end,
    transmit = function() end,
    writeUnits = function() end,
    setAnnun = function() end,
    clearAnnun = function() end,
    rotWait = function() end, 
  }
  
  return displayTable 
  
end

return _M
