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
local timers = require 'rinSystem.rinTimers.Pack'
local system = require 'rinSystem.Pack'
local dbg = require "rinLibrary.rinDebug"
local rinMsg = require 'rinLibrary.rinMessage'

local lpeg = require "rinLibrary.lpeg"
local space, digit, P, S = lpeg.space, lpeg.digit, lpeg.P, lpeg.S

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

private.addRegisters{
    keybuffer               = 0x0008,
    lcd                     = 0x0009,

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

    active_product_no       = 0xB000,
    active_product_name     = 0xB006,
    clr_all_totals          = 0xB002,
    clr_docket_totals       = 0xB004,
    select_product_no       = 0xB00F,
    select_product_name     = 0xB010,
    select_product_delete   = 0xB011,
    select_product_rename   = 0xB012
}

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

-- Pattern to ease the computation of the number of decimal places in a value
local dpCount
local dpPattern = S('+-')^-1 * space^0 * digit^0 * (P'.' * (digit^0 / function(s) dpCount = #s end))^-1

-------------------------------------------------------------------------------
-- Called to send command to a register but not wait for the response
-- @param cmd command
-- @param reg register
-- @param data to send
-- @param crc 'crc' if message sent with crc, false (default) otherwise
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
-- @param crc 'crc' if message sent with crc, false (default) otherwise
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

    local finished = false
    local regData = ''
    local regErr = ''
    local function waitf(data, err)
          regData = data
          regErr = err
          finished = true
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
-- @return floating point number
-- @local
function private.toFloat(data, dp)
    local dp = dp or _M.getDispModeDP('primary')  -- use instrument dp if not specified otherwise

    data = tonumber(data, 16)
    if data > 0x7FFFFFFF then
        data = data - 0xFFFFFFFF - 1
    end
    return data / powersOfTen[dp]
end

-------------------------------------------------------------------------------
-- Called to read register contents
-- @param reg register to read
-- @param timeout timeout in seconds (optional)
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.readRegLiteral(reg, timeout)
    local data, err

    data, err = sendRegWait('rdlit', reg, nil, timeout)
    if err then
        dbg.debug('Read Literal Error', err)
    end
    return data, nil
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
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.writeReg(reg, data, timeout)
    return sendRegWait('wrfinaldec', reg, data, timeout)
end

-------------------------------------------------------------------------------
-- Called to write hex data to an instrument register
-- @param reg register
-- @param data to send
-- @param timeout timeout for send operation
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.writeRegHex(reg, data, timeout)
    return sendRegWait('wrfinalhex', reg, data, timeout)
end

-------------------------------------------------------------------------------
-- Called to write data to an instrument register asynchronously
-- @function writeRegAsync
-- @param reg register
-- @param data to send
-- @local
function private.writeRegAsync(reg, data)
    sendReg('wrfinaldec', reg, data)
end

-------------------------------------------------------------------------------
-- Called to write hex data to an instrument register asynchronously
-- @function writeRegHexAsync
-- @param reg register
-- @param data to send
-- @local
function private.writeRegHexAsync(reg, data)
    sendReg('wrfinalhex', reg, data)
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
-- Called to get a registers name
-- @param reg register
-- @param timeout Timeout in seconds (optional)
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @local
function private.getRegName(reg, timeout)
    return sendRegWait('rdname', reg, nil, timout)
end

-------------------------------------------------------------------------------
-- Called to read a register value and work out how many decimal places the
-- value contains.
-- @function getRegDecimalPlaces
-- @param reg Register to read
-- @return Decimal places
-- @local
function private.getRegDecimalPlaces(reg)
    local data, err = sendRegWait('rdlit', reg)
    if err then
        dbg.error('getRegDecimalPlaces: ', reg, err)
        return nil
    else
        dpCount = 0
        dpPattern:match(data)
        return dpCount
    end
end

-------------------------------------------------------------------------------
-- Called to read a register's type
-- @function getRegType
-- @param reg Register to query
-- @return The type of the register
-- @local
function private.getRegType(reg)
    local rdtype = sendRegWait('rdtype', reg)
    return typeMap[tonumber(rdtype, 16)]
end

-------------------------------------------------------------------------------
-- Called to read a register's maximum value
-- @function getRegMax
-- @param reg Register to query
-- @return The type of the register
-- @return Error code or nil for no error
-- @local
function private.getRegMax(reg)
    return sendRegWait('rdrangemax', reg)
end

-------------------------------------------------------------------------------
-- Called to read a register's minimum value
-- @function getRegMin
-- @param reg Register to query
-- @return The type of the register
-- @return Error code or nil for no error
-- @local
function private.getRegMin(reg)
    return sendRegWait('rdrangemin', reg)
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
    private.setCRCmode(oldCRC)
    private.saveSettings()
    file:close()
end

-- Add a timer for the heartbeat (every 5s)
timers.addTimer(5.0, 0, private.writeRegAsync, REG_HEARTBEAT, 10)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
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
