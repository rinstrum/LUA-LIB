#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- Interactive snadbox for experimenting with Lua and our library
--
-- Direct command line access to library functions
--
-------------------------------------------------------------------------------

--=============================================================================
-- Some of the more commonly used modules as globals
rinApp = require 'rinApp'               -- load in the application framework
timers = require 'rinSystem.rinTimers'  -- load in some system timers
dbg    = require 'rinLibrary.rinDebug'  -- load in a debugger

--=============================================================================
-- Connect to the instrument you want to control
dwi = rinApp.addK400()                  -- local K401 instrument

function callback(name, result)
    local msg = 'call back ' .. name .. ':'
    return function(...) print(msg, ...) return result end
end

--=============================================================================
-- Main Application
--=============================================================================
rinApp.setUserTerminal(function(s)
    local ok, err = pcall(loadstring(s))
    if not ok then
        print(err)
	    return false
    end
    return true
end)

rinApp.run()
