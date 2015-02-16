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
local lpeg = require "rinLibrary.lpeg"
local P, V = lpeg.P, lpeg.V
local spaces, stashName = lpeg.space^1, lpeg.alpha * lpeg.alnum^0
local inputFunction, inputBuffer = function() print'No command run yet.' end
local cmdTable, cmds

local function luaInput(s)
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

local function cmdHelp()
    print [[
again   to re-execute last successful command
clear   to erase pending input
exit    to exit the sandbox
help    for this help
list    list the currently entered command buffer

Anything else is taken as Lua input.
]]
end

local function cmdList()
    print(inputBuffer and ('Command buffer is:\n' .. inputBuffer .. '---') or
                            'No command buffer.')
end

local function cmdAgain()
    pcall(inputFunction)
end

local function cmdClear()
    inputBuffer = nil
    print'Cleared input.'
end

local function cmdStash(s)
    local f = inputFunction
    cmdTable.alias = P(s) / function() pcall(f) end + cmdTable.alias
    cmds = P(cmdTable)
end

cmdTable = {
            (V'cmd' + V'alias' + V'lua') + P(-1),
    lua =   P(1)^0 / luaInput,
    cmd =   P'help' / cmdHelp +
            P'list' / cmdList +
            P'exit' / rinApp.finish +
            P'again' / cmdAgain +
            P'clear' / cmdClear +
            P'stash' * spaces * (stashName / cmdStash),
    alias = P(false)
}
cmds = P(cmdTable)

rinApp.setUserTerminal(function(s)
    cmds:match(s)
    io.write(inputBuffer and '>> ' or '> ')
    io.flush(io.input())
    return true
end)

print"Enter 'help' for available commands."
io.write('> ')
io.flush(io.input())

rinApp.run()
