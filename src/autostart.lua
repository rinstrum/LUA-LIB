-------------------------------------------------------------------------------
--- Autostart support and failure recovery.
--
-- This can never be called from an application, it exists to start applications
-- only.
--
-- @module autostart
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local posix = require 'posix'
local utils = require 'rinSystem.utilities'

local threshold = 30        -- Seconds running to consider the start a failure
local failure = 3           -- Number of sequential failures before terminating

-------------------------------------------------------------------------------
-- Return a current time.  This isn't fixed to any specific base and is only
-- useful for determing time differences.
-- @return Monotonic time from arbitrary base
-- @local
local function time()
    local s, n = posix.clock_gettime "monotonic"
    return s + n * 0.000000001
end

return function(directory, main)
    local count = 0

    while count <= failure do
        local s = time()
        local r = os.execute('cd ' .. directory .. ' && /usr/local/bin/lua ' .. main)
        if r == 0 then
            count = 0
        else
            if time() - s < threshold then
                count = count + 1
            else
                count = 1
            end
        end
    end

    -- Only get here if something goes horribly wrong
    local rinApp = require 'rinApp'
    local usb = require "rinLibrary.rinUSB"
    local dev = rinApp.addK400('K401')
    local usbPath, usbPackages = nil, nil

-------------------------------------------------------------------------------
-- Convert a string into a case insensitive glob string
-- @param s String
-- @return Glob string
-- @local
    local function mix(s)
        local r = {}
        for i = 1, #s do
            local c = s:sub(i, i)
            local cu, cl = string.upper(c), string.lower(c)
            table.insert(r, (cu == cl) and c or ('['..cu..cl..']'))
        end
        return table.concat(r)
    end

-------------------------------------------------------------------------------
-- Copy the execution directory to USB as a tar file
-- @local
    local function copyTo()
        dev.write('topRight', 'SAVE', 'wait, time=.3')
        local yr, mo, da = dev.RTCreadDate()
        local hr, mi, se = dev.RTCreadTime()
        local dest = string.format('%s/save-%s-%s%s%s%s%s%s.tar',
                                    usbPath, dev.getSerialNumber():gsub('%s+', ''),
                                    yr, mo, da, hr, mi, se)
        os.execute('tar cf ' .. dest .. ' ' .. directory)
        utils.sync()
        dev.write('topRight', 'DONE SAVE', 'time=1, clear')
        return true
    end

-------------------------------------------------------------------------------
-- Copy lua, ini, csv, ris and txt files from the USB to the execution directory
-- @local
    local function copyFrom()
        dev.write('topRight', 'LOAD', 'wait, time=.3')
        for _, s in pairs{ 'lua', 'luac', 'ini', 'csv', 'ris', 'txt' } do
            os.execute('cp '..usbPath..'/*.'..mix(s)..' '..directory..'/')
        end
        utils.sync()
        dev.write('topRight', 'DONE LOAD', 'time=1, clear')
        return true
    end

-------------------------------------------------------------------------------
-- Install all available packages from the USB
-- @local
    local function installPackages()
        dev.write('topRight', 'PKGS', 'wait, time=.3')
        for _, pkg in pairs(usbPackages) do
            os.execute('/usr/local/bin/rinfwupgrade ' .. pkg)
        end
        -- Package installation kills the Lua infrastructure so reboot now
        utils.reboot()
    end

-------------------------------------------------------------------------------
-- Change the mutable display fields
-- @local
    local function updateDisplay()
        local f2, f3, f4
        if usbPath ~= nil then
            local prompt = 'F1 EXIT F2 USB> F3 >USB'
            if usbPackages then
                prompt = prompt .. ' OK PKGS'
                f4 = installPackages
            end
            dev.write('bottomLeft', 'READY')
            dev.write('bottomRight', prompt, 'align=right')
            f2, f3 = copyFrom, copyTo
        else
            dev.write('bottomLeft', 'WAIT USB')
            dev.write('bottomRight', 'F1 EXIT', 'align=right')
        end
        dev.setKeyCallback('f2', f2, 'short')
        dev.setKeyCallback('f3', f3, 'short')
        dev.setKeyCallback('ok', f4, 'short')
    end

    dev.clearAnnunciators('all')
    dev.writeTopUnits('none')
    dev.writeBotUnits('none', 'none')
    dev.write('topRight', '')
    dev.write('topLeft', 'RECVRY')

    usb.setStorageAddedCallback(function(where)
        usbPath = where
        usbPackages = posix.glob(where .. '/*.[oOrR][Pp][kK]')
        local recover = posix.glob(where .. mix('/recovery.lua'))
        if recover then
            dev.write('bottomRight', #recover > 1 and 'SCRIPTS' or 'SCRIPT')
            dev.write('bottomLeft', 'RUNNING', 'wait, time=.3, align=right')
            for _, s in pairs(recover) do
                os.execute('/usr/local/bin/lua ' .. s)
            end
        end
        updateDisplay()
    end)

    usb.setStorageRemovedCallback(function()
        usbPath = nil
        usbPackages = nil
        updateDisplay()
    end)

    dev.setKeyCallback('f1', rinApp.finish, 'short')
    dev.setKeyGroupCallback('all', function() return true end)
    rinApp.addIdleEvent(updateDisplay)

    rinApp.run()
    utils.reboot()
end
