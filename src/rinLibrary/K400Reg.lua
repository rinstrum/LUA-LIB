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

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

_M.REG_KEYBUFFER        = 0x0008
_M.REG_LCD              = 0x0009

--- System Registers.
--@table sysRegisters
-- @field REG_SOFTMODEL Software model eg. "K401"
-- @field REG_SOFTVER Software Version eg "V1.00"
-- @field REG_SERIALNO Serial Number
_M.REG_SOFTMODEL        = 0x0003
_M.REG_SOFTVER          = 0x0004
_M.REG_SERIALNO         = 0x0005

--- Instrument Reading Registers.
--@table rdgRegisters
-- @field REG_ADCSAMPLE   Sample number of current reading
-- @field REG_SYSSTATUS   System Status Bits
-- @field REG_SYSERR      System Error Bits
-- @field REG_ABSMVV      Absolute mV/V reading (10,000 = 1mV/V)
-- @field REG_GROSSNET    Gross or Net reading depending on operating mode
-- @field REG_GROSS       Gross weight
-- @field REG_NET         Net Weight
-- @field REG_TARE        Tare Weight
-- @field REG_PEAKHOLD    Peak Hold Weight
-- @field REG_MANHOLD     Manually Held weight
-- @field REG_GRANDTOTAL  Accumulated total
-- @field REG_ALTGROSS    Gross weight in secondary units
-- @field REG_RAWADC      Raw ADC reading (2,560,000 = 1.0 mV/V)
-- @field REG_ALTNET      Net weight in secondary units
-- @field REG_FULLSCALE   Fullscale weight

_M.REG_ADCSAMPLE        = 0x0020
_M.REG_SYSSTATUS        = 0x0021
_M.REG_SYSERR           = 0x0022
_M.REG_ABSMVV           = 0x0023

_M.REG_GROSSNET         = 0x0025
_M.REG_GROSS            = 0x0026
_M.REG_NET              = 0x0027
_M.REG_TARE             = 0x0028
_M.REG_PEAKHOLD         = 0x0029
_M.REG_MANHOLD          = 0x002A
_M.REG_GRANDTOTAL       = 0x002B
_M.REG_ALTGROSS         = 0x002C
_M.REG_RAWADC           = 0x002D
_M.REG_ALTNET           = 0x002E
_M.REG_FULLSCALE        = 0x002F

--- Instrument User Variables.
--@table usrRegisters
-- @field REG_USERID_NAME1    Names of 5 User ID strings
-- @field REG_USERID_NAME2
-- @field REG_USERID_NAME3
-- @field REG_USERID_NAME4
-- @field REG_USERID_NAME5
-- @field REG_USERNUM_NAME1   Names of 5 User ID numbers
-- @field REG_USERNUM_NAME2
-- @field REG_USERNUM_NAME3
-- @field REG_USERNUM_NAME4
-- @field REG_USERNUM_NAME5
-- @field REG_USERID1         Data for 5 User ID strings
-- @field REG_USERID2
-- @field REG_USERID3
-- @field REG_USERID4
-- @field REG_USERID5
-- @field REG_USERNUM1        Data for 5 User ID numbers
-- @field REG_USERNUM2        the first 3 are integers
-- @field REG_USERNUM3        the last 2 are weight values
-- @field REG_USERNUM4
-- @field REG_USERNUM5

-- USER VARIABLES
_M.REG_USERID_NAME1     = 0x0080
_M.REG_USERID_NAME2     = 0x0081
_M.REG_USERID_NAME3     = 0x0082
_M.REG_USERID_NAME4     = 0x0083
_M.REG_USERID_NAME5     = 0x0084
_M.REG_USERNUM_NAME1    = 0x0316
_M.REG_USERNUM_NAME2    = 0x0317
_M.REG_USERNUM_NAME3    = 0x0318
_M.REG_USERNUM_NAME4    = 0x0319
_M.REG_USERNUM_NAME5    = 0x031A

_M.REG_USERID1          = 0x0090
_M.REG_USERID2          = 0x0092
_M.REG_USERID3          = 0x0093
_M.REG_USERID4          = 0x0094
_M.REG_USERID5          = 0x0095
_M.REG_USERNUM1         = 0x0310
_M.REG_USERNUM2         = 0x0311
_M.REG_USERNUM3         = 0x0312
_M.REG_USERNUM4         = 0x0313
_M.REG_USERNUM5         = 0x0314

--- Product Registers.
--@table productRegisters
-- @field REG_ACTIVE_PRODUCT_NO    Read the Active Product Number, Write to set the active product by number
-- @field REG_ACTIVE_PRODUCT_NAME  Read the Active Product Name, Write to set Active Product by name
-- @field REG_CLR_ALL_TOTALS       Clears all product totals (EXECUTE)
-- @field REG_CLR_DOCKET_TOTALS    Clears all docket sub-totals (EXECUTE)
-- @field REG_SELECT_PRODUCT_NO    Read the Selected Product Number, Write to set the Selected product by number
-- @field REG_SELECT_PRODUCT_NAME  Read the Selected Product Name, Write to set the Selected product by Name
-- @field REG_SELECT_PRODUCT_DELETE Delete Selected Product, totals must be 0 (EXECUTE)
-- @field REG_SELECT_PRODUCT_RENAME Execute with a string as an argument to change name of selected product (EXECUTE)

_M.REG_ACTIVE_PRODUCT_NO        = 0xB000
_M.REG_ACTIVE_PRODUCT_NAME      = 0xB006
_M.REG_CLR_ALL_TOTALS           = 0xB002
_M.REG_CLR_DOCKET_TOTALS        = 0xB004
_M.REG_SELECT_PRODUCT_NO        = 0xB00F
_M.REG_SELECT_PRODUCT_NAME      = 0xB010
_M.REG_SELECT_PRODUCT_DELETE    = 0xB011
_M.REG_SELECT_PRODUCT_RENAME    = 0xB012

--- Main Instrument Commands.
--@table rinCMD
-- @field CMD_RDLIT        Read literal data
-- @field CMD_RDFINALHEX   Read data in hexadecimal format
-- @field CMD_RDFINALDEC   Read data in decimal format
-- @field CMD_WRFINALHEX   Write data in hexadecimal format
-- @field CMD_WRFINALDEC   Write data in decimal format
-- @field CMD_EX           Execute with data as execute parameter

-------------------------------------------------------------------------------
-- Called to send command to a register but not wait for the response
-- @param cmd CMD_  command
-- @param reg REG_  register
-- @param data to send
-- @param crc 'crc' if message sent with crc, false (default) otherwise
-- @local
function _M.sendReg(cmd, reg, data, crc)
    local r = private.getRegisterNumber(reg)
    _M.send(nil, cmd, r, data, "noReply", crc)
end

-------------------------------------------------------------------------------
-- Called to send command and wait for response
-- @param cmd CMD_  command
-- @param reg REG_  register
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
-- processes the return string from CMD_RDLIT command
-- if data is a floating point number then the converted number is returned
-- otherwise the original data string is returned
-- @function literalToFloat
-- @param data returned from _CMD_RDLIT
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
-- @param data returned from _CMD_RDFINALHEX or from stream
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
-- @param reg REG_  register
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @usage
-- print('serial number is', device.readReg('SerialNo'))
function _M.readReg(reg)
    local data, err

    data, err = _M.sendRegWait(_M.CMD_RDLIT, reg)
    if err then
        dbg.debug('Read Error', err)
        return nil, err
    else
        return private.literalToFloat(data), nil
    end
end

-------------------------------------------------------------------------------
-- Called to write data to an instrument register
-- @param reg REG_  register
-- @param data to send
-- @usage
-- device.writeReg('usernum1', 0)
function _M.writeReg(reg, data)
    _M.sendRegWait(_M.CMD_WRFINALDEC, reg, data)
end

-------------------------------------------------------------------------------
-- Called to run a register execute command with data as the execute parameter
-- @param reg REG_  register
-- @param data to send
-- @usage
-- device.exReg('flush_keys', 0) -- flush pending key presses
function _M.exReg(reg, data)
    _M.sendRegWait(_M.CMD_EX, reg, data)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.literalToFloat = private.literalToFloat
deprecated.toFloat = private.toFloat

end
