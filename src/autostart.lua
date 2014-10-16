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

require 'posix'

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
    local running = true
    local count = 0

    while running do
        local s = time()
        local r = os.execute('cd ' .. directory .. ' && /usr/local/bin/lua ' .. main)
        if r == 0 then
            count = 0
        else
            local d = time() - s
            if d < threshold then
                count = count + 1
                if count > failure then
                    running = false
                end
            else
                count = 1
            end
        end
    end

    -- Only get here if something goes horribly wrong
    local rinApp = require 'rinApp'
    local usb = require "rinLibrary.rinUSB"
    local dev = rinApp.addK400('K401')
    local usbPath = nil

-------------------------------------------------------------------------------
-- Copy the execution directory to USB as a tar file
-- @local
    local function copyTo()
        local yr, mo, da = dev.RTCreadDate()
        local hr, mi, se = dev.RTCreadTime()
        local dest = string.format('%s/save-%s-%s%s%s%s%s%s.tar',
                                    usbPath, dev.getSerialNumber():gsub('%s+', ''),
                                    yr, mo, da, hr, mi, se)
        os.execute('tar cf ' .. dest .. ' ' .. directory)
        os.execute('sync')
        dev.write('topRight', 'DONE SAVE', 'time=1, clear')
        return true
    end

-------------------------------------------------------------------------------
-- Copy lua, ini, csv, ris and txt files from the USB to the execution directory
-- @local
    local function copyFrom()
        for _, s in pairs{ 'lua', 'luac', 'ini', 'csv', 'ris', 'txt' } do
            os.execute('cp '..usbPath..'/*.'..s..' '..directory..'/')
        end
        os.execute('sync')
        dev.write('topRight', 'DONE LOAD', 'time=1, clear')
        return true
    end

-------------------------------------------------------------------------------
-- Change the mutable display fields
-- @local
    local function updateDisplay()
        local f2, f3
        if usbPath ~= nil then
            dev.write('bottomLeft', 'READY')
            dev.write('bottomRight', 'F1 EXIT F2 USB> F3 >USB', 'align=right')
            f2, f3 = copyFrom, copyTo
        else
            dev.write('bottomLeft', 'WAIT USB')
            dev.write('bottomRight', 'F1 EXIT', 'align=right')
        end
        dev.setKeyCallback('f2', f2, 'short')
        dev.setKeyCallback('f3', f3, 'short')
    end

    dev.clearAnnunciators('all')
    dev.writeTopUnits('none')
    dev.writeBotUnits('none', 'none')
    dev.write('topRight', '')
    dev.write('topLeft', 'RECVRY')

    usb.setStorageAddedCallback(function(where)
        usbPath = where
        updateDisplay()
    end)

    usb.setStorageRemovedCallback(function()
        usbPath = nil
        updateDisplay()
    end)

    dev.setKeyCallback('f1', rinApp.finish, 'short')
    dev.setKeyGroupCallback('all', function() return true end)
    rinApp.addIdleEvent(updateDisplay)

    rinApp.run()
    os.execute('reboot')
end
