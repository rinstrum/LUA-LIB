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

local lpeg = require "lpeg"
local locale, P, S = lpeg.locale(), lpeg.P, lpeg.S

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

private.addRegister('keybuffer',    0x0008)
private.addRegister('lcd',          0x0009)

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

private.addRegister('adcsample',    0x0020)
private.addRegister('sysstatus',    0x0021)
private.addRegister('syserr',       0x0022)
private.addRegister('absmvv',       0x0023)

private.addRegister('grossnet',     0x0025)
private.addRegister('gross',        0x0026)
private.addRegister('net',          0x0027)
private.addRegister('tare',         0x0028)
private.addRegister('peakhold',     0x0029)
private.addRegister('manhold',      0x002A)
private.addRegister('grandtotal',   0x002B)
private.addRegister('altgross',     0x002C)
private.addRegister('rawadc',       0x002D)
private.addRegister('altnet',       0x002E)
private.addRegister('fullscale',    0x002F)

--- Instrument User Variables.
--@table usrRegisters
-- @field userid_name1 Names of 5 User ID strings
-- @field userid_name2
-- @field userid_name3
-- @field userid_name4
-- @field userid_name5
-- @field usernum_name1 Names of 5 User ID numbers
-- @field usernum_name2
-- @field usernum_name3
-- @field usernum_name4
-- @field usernum_name5
-- @field userid1 Data for 5 User ID strings
-- @field userid2
-- @field userid3
-- @field userid4
-- @field userid5
-- @field usernum1 Data for 5 User ID numbers
-- @field usernum2 the first 3 are integers
-- @field usernum3 the last 2 are weight values
-- @field usernum4
-- @field usernum5

-- USER VARIABLES
private.addRegister('userid_name1',     0x0080)
private.addRegister('userid_name2',     0x0081)
private.addRegister('userid_name3',     0x0082)
private.addRegister('userid_name4',     0x0083)
private.addRegister('userid_name5',     0x0084)
private.addRegister('usernum_name1',    0x0316)
private.addRegister('usernum_name2',    0x0317)
private.addRegister('usernum_name3',    0x0318)
private.addRegister('usernum_name4',    0x0319)
private.addRegister('usernum_name5',    0x031A)

private.addRegister('userid1',          0x0090)
private.addRegister('userid2',          0x0092)
private.addRegister('userid3',          0x0093)
private.addRegister('userid4',          0x0094)
private.addRegister('userid5',          0x0095)
private.addRegister('usernum1',         0x0310)
private.addRegister('usernum2',         0x0311)
private.addRegister('usernum3',         0x0312)
private.addRegister('usernum4',         0x0313)
private.addRegister('usernum5',         0x0314)

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

private.addRegister('active_product_no',        0xB000)
private.addRegister('active_product_name',      0xB006)
private.addRegister('clr_all_totals',           0xB002)
private.addRegister('clr_docket_totals',        0xB004)
private.addRegister('select_product_no',        0xB00F)
private.addRegister('select_product_name',      0xB010)
private.addRegister('select_product_delete',    0xB011)
private.addRegister('select_product_rename',    0xB012)

--- Main Instrument Commands.
--@table rinCMD
-- @field rdlit Read literal data
-- @field rdfinalhex Read data in hexadecimal format
-- @field rdfinaldec Read data in decimal format
-- @field wrfinalhex Write data in hexadecimal format
-- @field wrfinaldec Write data in decimal format
-- @field ex Execute with data as execute parameter

-- Register Types
local TYP_CHAR             = 0x00
local TYP_UCHAR            = 0x01
local TYP_SHORT            = 0x02
local TYP_USHORT           = 0x03
local TYP_LONG             = 0x04
local TYP_ULONG            = 0x05
local TYP_STRING           = 0x06
local TYP_OPTION           = 0x07
local TYP_MENU             = 0x08
local TYP_WEIGHT           = 0x09
local TYP_BLOB             = 0x0A
local TYP_EXECUTE          = 0x0B
local TYP_BITFIELD         = 0x0C

local typeMap = {
    [TYP_CHAR]     = 'char',
    [TYP_UCHAR]    = 'uchar',
    [TYP_SHORT]    = 'short',
    [TYP_USHORT]   = 'ushort',
    [TYP_LONG]     = 'long',
    [TYP_ULONG]    = 'ulong',
    [TYP_STRING]   = 'string',
    [TYP_OPTION]   = 'option',
    [TYP_MENU]     = 'menu',
    [TYP_WEIGHT]   = 'weight',
    [TYP_BLOB]     = 'blob',
    [TYP_EXECUTE]  = 'execute',
    [TYP_BITFIELD] = 'bitfield'
}

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

-- Pattern to ease the computation of the number of decimal places in a value
local dpCount
local dpPattern = S('+-')^-1 * locale.space^0 * locale.digit^0 * (P'.' * (locale.digit^0 / function(s) dpCount = #s end))^-1

-------------------------------------------------------------------------------
-- Called to send command to a register but not wait for the response
-- @param cmd command
-- @param reg register
-- @param data to send
-- @param crc 'crc' if message sent with crc, false (default) otherwise
-- @local
local function sendReg(cmd, reg, data, crc)
    local r = private.getRegisterNumber(reg)
    _M.send(nil, cmd, r, data, "noReply", crc)
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
function _M.sendRegWait(cmd, reg, data, t, crc)

    local t = t or 2.0

    if reg == nil then
          return nil, 'Nil Register'
    end

    local r = private.getRegisterNumber(reg)
    if r == nil then
        return nil, "Unknown Register"
    end

    local waiting = true
    local regData = ''
    local regErr = ''
    local function waitf(data, err)
          regData = data
          regErr = err
          waiting = false
    end

    local f = _M.getDeviceRegister(r)
    _M.bindRegister(r, waitf)
    _M.send(nil, cmd, r, data, "reply", crc)
    local tmr = timers.addTimer(0, t, waitf, nil, 'Timeout')

    while waiting do
        system.handleEvents()
    end

    _M.bindRegister(r, f)

    timers.removeTimer(tmr)
    return regData, regErr
end

-------------------------------------------------------------------------------
-- processes the return string from rdlit command
-- if data is a floating point number then the converted number is returned
-- otherwise the original data string is returned
-- @function literalToFloat
-- @param data returned from rdlit
-- @return floating point number or data string
-- @local
function private.literalToFloat(data)
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

    data = tonumber(data,16)
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
-- @usage
-- print('serial number is', device.readReg('SerialNo'))
function _M.readReg(reg, timeout)
    local data, err

    data, err = _M.sendRegWait('rdlit', reg, nil, timeout)
    if err then
        dbg.debug('Read Error', err)
        return nil, err
    else
        return private.literalToFloat(data), nil
    end
end

-------------------------------------------------------------------------------
-- Called to write data to an instrument register
-- @param reg register
-- @param data to send
-- @param timeout timeout for send operation
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @usage
-- device.writeReg('usernum1', 0)
function _M.writeReg(reg, data, timeout)
    return _M.sendRegWait('wrfinaldec', reg, data, timeout)
end

-------------------------------------------------------------------------------
-- Called to write hex data to an instrument register
-- @param reg register
-- @param data to send
-- @param timeout timeout for send operation
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @usage
-- device.writeReg('usernum1', 0)
function private.writeRegHex(reg, data, timeout)
    return _M.sendRegWait('wrfinalhex', reg, data, timeout)
end

-------------------------------------------------------------------------------
-- Called to write data to an instrument register asynchronously
-- @function writeRegAsync
-- @param reg register
-- @param data to send
-- @local
function private.writeRegAsync(reg, data)
    _M.sendReg('wrfinaldec', reg, data)
end

-------------------------------------------------------------------------------
-- Called to write hex data to an instrument register asynchronously
-- @function writeRegHexAsync
-- @param reg register
-- @param data to send
-- @local
function private.writeRegHexAsync(reg, data)
    _M.sendReg('wrfinalhex', reg, data)
end

-------------------------------------------------------------------------------
-- Called to run a register execute command with data as the execute parameter
-- @param reg register
-- @param data to send
-- @param timeout Timeout in seconds (optional)
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @usage
-- device.exReg('flush_keys', 0) -- flush pending key presses
function _M.exReg(reg, data, timeout)
    return _M.sendRegWait('ex', reg, data, timeout)
end

-------------------------------------------------------------------------------
-- Call to run a register execute command with data as the execute parameter.
-- This call doesn't wait for a response.
-- @function exRegAsync
-- @param reg register
-- @param data to send
-- @local
function private.exRegAsync(reg, data)
    _M.sendReg('ex', reg, data, "noReply")
end

-------------------------------------------------------------------------------
-- Called to read a register value and work out how many decimal places the
-- value contains.
-- @function getRegDecimalPlaces
-- @param reg Register to read
-- @return Decimal places
-- @local
function private.getRegDecimalPlaces(reg)
    local data, err = _M.sendRegWait('rdlit', reg)
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
    local rdtype = _M.sendRegWait('rdtype', reg)
    return typeMap[tonumber(rdtype, 16)]
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
for _, v in ipairs({
            'keybuffer', 'lcd',

            'absmvv', 'adcsample', 'altgross', 'altnet', 'fullscale',
            'grandtotal', 'gross', 'grossnet', 'manhold', 'net',
            'peakhold', 'rawadc', 'syserr', 'sysstatus', 'tare',

            'userid1', 'userid2', 'userid3', 'userid4', 'userid5',
            'userid_name1', 'userid_name2', 'userid_name3',
            'userid_name4', 'userid_name5',
            'usernum1', 'usernum2', 'usernum3', 'usernum4', 'usernum5',
            'usernum_name1', 'usernum_name2', 'usernum_name3',
            'usernum_name4', 'usernum_name5',

            'active_product_name', 'active_product_no', 'clr_all_totals',
            'clr_docket_totals', 'select_product_delete',
            'select_product_name', 'select_product_no',
            'select_product_rename'
        }) do
    private.registerDeprecated(v)
end

deprecated.literalToFloat = private.literalToFloat
deprecated.toFloat = private.toFloat
deprecated.sendReg = sendReg

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
    local data, err = _M.sendRegWait('rdlit', reg)
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

end
