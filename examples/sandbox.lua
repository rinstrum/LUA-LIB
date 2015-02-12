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
local inputFunction, inputBuffer = function() print'No command run yet.' end
local commands = setmetatable({
    help = function()
        print [[
again   to re-execute last successful command
clear   to erase pending input
exit    to exit the sandbox
help    for this help
list    list the currently entered command buffer

Anything else is taken as Lua input.
]]
    end,

    clear = function()
        inputBuffer = nil
        print'Cleared input.'
    end,

    list = function()
        print(inputBuffer and ('Command buffer is:\n' .. inputBuffer) or 'No command buffer.')
    end,

    again = function()  pcall(inputFunction)    end,
    exit = rinApp.finish
}, {
    __index = function(t, s)
        return function()
            local c, save = (inputBuffer or '') .. s
            local f, err = loadstring(c)
            if err == nil then
                local success, e = pcall(f)
                if success then
                    inputFunction = f
                else
                    print('Execute error: ' .. e)
                end
            elseif string.find(err, '<eof>') then
                save = c .. '\n'
            else
                print('Parse error: ' .. err)
            end
            inputBuffer = save
        end
    end
})

rinApp.setUserTerminal(function(s)
    commands[s]()
    io.write(inputBuffer and '>> ' or '> ')
    io.flush(io.input())
    return true
end)

print"Enter 'help' for available commands."
io.write('> ')
io.flush(io.input())

rinApp.run()
