-------------------------------------------------------------------------------
--- USB Functions.
-- Functions to detect and mount USB devices.
-- @module rinLibrary.rinUSB
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local usb = require "devicemounter"
local socks = require "rinSystem.rinSockets.Pack"
local dbg = require "rinLibrary.rinDebug"
local rs232 = require "luars232"
local ev_lib = require "ev_lib"
local kb_lib = require "kb_lib"
local utils = require 'rinSystem.utilities'

local userUSBRegisterCallback = nil
local userUSBEventCallback = nil
local userUSBKBDCallback = nil
local libUSBSerialCallback = nil
local eventDevices = {}

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB device change is detected
-- @param callback Callback function takes event table as a parameter
-- @return The previous callback
-- @usage
-- local usb = require 'rinLibrary.rinUSB'
--
-- function registerCB(t)
--     for _, v in pairs(t) do
--         print('register:', t[1])
--         print('    what:', t[2])   -- 'added' or 'removed'
--         print('    whom:', t[3])
--     end
-- end
-- usb.setUSBRegisterCallback(registerCB)
function _M.setUSBRegisterCallback(callback)
    utils.checkCallback(callback)
    local r = userUSBRegisterCallback
    userUSBRegisterCallback = callback
    return r
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever a USB device change is detected
-- @return current callback
-- @usage
-- local usb = require 'rinLibrary.rinUSB'
--
-- if usb.getUSBRegisterCallback() == nil then
--     print('No USB register callback installed')
-- end
function _M.getUSBRegisterCallback()
    return userUSBRegisterCallback
end

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB device event is detected
-- @param callback Callback function takes event table as a parameter
-- @return The previous callback
-- @usage
-- local usb = require 'rinLibrary.rinUSB'
-- local input = require "linux.input"
--
-- function eventCB(ev)
--     if ev.type == input.EV_SYN and ev.code == input.SYN_CONFIG then
--         print "Event: -------------- Config Sync ------------ "
--     elseif ev.type == input.EV_SYN and ev.code == input.SYN_REPORT then
--         print "Event: -------------- Report Sync ------------ "
--     elseif ev.type == input.EV_MSC and (ev.code == input.MSC_RAW or ev.code == input.MSC_SCAN) then
--         print(string.format("Event: type %d (%s), code %d (%s), value %02x",
--                 ev.type, ev_lib.events[ev.type],
--                 ev.code, ev_lib.names[ev.type][ev.code],
--                 ev.value))
--     else
--         print(string.format("Event: type %d (%s), code %d (%s), value %d",
--                 ev.type, ev_lib.events[ev.type],
--                 ev.code, ev_lib.names[ev.type][ev.code],
--                 ev.value))
--     end
-- end
-- usb.setUSBEventCallback(eventCB)
function _M.setUSBEventCallback(callback)
    utils.checkCallback(callback)
    local r = userUSBEventCallback
    userUSBEventCallback = callback
    return r
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever a USB device event is detected
-- @return current callback
-- @usage
-- local usb = require 'rinLibrary.rinUSB'
--
-- if usb.getUSBEventCallback() == nil then
--     print('No USB user event callback installed')
-- end
function _M.getUSBEventCallback()
    return userUSBEventCallback
end

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB Keyboard event is processed
-- @param callback Callback function takes key string as a parameter
-- @return The previous callback
-- @usage
-- local usb = require 'rinLibrary.rinUSB'
--
-- usb.setUSBKBDCallback(function(key) print(key, 'pressed') end)
function _M.setUSBKBDCallback(callback)
    utils.checkCallback(callback)
    local r = userUSBKBDCallback
    userUSBKBDCallback = callback
    return r
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever whenever a USB Keyboard event is processed
-- @return current callback
-- @usage
-- local usb = require 'rinLibrary.rinUSB'
--
-- if usb.getUSBKBDCallback() == nil then
--     print('No USB keyboard callback installed')
-- end
function _M.getUSBKBDCallback()
    return userUSBKBDCallback
end

-------------------------------------------------------------------------------
-- Callback to detect events happening for USB devices and to further dispatch
-- them as required.
-- @param sock File descriptor the USB device is communicating with.
-- @local
local function eventCallback(sock)
    local ev = ev_lib.getEvent(sock)
    if ev then
        if utils.callable(userUSBEventCallback) then
            userUSBEventCallback(ev)
        end
        local key = kb_lib.getR400Keys(ev)
        if key and utils.callable(userUSBKBDCallback) then
            userUSBKBDCallback(key)
        end
    end
end

-------------------------------------------------------------------------------
-- Callback to receive meta-events associated with USB device appearance
-- and disappearance.
-- @param t Event table
-- @local
local function usbCallback(t)
    dbg.debug('', t)
    for k,v in pairs(t) do
        if v[1] == 'event' then
            if v[2] == 'added' then
                eventDevices[k] = ev_lib.openEvent(k)
                socks.addSocket(eventDevices[k], eventCallback)
            elseif v[2] == 'removed' and eventDevices[k] ~= nil then
                socks.removeSocket(eventDevices[k])
                eventDevices[k] = nil
            end
        end
    end

    if utils.callable(libUSBSerialCallback) then
        libUSBSerialCallback(t)
    end
    if utils.callable(userUSBRegisterCallback) then
        userUSBRegisterCallback(t)
    end
end

-------------------------------------------------------------------------------
-- Setup a serial handler
-- @param callback Callback function that accepts data byte at a time
-- @param baud Baud rate to use (default RS232_BAUD_9600)
-- @param data Number of data bits per byte (default RS232_DATA_8)
-- @param parity Type of parity bit used (default RS232_PARITY_NONE)
-- @param stopbits Number of stop bits used (default RS232_STOP_1)
-- @param flow Flavour of flow control used (default RS232_FLOW_OFF)
-- @usage
-- -- Refer to the myUSBApp example provided.
--
-- local usb = require 'rinLibrary.rinUSB'
--
-- -- The call back takes three arguments:
-- --     c The character just read from the serial device
-- --     err The error indication if c is nil
-- --     port The incoming serial port
-- -- The call back is called on open, close and when a character is read.  For the
-- -- open and close calls, the character argument is nil and the error argument is
-- -- either "open" or "close".  The call back is not invoked when writing to the
-- -- serial deivce.
-- local function usbSerialHandler(c, err, port)
--     print("USB serial", c, err)
-- end
-- usb.serialUSBdeviceHandler(usbSerialHandler)
function _M.serialUSBdeviceHandler(callback, baud, data, parity, stopbits, flow)
    local b = baud or rs232.RS232_BAUD_9600
    local d = data or rs232.RS232_DATA_8
    local p = parity or rs232.RS232_PARITY_NONE
    local s = stopbits or rs232.RS232_STOP_1
    local f = flow or rs232.RS232_FLOW_OFF

    if callback == nil then
        libUSBSerialCallback = nil
    else
        utils.checkCallback(callback)
        libUSBSerialCallback = function (t)
            for k, v in pairs(t) do
                if v[1] == "serial" then
                    if v[2] == "added" then
                        local port = v[3]
                        local noerr = rs232.RS232_ERR_NOERROR

                        assert(port:set_baud_rate(b) == noerr)
	                    assert(port:set_data_bits(d) == noerr)
		                assert(port:set_parity(p) == noerr)
		                assert(port:set_stop_bits(s) == noerr)
		                assert(port:set_flow_control(f) == noerr)

                        socks.addSocket(port, function ()
                                                  local e, c, s = port:read(1, 10)
                                                  if s == 0 then
                                                      socks.removeSocket(port)
                                                      callback(nil, "close", port)
                                                  else
                                                      callback(c, e, port)
                                                  end
                                              end)
                        callback(nil, "open", port)
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Called to initialise the USB port if in use
-- This routing is called automatically by the rinApp framework.
-- @usage
-- local usb = require 'rinUSB'
-- usb.initUSB()
function _M.initUSB()
    socks.addSocket(usb.init(), function (sock) usb.receiveCallback() end)
    usb.registerCallback(usbCallback)
    usb.checkDev()  -- call to check if any usb devices already mounted
end

-------------------------------------------------------------------------------
-- Add deprecated wrapper routines to the given table/object.
-- This routing is called automatically by the rinApp framework.
-- @param app The object to add the wrapper routines to
-- @usage
-- local usb = require 'rinUSB'
-- local t = {}
-- usb.deprecatedUSBhandlers(t)
-- t.initUSB() -- call the usb.initUSB() function.
function _M.deprecatedUSBhandlers(app)
    for k, v in pairs(_M) do
        if type(k) == "string" and type(v) == "function" and "deprecatedUSBhandlers" ~= k then
            local deprecatedWarned = false
            app[k] =    function(...)
                            if not deprecatedWarned then
                                dbg.warn('USB deprecated function ', k..' use rinLibrary.rinUSB')
                                deprecatedWarned = true
                            end
                            return v(...)
                        end
        end
    end
end

return _M
