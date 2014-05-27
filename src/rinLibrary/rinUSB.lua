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

local userUSBRegisterCallback = nil
local userUSBEventCallback = nil
local userUSBKBDCallback = nil
local libUSBSerialCallback = nil
local eventDevices = {}

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB device change is detected
-- @param f  Callback function takes event table as a parameter
-- @return The previous callback
function _M.setUSBRegisterCallback(f)
    local r = userUSBRegisterCallback
    userUSBRegisterCallback = f
    return r
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever a USB device change is detected
-- @return current callback
function _M.getUSBRegisterCallback(f)
    return userUSBRegisterCallback
end

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB device event is detected
-- @param f  Callback function takes event table as a parameter
-- @return The previous callback
function _M.setUSBEventCallback(f)
    local r = userUSBEventCallback
    userUSBEventCallback = f
    return r
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever a USB device event is detected
-- @return current callback
function _M.getUSBEventCallback()
    return userUSBEventCallback
end

-------------------------------------------------------------------------------
-- Called to register a callback to run whenever a USB Keyboard event is processed
-- @param f  Callback function takes key string as a parameter
-- @return The previous callback
function _M.setUSBKBDCallback(f)
    local r = userUSBKBDCallback
    userUSBKBDCallback = f
    return r
end

-------------------------------------------------------------------------------
-- Called to get current callback that runs whenever whenever a USB Keyboard event is processed
-- @return current callback
function _M.getUSBKBDCallback()
    return userUSBKBDCallback
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
local function eventCallback(sock)
    local ev = ev_lib.getEvent(sock)
    if ev then
        if userUSBEventCallback then
            userUSBEventCallback(ev)
        end
        local key = kb_lib.getR400Keys(ev)
        if key and userUSBKBDCallback then
            userUSBKBDCallback(key)
        end
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
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

    if libUSBSerialCallback then
        libUSBSerialCallback(t)
    end
    if userUSBRegisterCallback then
        userUSBRegisterCallback(t)
    end
end

-------------------------------------------------------------------------------
-- Setup a serial handler
-- @param cb Callback function that accepts data byte at a time
-- @param baud Baud rate to use (default RS232_BAUD_9600)
-- @param data Number of data bits per byte (default RS232_DATA_8)
-- @param parity Type of parity bit used (default RS232_PARITY_NONE)
-- @param stopbits Number of stop bits used (default RS232_STOP_1)
-- @param flow Flavour of flow control used (default RS232_FLOW_OFF)
-- The call back takes three arguments:
--  c The character just read from the serial device
--  err The error indication if c is nil
--  port The incoming serial port
function _M.serialUSBdeviceHandler(cb, baud, data, parity, stopbits, flow)
    local b = baud or rs232.RS232_BAUD_9600
    local d = data or rs232.RS232_DATA_8
    local p = parity or rs232.RS232_PARITY_NONE
    local s = stopbits or rs232.RS232_STOP_1
    local f = flow or rs232.RS232_FLOW_OFF

    if cb == nil then
        libUSBSerialCallback = nil
    else
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
                                                      cb(nil, "close", port)
                                                  else
                                                      cb(c, e, port)
                                                  end
                                              end)
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- called to initialise the USB port if in use
function _M.initUSB()
    socks.addSocket(usb.init(), function (sock) usb.receiveCallback() end)
    usb.registerCallback(usbCallback)
    usb.checkDev()  -- call to check if any usb devices already mounted
end

-------------------------------------------------------------------------------
-- Add depricated wrapper routines to the given table/object.
-- @param app The object to add the wrapper routines to
function _M.depricatedUSBhandlers(app)
    for k, v in pairs(_M) do
        if type(k) == "string" and type(v) == "function" and "depricatedUSBhandlers" ~= k then
            local depricatedWarned = false
            app[k] =    function(...)
                            if not depricatedWarned then
                                dbg.warn('USB deprecated function ', k..' use rinLibrary.rinUSB')
                                depricatedWarned = true
                            end
                            return v(...)
                        end
        end
    end
end

return _M
