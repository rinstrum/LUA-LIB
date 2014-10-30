-------------------------------------------------------------------------------
--- USB Helper Infrastructure.
-- Support routines to provide a semi-standard interface to USB file copying
-- and package installation.
-- @module rinLibrary.K400USB
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local usb = require 'rinLibrary.rinUSB'
local dbg = require "rinLibrary.rinDebug"
local timers = require 'rinSystem.rinTimers'
local utils = require 'rinSystem.utilities'
local naming = require 'rinLibrary.namings'

local whenMap = {
    idle = 'idle',
    immediate = 'immediate',
    manual = 'manual'
}

--- When Setting Modes.
--
-- This setting determines when the automatic USB storage handler will operate.
--@table usbWhenMode
-- @field idle Called during the main loop after a USB storage device appears.
-- @field immediate Called immediately after a USB storage device appears.
-- @field manual Never called.

--- USB Storage Subsystem Parameters
--
-- The storage subsystem provides a number of call backs which allow control
-- over the copying and update processes.  Generally, you will only need
-- to specify a backup and an update call back.
-- @table usbActivateParameters
-- @field when Secify when the automatic USB storage handler is invoked.
-- @field new Call back when a new USB storage device becomes available.
-- The USB storage device's mount point path is passed to the call back.  This
-- call back can return a new when code that replaces the previous set when
-- code just for this USB storage device, returning nothing or nil will use
-- the normally defined when code.
-- @field removed Call back when a USB storage device is removed.  No arguments
-- are passed to the call back.
-- @field backup Call back to backup the module to the USB and save logs etc.
-- The USB storage device's mount point path is passed to the call back.
-- @field update Call back to update the module from the USB storage device.
-- The USB storage device's mount point path is passed to the call back.
-- This call back can return true to indicate that a reboot is required.
-- @field unmount Call back when the USB storage device is about to be unmounted.
-- The USB storage device's mount point path is passed to the call back.
-- @see usbWhenMode

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)
    local newUsbCB, removedUsbCB, backupUsbCB, updateUsbCB, unmountUsbCB
    local mountPoint
    local mustReboot, usbRemoved = false, false
    local when = 'idle'

-------------------------------------------------------------------------------
-- Display a message to the screen in a standard manner.
-- @param m Message to display
-- @param params Optional display parameters
-- @local
    local function message(m, params)
        params = params or 'align=right, sync'
        _M.write('topLeft', 'USB')
        _M.write('bottomLeft', m, params)
    end

-------------------------------------------------------------------------------
-- Unmount the attached USB storage device.
--
-- Appropraite messages are displayed on the display during this process.
--
-- You won't need to call this unless you are taking control of the USB storage
-- handling yourself.
-- @usage
-- device.usbUnmount('/dev/sda1')
    function _M.usbUnmount()
        message('UNMOUNT')
        utils.call(unmountUsbCB, mountPoint)
        usb.unmount(mountPoint)
        _M.write('bottomLeft', 'REMOVE', 'align=right')
    end

-------------------------------------------------------------------------------
-- Display the writing backup messages and call the user's call back.
--
-- Appropraite messages are displayed on the display during this process.
--
-- You won't need to call this unless you are taking control of the USB storage
-- handling yourself.
-- @usage
-- device.usbBackup()
    function _M.usbBackup()
        message('WRITING')
        utils.call(backupUsbCB, mountPoint)
    end

-------------------------------------------------------------------------------
-- Display the reading / update messages and call the user's call back.
--
-- Appropraite messages are displayed on the display during this process.
--
-- You won't need to call this unless you are taking control of the USB storage
-- handling yourself.
-- @usage
-- device.usbUpdate()
    function _M.usbUpdate()
        message('READING')
        utils.call(updateUsbCB, mountPoint)
    end

-------------------------------------------------------------------------------
-- Indicate that a reboot is required when the USB storage device is unmounted.
--
-- You generally won't need to call this because the return code from your
-- update routine sets this directly.
-- @see usbReboot
-- @usage
-- device.usbRebootRequired()
    function _M.usbRebootRequired()
        mustReboot = true
    end

-------------------------------------------------------------------------------
-- Display the reboot message and reboot the module and display.
--
-- Appropraite messages are displayed on the display during this process.
--
-- You won't need to call this unless you are taking control of the USB storage
-- handling yourself.
-- @see usbRebootRequired
-- @usage
-- device.usbReboot()
    function _M.usbReboot()
        _M.buzz(3) -- "triple beep" on reboot
        message('REBOOT')
        _M.restart('all')
    end

-------------------------------------------------------------------------------
-- Set when the automatic USB handler is invoked.
--
-- You generally don't need to call this directly, the when setting can be
-- specified when activing the storage helper subsystem.
-- @param w When ('idle', 'immediate', 'manual')
-- @see usbActivateStorage
-- @see usbWhenMode
-- @usage
-- device.usbSetWhen('immediate')
    function _M.usbSetWhen(w)
        when = naming.convertNameToValue(w, whenMap, 'idle')
    end

-------------------------------------------------------------------------------
-- Copy things from the USB device, optionally schedule a reboot.
-- @local
    local function copyFrom()
        if _M.usbUpdate() == true then
            _M.usbRebootRequired()
        end
    end

-------------------------------------------------------------------------------
-- USB storage save/restore handler
-- @param mountPoint Mount point for the USB storage device
-- @local
    local function newUsb(mountPoint)
        local mode, restoreDisplay = _M.lcdControl('lua'), _M.saveDisplay()
        local savedKeyHandlers = _M.saveKeyCallbacks(false)
        _M.setKeyGroupCallback('all', function() return true end)

        message('FOUND', 'time=2, wait, clear')

        _M.createMenu { 'USB STORAGE', loop=true }
            .item { 'EJECT', secondary='USB', exit=true,  }
            .item { 'FROM', secondary='USB', exit=true, run=copyFrom, enabled=updateUsbCB ~= nil }
            .item { 'TO', secondary='USB', exit=true, run=_M.usbBackup, enabled=backupUsbCB ~= nil }
            .run()

        _M.usbUnmount()
        _M.app.delayUntil(function() return usbRemoved end)
        savedKeyHandlers()
        restoreDisplay()
        _M.lcdControl(mode)
    end

-------------------------------------------------------------------------------
-- Call back for USB registration events
-- @param loc Mount point for new USB storage device
-- @local
    local function added(loc)
        mountPoint, mustReboot, usbRemoved = loc, false, false
        _M.buzz(1) -- "single beep" on USB registration

        local w = utils.call(newUsbCB, loc) or when
        if w == 'immediate' then
            newUsb(loc)
        elseif w == 'idle' then
            _M.app.addIdleEvent(newUsb, loc)
        end
    end

-------------------------------------------------------------------------------
-- Call back for USB deregistration events
-- @local
    local function removed()
        _M.buzz(2) -- "double beep" when USB is unplugged
        utils.call(removedUsbCB)
        usbRemoved = true

        if mustReboot then
            _M.usbReboot()
        end
        mountPoint, mustReboot = nil, false
    end

-------------------------------------------------------------------------------
-- Activate the USB storage subsystem.
-- @param args Parameters for the subsystem
-- @see usbDeactiveStorage
-- @see usbActivateParameters
    function _M.usbActivateStorage(args)
        newUsbCB = args.new             utils.checkCallback(newUsbCB)
        removedUsbCB = args.removed     utils.checkCallback(removedUsbCB)
        backupUsbCB = args.backup       utils.checkCallback(backupUsbCB)
        updateUsbCB = args.update       utils.checkCallback(updateUsbCB)
        unmountUsbCB = args.unmount     utils.checkCallback(unmountUsbCB)
        _M.usbSetWhen(args.when)

        usb.setStorageAddedCallback(added)
        usb.setStorageRemovedCallback(removed)
    end

-------------------------------------------------------------------------------
-- Deactivate the USB storage subsystem.
-- @see usbActivateStorage
    function _M.usbDeactiveStorage()
        usb.setStorageAddedCallback(nil)
        usb.setStorageRemovedCallback(nil)
    end
end
