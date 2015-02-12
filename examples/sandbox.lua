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
device = rinApp.addK400()                  -- local K4xx instrument

function callback(name, result)
    local msg = 'call back ' .. name .. ':'
    return function(...) print(msg, ...) return result end
end

--=============================================================================
-- Main Application
--=============================================================================
local inputBuffer
rinApp.setUserTerminal(function(s)
    local prompt, save = '> ', nil
    if s ~= '' then
        local c = inputBuffer and (inputBuffer .. '\n' .. s) or s
        local f, err = loadstring(c)
        if f then
            pcall(f)
        elseif string.find(err, '<eof>') then
            prompt, save = '>> ', c
        else
            print('Error: ' .. err)
        end
    end
    io.write(prompt)
    io.flush(io.input())
    inputBuffer = save
    return true
end)

io.write('> ')
io.flush(io.input())

rinApp.run()
