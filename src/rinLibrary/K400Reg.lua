-------------------------------------------------------------------------------
--- Register Functions.
-- Functions to read, write and execute commands on instrument registers directly
-- @module rinLibrary.K400Reg
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local string = string
local tonumber = tonumber
local powersOfTen = require "rinLibrary.powersOfTen"
local timers = require 'rinSystem.rinTimers'
local system = require 'rinSystem'
local dbg = require "rinLibrary.rinDebug"
local rinMsg = require 'rinLibrary.rinMessage'
local canonical = require('rinLibrary.namings').canonicalisation
local bit32 = require "bit"

local lpeg = require "rinLibrary.lpeg"
local space, digit, P, S = lpeg.space, lpeg.digit, lpeg.P, lpeg.S

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

private.addRegisters{
    none                    = 0         -- not a register
}

private.registerDeviceInitialiser(function()
    private.addRegisters{
--- Instrument Reading Registers.
--@table rdgRegisters
-- @field adcsample Sample number of current reading
-- @field sysstatus System Status Bits
-- @field syserr System Error Bits
-- @field absmvv Absolute mV/V reading (10,000 = 1mV/V)
-- @field grossnet Gross or Net reading depending on operating mode
-- @field gross Gross weight
-- @field net Net Weight
-- @field tare Tare Weight
-- @field peakhold Peak Hold Weight
-- @field manhold Manually Held weight
-- @field grandtotal Accumulated total
-- @field altgross Gross weight in secondary units
-- @field rawadc Raw ADC reading (2,560,000 = 1.0 mV/V)
-- @field altnet Net weight in secondary units
-- @field fullscale Fullscale weight
-- @field piececount Piece count
-- @field unfiltered_weight Raw weight readings
        adcsample               = 0x0020,
        sysstatus               = 0x0021,
        syserr                  = 0x0022,
        absmvv                  = 0x0023, 
        grossnet                = 0x0025,
        gross                   = 0x0026,
        net                     = 0x0027,
        tare                    = 0x0028,
        peakhold                = private.nonbatching(0x0029),
        manhold                 = private.nonbatching(0x002A),
        grandtotal              = 0x002B,
        altgross                = private.nonbatching(0x002C),
        rawadc                  = 0x002D,
        altnet                  = private.nonbatching(0x002E),
        fullscale               = 0x002F,
        piececount              = private.nonbatching(0x0053),
        unfiltered_weight       = private.k422(0x0055),

--- Product Registers.
--@table productRegisters
-- @field active_product_no Read the Active Product Number, Write to set the active product by number
-- @field active_product_name Read the Active Product Name, Write to set Active Product by name
-- @field clr_all_totals Clears all product totals (EXECUTE)
-- @field clr_docket_totals Clears all docket sub-totals (EXECUTE)
-- @field select_product_no Read the Selected Product Number, Write to set the Selected product by number
-- @field select_product_name Read the Selected Product Name, Write to set the Selected product by Name
-- @field select_product_delete Delete Selected Product, totals must be 0 (EXECUTE)
-- @field select_product_rename Execute with a string as an argument to change name of selected product (EXECUTE)
-- @field product_total_weight ?
-- @field product_total_alt_weight ?
-- @field product_total_count ?
-- @field product_total_number ?
        active_product_no       = 0xB000,
        active_product_name     = 0xB006,
        clr_all_totals          = 0xB002,
        clr_docket_totals       = 0xB004,
        select_product_no       = 0xB00F,
        select_product_name     = 0xB010,
        select_product_delete   = 0xB011,
        select_product_rename   = 0xB012,

        product_total_weight    = 0xB102,
        product_total_alt_weight= 0xB103,
        product_total_count     = 0xB104,
        product_total_number    = 0xB105
    }
end)

local REG_HEARTBEAT         = 0x032F

-- Register Types
local TYP_CHAR              = 0x00
local TYP_UCHAR             = 0x01
local TYP_SHORT             = 0x02
local TYP_USHORT            = 0x03
local TYP_LONG              = 0x04
local TYP_ULONG             = 0x05
local TYP_STRING            = 0x06
local TYP_OPTION            = 0x07
local TYP_MENU              = 0x08
local TYP_WEIGHT            = 0x09
local TYP_BLOB              = 0x0A
local TYP_EXECUTE           = 0x0B
local TYP_BITFIELD          = 0x0C

--- Register Types.
-- @table rinType
-- @field char Eight bit character
-- @field uchar Eight bit unsigned character
-- @field short Sixteen bit signed integer
-- @field ushort Sixteen bit unsigned integer
-- @field long Thirty two bit signed integer
-- @field ulong Thirty two bit unsigned integer
-- @field string String
-- @field option Option
-- @field menu Menu
-- @field weight Weight
-- @field blob Blob
-- @field execute Execute
-- @field bitfield Bit Field
local typeMap = {
    [TYP_CHAR]              = 'char',
    [TYP_UCHAR]             = 'uchar',
    [TYP_SHORT]             = 'short',
    [TYP_USHORT]            = 'ushort',
    [TYP_LONG]              = 'long',
    [TYP_ULONG]             = 'ulong',
    [TYP_STRING]            = 'string',
    [TYP_OPTION]            = 'option',
    [TYP_MENU]              = 'menu',
    [TYP_WEIGHT]            = 'weight',
    [TYP_BLOB]              = 'blob',
    [TYP_EXECUTE]           = 'execute',
    [TYP_BITFIELD]          = 'bitfield'
}

local permissionsMap = {
    [0] = true, [1] = 'safe', [2] = 'full', [3] = false
}

-- Pattern to ease the computation of the number of decimal places in a value
local dpCount
local dpPattern = S('+-')^-1 * space^0 * digit^0 * (P'.' * (digit^0 / function(s) dpCount = #s end))^-1

local regCache      -- Maintain a cache of register attributes

-------------------------------------------------------------------------------
-- Called to send command to a register but not wait for the response
-- @param cmd command
-- @param reg register
-- @param data to send
-- @param crc 'crc' if message sent with crc, not otherwise (default)
-- @local
local function sendReg(cmd, reg, data, crc)
    if reg ~= nil then
        local r = private.getRegisterNumber(reg)
        private.send(nil, cmd, r, data, "noReply", crc)
    end
end

-------------------------------------------------------------------------------
-- Called to send command and wait for response
-- @param cmd command
-- @param reg register
-- @param data to send
-- @param t timeout in sec
-- @param crc 'crc' if message sent with crc, not otherwise (default)
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
local function sendRegWait(cmd, reg, data, t, crc)
    if reg == nil then
          return nil, 'Nil Register'
    end

    local r = private.getRegisterNumber(reg)
    if r == nil then
        return nil, "Unknown Register"
    end

    local finished, regData, regErr = false, '', ''
    local function waitf(data, err)
        finished, regData, regErr = true, data, err
    end

    local f = private.getDeviceRegister(r)
    private.bindRegister(r, waitf)
    private.send(nil, cmd, r, data, "reply", crc)
    local tmr = timers.addTimer(0, t or 2.0, waitf, nil, 'Timeout')

    _M.app.delayUntil(function() return finished end)
    private.bindRegister(r, f)

    timers.removeTimer(tmr)
    return regData, regErr
end

-------------------------------------------------------------------------------
-- processes the return string from rdlit command
-- if data is a floating point number then the converted number is returned
-- otherwise the original data string is returned
-- @param data returned from rdlit
-- @return floating point number or data string
-- @local
local function literalToFloat(data)
    local a, b = string.find(data,'[+-]?%s*%d*%.?%d*')
    if not a then
        return data
    else
        data = string.gsub(string.sub(data,a,b), '%s', '')  -- remove spaces
        return tonumber(data)
    end
end

-------------------------------------------------------------------------------
-- called to convert hexadecimal return string to a floating point number
-- @function toFloat
-- @param data returned from _rdfinalhex or from stream
-- @param dp decimal position (if nil then instrument dp used)
-- @return floating point number or nil on error
-- @local
function private.toFloat(data, dp)
    local dp = dp or _M.getDispModeDP('primary')  -- use instrument dp if not specified otherwise

    data = tonumber(data, 16)
    if data then
        if data > 0x7FFFFFFF then
            data = data - 4294967296    -- 4294967296 = 2^32 = 0xFFFFFFFF + 1
        end
        return data / powersOfTen[dp]
    end
    return nil
end

-------------------------------------------------------------------------------
-- Called to read register contents
-- @param reg register to read
-- @param timeout timeout in seconds (optional)
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.readRegLiteral(reg, timeout)
    local data, err = sendRegWait('rdlit', reg, nil, timeout)
    if err then
        dbg.debug('Read Literal Error', err)
    end
    return data, err
end

-------------------------------------------------------------------------------
-- Called to read register contents
-- @function readReg
-- @param reg register to read
-- @param timeout timeout in seconds (optional)
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.readReg(reg, timeout)
    local data, err = private.readRegLiteral(reg, timeout)

    if err then
        return nil, err
    end
    local num = literalToFloat(data)
    if num then
        return num, nil
    else
        return data, nil
    end
end

-------------------------------------------------------------------------------
-- Called to read register contents in decimal
-- @param reg register to read
-- @param timeout timeout in seconds (optional)
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.readRegDec(reg, timeout)
    local data, err

    data, err = sendRegWait('rdfinaldec', reg, nil, timeout)
    if err then
        dbg.debug('Read Dec Error', err)
    end
    return data, nil
end

-------------------------------------------------------------------------------
-- Called to read register contents in decimal
-- @param reg register to read
-- @param timeout timeout in seconds (optional)
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.readRegHex(reg, timeout)
    local data, err

    data, err = sendRegWait('rdfinalhex', reg, nil, timeout)
    if err then
        dbg.debug('Read Hex Error', err)
    end
    return data, err
end

-------------------------------------------------------------------------------
-- Called to write data to an instrument register
-- @function writeReg
-- @param reg register
-- @param data to send
-- @param timeout timeout for send operation
-- @param crc 'crc' if message sent with crc, not otherwise (default)
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.writeReg(reg, data, timeout, crc)
    return sendRegWait('wrfinaldec', reg, data, timeout, crc)
end

-------------------------------------------------------------------------------
-- Called to write hex data to an instrument register
-- @param reg register
-- @param data to send
-- @param timeout timeout for send operation
-- @param crc 'crc' if message sent with crc, not otherwise (default)
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.writeRegHex(reg, data, timeout, crc)
    return sendRegWait('wrfinalhex', reg, data, timeout, crc)
end

-------------------------------------------------------------------------------
-- Called to write data to an instrument register asynchronously
-- @function writeRegAsync
-- @param reg register
-- @param data to send
-- @param crc 'crc' if message sent with crc, not otherwise (default)
-- @local
function private.writeRegAsync(reg, data, crc)
    sendReg('wrfinaldec', reg, data, crc)
end

-------------------------------------------------------------------------------
-- Called to write hex data to an instrument register asynchronously
-- @function writeRegHexAsync
-- @param reg register
-- @param data to send
-- @param crc 'crc' if message sent with crc, not otherwise (default)
-- @local
function private.writeRegHexAsync(reg, data, crc)
    sendReg('wrfinalhex', reg, data, crc)
end

-------------------------------------------------------------------------------
-- Called to run a register execute command with data as the execute parameter
-- @function exReg
-- @param reg register
-- @param data to send
-- @param timeout Timeout in seconds (optional)
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.exReg(reg, data, timeout)
    return sendRegWait('ex', reg, data, timeout)
end

-------------------------------------------------------------------------------
-- Call to run a register execute command with data as the execute parameter.
-- This call doesn't wait for a response.
-- @function exRegAsync
-- @param reg register
-- @param data to send
-- @local
function private.exRegAsync(reg, data)
    sendReg('ex', reg, data, "noReply")
end

-------------------------------------------------------------------------------
-- Reset the register infomation cache to clear.
--
-- This needs to be called after any change that might impact the register
-- information and settings.
-- @function resetRegisterInfoCache
-- @local
function private.resetRegisterInfoCache()
    regCache = {}
end
private.resetRegisterInfoCache()

-------------------------------------------------------------------------------
-- Utility function to cache register information.
-- The item desired is queried for and cached.  Future queries return the
-- cached value directly.
-- @param reg Register to query
-- @param name Name of item being queried
-- @param post Post query update function
-- @param ... Argument to sendRegWait to query this item
-- @return query result, nil if error
-- @return err error string if error received, nil otherwise
-- @local
local function queryRegisterInformation(reg, name, post, ...)
    if reg == nil then
          return nil, 'Nil Register'
    end
    local r = private.getRegisterNumber(reg)
    if r == nil then
        return nil, "Unknown Register"
    end

    if regCache[r] == nil then
        regCache[r] = {}
    end
    if regCache[r][name] ~= nil then
        return regCache[r][name], nil
    end

    local data, err = post(reg, sendRegWait(...))
    if err == nil then
        regCache[r][name] = data
    end
    return data, err
end

-------------------------------------------------------------------------------
-- Query helper function that simply returns its arguments.
-- This is used for a no modification query
-- @param reg Register being queried
-- @param data Data returned from the display
-- @param err Error code from display
-- @return Data
-- @return Error code
-- @local
local function queryNoChanges(reg, data, err)
    return data, err
end

-------------------------------------------------------------------------------
-- Called to get a registers name
-- @param reg register
-- @param timeout Timeout in seconds (optional)
-- @return reply Name of register from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.getRegName(reg, timeout)
    return queryRegisterInformation(reg, 'name', queryNoChanges, 'rdname', reg, nil, timout)
end

-------------------------------------------------------------------------------
-- Query helper function to get decimal places from a query return code
-- @param reg Register being queried
-- @param data Formatted value returned from display
-- @param err Error code from display
-- @return Number of decimal places
-- @return Error code
-- @local
local function queryDecimalPlaces(reg, data, err)
    if err then
        return data, err
    end
    dpCount = 0
    dpPattern:match(data)
    return dpCount, nil
end

-------------------------------------------------------------------------------
-- Called to read a register value and work out how many decimal places the
-- value contains.
-- @function getRegDecimalPlaces
-- @param reg Register to read
-- @return Decimal places for register, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.getRegDecimalPlaces(reg)
    return queryRegisterInformation(reg, 'decimalPlaces', queryDecimalPlaces, 'rdlit', reg)
end

-------------------------------------------------------------------------------
-- Query helper function to get permissions from the permission return code
-- @param reg Register being queried
-- @param data Permission code returned from display
-- @param err Error code from display
-- @return Permissions table
-- @return Error code
-- @local
local function queryPermissions(reg, data, err)
    local p = tonumber(data, 16) or 15
    return {
        read = permissionsMap[p % 4],
        write = permissionsMap[math.floor(p/4) % 4],
        sideEffects = bit32.band(0x80, p) == 0
    }, err
end

-------------------------------------------------------------------------------
-- Called to read a register's permissions
-- @function getRegType
-- @param reg Register to query
-- @return The register permissions, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.getRegPermissions(reg)
    return queryRegisterInformation(reg, 'permissions', queryPermissions, 'rdpermission', reg)
end

-------------------------------------------------------------------------------
-- Query helper function to get type from the type code
-- @param reg Register being queried
-- @param data Type code returned from display
-- @param err Error code from display
-- @return Type name
-- @return Error code
-- @local
local function queryType(reg, data, err)
    if data == nil then return nil, err end
    return typeMap[tonumber(data, 16) or -1], err
end

-------------------------------------------------------------------------------
-- Called to read a register's type
-- @function getRegType
-- @param reg Register to query
-- @return The type of the register, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.getRegType(reg)
    return queryRegisterInformation(reg, 'type', queryType, 'rdtype', reg)
end

-------------------------------------------------------------------------------
-- Query helper function to get a number from the data
-- @param reg Register being queried
-- @param data Data returned from display
-- @param err Error code from display
-- @return Numeric data
-- @return Error code
-- @local
local function queryNum(reg, data, err)
    if err then
        return data, err
    end
    return private.toFloat(data, private.getRegDecimalPlaces(reg)), nil
end

-------------------------------------------------------------------------------
-- Called to read a register's maximum value
-- @function getRegMax
-- @param reg Register to query
-- @return The maximum value for the register, not converted to real, nil if error
-- @return Error code or nil for no error
-- @local
function private.getRegMax(reg)
    local dp = private.getRegDecimalPlaces(reg)
    return queryRegisterInformation(reg, 'max', queryNum, 'rdrangemax', reg)
end

-------------------------------------------------------------------------------
-- Called to read a register's minimum value
-- @function getRegMin
-- @param reg Register to query
-- @return The minimum value for the register, not converted to real, nil if error
-- @return Error code or nil for no error
-- @local
function private.getRegMin(reg)
    local dp = private.getRegDecimalPlaces(reg)
    return queryRegisterInformation(reg, 'min', queryNum, 'rdrangemin', reg)
end

-------------------------------------------------------------------------------
-- Query all the information about a register.
-- @param reg Register to query information about
-- @return Table containing all the register information
-- @usage
-- local regInfo = device.getRegInfo('grossnet')
-- print('grossnet decimals', regInfo.dp)
function _M.getRegInfo(reg)
    return {
        name            = private.getRegName(reg) or canonical(reg),
        type            = private.getRegType(reg),
        min             = private.getRegMin(reg),
        max             = private.getRegMax(reg),
        decimalPlaces   = private.getRegDecimalPlaces(reg),
        permissions     = private.getRegPermissions(reg)
    }
end

-------------------------------------------------------------------------------
-- Read a numeric register and convert according to the current decimal place
-- settings etc
-- @param reg Register to query
-- @return value of register or nil on error
-- @return eror message or nil for no error
-- @local
local function getNumber(reg)
    local n, err = private.readRegHex(reg)
    if n == nil then
        return nil, err
    end
    return private.toFloat(n, private.getRegDecimalPlaces(reg))
end

-------------------------------------------------------------------------------
-- Write a numeric register and convert according to the current decimal place
-- settings etc
-- @param reg Register to query
-- @param val Value to write to the register (real)
-- @local
local function setNumber(reg, val)
    val = math.max(private.getRegMin(reg), math.min(private.getRegMax(reg), val))
    val = math.floor(val * powersOfTen[private.getRegDecimalPlaces(reg)] + 0.5)
    if val < 0 then
        val = val + 4294967296
    end
    return private.writeRegHexAsync(reg, val)
end

local registerAccessorsByType = {
--  type            read function           write function
    char        = { getNumber,              setNumber                   },
    uchar       = { getNumber,              setNumber                   },
    short       = { getNumber,              setNumber                   },
    ushort      = { getNumber,              setNumber                   },
    long        = { getNumber,              setNumber                   },
    ulong       = { getNumber,              setNumber                   },
    string      = { private.readRegLiteral, private.writeReg            },
    option      = { private.readRegHex,     private.writeRegHexAsync    },
    menu        = { private.readRegHex,     private.writeRegHexAsync    },
    weight      = { getNumber,              setNumber                   },
    blob        = { private.readRegHex,     private.writeRegHexAsync    },
    execute     = { nil,                    private.exReg               },
    bitfield    = { private.readRegHex,     private.writeRegHexAsync    },
}

-------------------------------------------------------------------------------
-- Type and range congiscent register query function
-- @param reg Register to read
-- @return Register's value, nil on error
-- @return Error message, nil for no error
-- @usage
-- local value = getRegister('')
function _M.getRegister(reg)
    local t, err = private.getRegType(reg)
    if t == nil then
        return nil, err
    end

    local acc = registerAccessorsByType[t]
    if acc and acc[1] then
        return acc[1](reg)
    end
    return nil, (acc == nil) and "unknown register type" or 'cannot get register'
end

-------------------------------------------------------------------------------
-- Type and range congiscent register query function
-- @param reg Register to set
-- @param value Value to set register to
-- @return Register's value, nil on error
-- @return Error message, nil for no error
-- @usage
-- setRegister('', 3.14)
function _M.setRegister(reg, value)
    local t, err = private.getRegType(reg)
    if t == nil then
        return nil, err
    end

    local acc = registerAccessorsByType[t]
    if acc and acc[2] then
        return acc[2](reg, value)
    end
    return (acc == nil) and "unknown register type" or 'cannot set register'
end

-------------------------------------------------------------------------------
-- Read a RIS file and send valid commands to the device
-- @param filename Name of the RIS file
-- @param calibration Set to true to rewrite calibration data.  This will
-- increase the calibration count and should not be used lightly.  Generally,
-- omit this argument and rely on the default behaviour of not rewriting the
-- calibration data.
-- @usage
-- device.loadRIS('myApp.RIS')
function _M.loadRIS(filename, calibration)
    local file = io.open(filename, "r")
    if not file then
        dbg.warn('RIS file not found',filename)
        return
    end

    local oldCRC = private.setCRCmode(calibration == true and 'crc' or '')
    for line in file:lines() do
        if (string.find(line, ':') and tonumber(string.sub(line, 1, 8), 16)) then
            local endCh = string.sub(line, -1, -1)
            if endCh ~= '\r' and endCh ~= '\n' then
                line = line .. ';'
            end

            local _, cmd, reg, data, err = rinMsg.processMsg(line)
            if err then
                dbg.error('RIS error: ',err)
            end
            sendRegWait(cmd, reg, data)
        end
    end
    file:close()
    private.setCRCmode(oldCRC)
    _M.saveSettings()
end

-- Add a timer for the heartbeat (every 5s)
timers.addTimer(5.0, 0, private.writeRegAsync, REG_HEARTBEAT, 10)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
private.registerDeviceInitialiser(function()
    private.registerDeprecated{
        'keybuffer', 'lcd',

        'absmvv', 'adcsample', 'altgross', 'altnet', 'fullscale',
        'grandtotal', 'gross', 'grossnet', 'manhold', 'net',
        'peakhold', 'rawadc', 'syserr', 'sysstatus', 'tare',

        'active_product_name', 'active_product_no', 'clr_all_totals',
        'clr_docket_totals', 'select_product_delete',
        'select_product_name', 'select_product_no',
        'select_product_rename'
    }
end)

deprecated.TYP_CHAR     = TYP_CHAR
deprecated.TYP_UCHAR    = TYP_UCHAR
deprecated.TYP_SHORT    = TYP_SHORT
deprecated.TYP_USHORT   = TYP_USHORT
deprecated.TYP_LONG     = TYP_LONG
deprecated.TYP_ULONG    = TYP_ULONG
deprecated.TYP_STRING   = TYP_STRING
deprecated.TYP_OPTION   = TYP_OPTION
deprecated.TYP_MENU     = TYP_MENU
deprecated.TYP_WEIGHT   = TYP_WEIGHT
deprecated.TYP_BLOB     = TYP_BLOB
deprecated.TYP_EXECUTE  = TYP_EXECUTE
deprecated.TYP_BITFIELD = TYP_BITFIELD

deprecated.literalToFloat = literalToFloat
deprecated.toFloat = private.toFloat
deprecated.sendReg = sendReg
deprecated.sendRegWait = sendRegWait
deprecated.readReg = private.readReg
deprecated.writeReg = private.writeReg
deprecated.exReg = private.exReg

-------------------------------------------------------------------------------
-- Called to read a register value and return value and dp position
-- Used to work out the dp position of a register value so subsequent
-- reads can use the hexadecimal format and convert locally using
-- toFloat
-- @function getRegDP
-- @param reg  register to read
-- @return register value number
-- @return dp position
-- @local
function deprecated.getRegDP(reg)
    local data, err = sendRegWait('rdlit', reg)
    if err then
        dbg.error('getDP: ', reg, err)
        return nil, nil
    else
        local tmp = string.match(data,'[+-]?%s*(%d*%.?%d*)')
        local dp = string.find(tmp,'%.')
        if not dp then
            dp = 0
        else
            dp =  string.len(tmp) - dp
        end

        return tonumber(tmp), dp
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Expose some internals for testing purposes
if _TEST then
    private.literalToFloat = literalToFloat
    private.sendRegWait = sendRegWait
end

end
