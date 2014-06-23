-------------------------------------------------------------------------------
-- USB test helpers.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local posix = require "posix"
local lpeg = require "lpeg"
local C, Cg, Ct, R = lpeg.C, lpeg.Cg, lpeg.Ct, lpeg.R

local base = '/sys/bus/usb/devices'

local d = C(R('09')^1)
local pat = Ct(d * '-' * d * ('.' * d)^0 *
               (':' * Cg(d, 'config') * '.' * Cg(d, 'interface'))^-1)

local _M = {}

-- Device and/or Interface Class codes as supported by the Linux kernel
_M.USB_CLASS_PER_INTERFACE = 0      -- DeviceClass */
_M.USB_CLASS_AUDIO = 1
_M.USB_CLASS_COMM = 2
_M.USB_CLASS_HID = 3
_M.USB_CLASS_PHYSICAL =  5
_M.USB_CLASS_STILL_IMAGE = 6
_M.USB_CLASS_PRINTER = 7
_M.USB_CLASS_MASS_STORAGE = 8
_M.USB_CLASS_HUB = 9
_M.USB_CLASS_CDC_DATA =  0x0a
_M.USB_CLASS_CSCID =  0x0b          -- chip+ smart card */
_M.USB_CLASS_CONTENT_SEC = 0x0d     -- content security */
_M.USB_CLASS_APP_SPEC = 0xfe
_M.USB_CLASS_VENDOR_SPEC = 0xff

-- Supported serial interfaces
_M.VENDOR_FUTURE_TECHNOLOGY_DEVICES = 0x0403
_M.PRODUCT_FT232_USB_SERIAL = 0x6001

_M.VENDOR_PROLIFIC_TECHNOLOGY = 0x067b
_M.PRODUCT_PL2303_SERIAL_PORT = 0x2303

-- Supported hubs
_M.VENDOR_NEC = 0x0409
_M.PRODUCT_HIGHSPEED_HUB = 0x005a


local function loadFile(path)
    local s = nil
    local f = io.open(path, "r")
    if f ~= nil then
        s = f:read('*all')
        f:close()
    end
    return s
end

local function loadNumberFile(path)
    local s = loadFile(path)
    return s and tonumber(s, 16) or nil
end

local function writeFile(path, s)
    local f = io.open(path, 'w')
    if f ~= nil then
        f:write(s)
        f:close()
    end
end

local function loadDevices(path, filter)
    local d = {}

    local files = posix.files(path)
    for f in files do
        if d[f] == nil then
            local m = pat:match(f)
            if m ~= nil then
                m.path = path .. '/' .. f .. '/'
                m.name = f
                if filter(m) then
                    table.insert(d, m)
                end
            end
        end
    end
    return d
end

local function class(m)
    if m.class == nil then
        if m.interface ~= nil then
            m.class = loadNumberFile(m.path .. 'bInterfaceClass')
        else
            m.class = loadNumberFile(m.path .. 'bDeviceClass')
        end
    end
    return m.class
end

local function isInterface(m)   return m.interface ~= nil   end
local function isDevice(m)      return m.interface == nil   end

-------------------------------------------------------------------------------
-- Load the entire USB tree
-- @return A table containing a table for each device and interface node
function _M.loadAll()           return loadDevices(base, function(m) return true end)           end

-------------------------------------------------------------------------------
-- Load the entire USB device tree
-- @return A table containing a table for each device node
function _M.loadAllDevices()    return loadDevices(base, function(m) return isInterface(m) end) end

-------------------------------------------------------------------------------
-- Load the entire USB interface tree
-- @return A table containing a table for each interface node
function _M.loadAllInterfaces() return loadDevices(base, function(m) return isDevice(m) end)    end

-------------------------------------------------------------------------------
-- Load all USB devices of a specified class
-- @return A table containing a table for each device of the specified class
function _M.loadDevices(class)
    return loadDevices(base,
        function(m)
            return isDevice(m) and class == class(m)
        end)
end

-------------------------------------------------------------------------------
-- Load all USB devices of a specified interface
-- @return A table containing a table for each device of the specified interface
function _M.loadInterfaces(class)
    return loadDevices(base,
        function(m)
            return isInterface(m) and class == class(m)
        end)
end

-------------------------------------------------------------------------------
-- Load all USB hub devices
-- @return A table containing a table for each hub in the USB device tree
function _M.loadHubDevices()    return _M.loadDevices(_M.USB_CLASS_HUB)                         end

-------------------------------------------------------------------------------
-- Load all USB hub interfaces
-- @return A table containing a table for each hub in the USB interface tree
function _M.loadHubInterfaces() return _M.loadInterfaces(_M.USB_CLASS_HUB)                      end

-------------------------------------------------------------------------------
-- Load all USB storage device interfaces
-- @return A table containing a table for each storage device in the USB interface tree
function _M.loadStorage()       return _M.loadInterfaces(_M.USB_CLASS_MASS_STORAGE)             end

-------------------------------------------------------------------------------
-- Load all USB device with the specified vendor and product ids
-- @return A table containing a table for each matching device
function _M.loadProduct(vendor, product)
    return loadDevices(base,
        function(m)
            return loadNumberFile(m.path .. 'idVendor') == vendor and
                   loadNumberFile(m.path .. 'idProduct') == product
        end)
end

-------------------------------------------------------------------------------
-- Bind a USB device or interface to the specified USB driver
-- @param m The USB device descriptor
-- @param driver A string containing the name of the relevant USB driver
function _M.bind(m, driver)
    m.driver = driver or m.driver
    writeFile('/sys/bus/usb/drivers/' .. driver .. '/bind', m.name)
end

-------------------------------------------------------------------------------
-- Unbind a USB device or interface
-- @param m The USB device descriptor
function _M.unbind(m)
    writeFile(m.path .. 'driver/unbind', m.name)
end

return _M
