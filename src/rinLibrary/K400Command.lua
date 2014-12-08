-------------------------------------------------------------------------------
-- Library for K400 high level command support.
-- @module rinLibrary.K400Command
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local tonumber = tonumber
local bit32 = require "bit"
local type = type
local table = table
local timers = require 'rinSystem.rinTimers'

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

-- Commands

local REG_ADC_ZERO         = 0x0300                  -- Execute registers
local REG_ADC_TARE         = 0x0301
local REG_ADC_PT           = 0x0302                  -- Tare value is parameter
local REG_ADC_GROSS_NET    = 0x0303

local ADCGN_TOGGLE         = 0
local ADCGN_GROSS          = 1
local ADCGN_NET            = 2

local adcgnMap = {
    toggle = ADCGN_TOGGLE,  gross = ADCGN_GROSS,    net = ADCGN_NET
}

local REG_ADC_HI_RES       = 0x0304
local ADCHIRES_TOGGLE      = 0
local ADCHIRES_ON          = 1
local ADCHIRES_OFF         = 2
local ADCHIRES_DB          = 3                       -- R420 database setting

local adchiresMap = {
    toggle  = ADCHIRES_TOGGLE,
    on      = ADCHIRES_ON,
    off     = ADCHIRES_OFF,
    db      = ADCHIRES_DB
}

--  Calibrate
local REG_CALIBWGT         = 0x0100
local REG_CALIBZERO        = 0x0102
local REG_CALIBSPAN        = 0x0103
local REG_CALIBLIN         = 0x0104
local REG_CLRLIN           = 0x0105
local REG_CALIBDIRZERO     = 0x0106
local REG_CALIBDIRSPAN     = 0x0107

--- Command Return Constants and strings.
--@table Command
-- @field ok Command executed successfully
-- @field cancel Command cancelled
-- @field in_prog Command in progress
-- @field error Error processing command
-- @field ol_ul Overload or Underload
-- @field busy Busy
-- @field motion Weight in motion
-- @field band Band error
-- @field res_low Low resolution
-- @field command
-- @field duplicate Duplicate
-- @field hi_res High resolution

local CMD_OK        = 0
local CMD_CANCEL    = 1
local CMD_INPROG    = 2
local CMD_ERROR     = 3
local CMD_OL_UL     = 4
local CMD_BUSY      = 5
local CMD_MOTION    = 6
local CMD_BAND      = 7
local CMD_RESLOW    = 8
local CMD_COMMAND   = 9
local CMD_DUPLIC    = 10
local CMD_HIRES     = 11

local cmdString = {
    [CMD_OK]        = 'ok',
    [CMD_CANCEL]    = 'cancel',
    [CMD_INPROG]    = 'in_prog',
    [CMD_ERROR]     = 'error',
    [CMD_OL_UL]     = 'ol_ul',
    [CMD_BUSY]      = 'busy',
    [CMD_MOTION]    = 'motion',
    [CMD_BAND]      = 'band',
    [CMD_RESLOW]    = 'res_low',
    [CMD_COMMAND]   = 'command',
    [CMD_DUPLIC]    = 'duplicate',
    [CMD_HIRES]     = 'hi_res'
}

local REG_ZEROMVV  = 0x0111
local REG_SPANWGT  = 0x0112
local REG_SPANMVV  = 0x0113
local REG_LINWGT   = 0x0114
local REG_LINPC    = 0x0115
local NUM_LINPTS   = 10

-------------------------------------------------------------------------------
-- Called to execute one of the command below
-- @param reg register to execute
-- @param data to send
-- @param timeout Timeout in seconds (optional)
-- @return command string, nil on error
-- @return error string, nil if no error
-- @local
local function doCmd(reg, data, timeout)
    local msg, err = private.exReg(reg, data, timeout)
    if msg then
        msg = tonumber(msg)
        return cmdString[msg], nil
    else
        return nil, err
    end
end

-------------------------------------------------------------------------------
-- Called to execute a Zero command
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- device.zero()
function _M.zero()
    return doCmd(REG_ADC_ZERO, nil, 15.0)
end

-------------------------------------------------------------------------------
-- Called to execute a Tare command
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- device.tare()
function _M.tare()
    return doCmd(REG_ADC_TARE, nil, 15.0)
end

-------------------------------------------------------------------------------
-- Called to execute a Pre-set Tare command
-- @param pt is the preset tare value
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- device.presetTare(0)
function _M.presetTare(pt)
    return doCmd(REG_ADC_PT, pt or 0, 5.0)
end

-------------------------------------------------------------------------------
-- Command to set Gross Mode
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- device.gross()
function _M.gross()
    return doCmd(REG_ADC_GROSS_NET, ADCGN_GROSS, 1.0)
end

-------------------------------------------------------------------------------
-- Command to set Net mode
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- device.net()
function _M.net()
    return doCmd(REG_ADC_GROSS_NET, ADCGN_NET, 1.0)
end

-------------------------------------------------------------------------------
-- Command to toggle Gross Net status
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- device.grossNetToggle()
function _M.grossNetToggle()
    return doCmd(REG_ADC_GROSS_NET, ADCGN_TOGGLE, 1.0)
end

-------------------------------------------------------------------------------
-- Common calibration code
-- @param reg register to execute
-- @param data to send
-- @param timeout Timeout in seconds (optional)
-- @return command string, nil on error
-- @return error code or nil for none
-- @local
local function doCalibrate(reg, data, timeout)
    local msg, err = private.exReg(reg, data, timeout)
    if not msg then
        return nil, err
    end

    local timedout = false
    timers.addTimer(0, 300, function() timedout = true end)

    while not timedout do
        msg, err = private.getSystemStatus()
        if msg ~= nil then
            if not _M.checkAllSystemStatus(msg, 'calinprog') then
                return cmdString[msg % 16], nil
            end
        else
            return nil, err
        end
    end
    return nil, "timeout"
end

-------------------------------------------------------------------------------
-- Command to calibrate Zero
-- @return command string, nil on error
-- @return error code or nil for none
-- @usage
-- local msg, err = device.calibrateZero()
-- if err == nil then
--     print('Zero MVV:', device.readZeroMVV())
-- end
-- print(msg)
function _M.calibrateZero()
    return doCalibrate(REG_CALIBZERO, nil, 1.0)
end

-------------------------------------------------------------------------------
-- Command to calibrate Span
-- @param span weight value for calibration
-- @return command string, nil on error
-- @return error code or nil for none
-- @usage
-- local msg, err = device.calibrateSpan(device.editReg('calibwgt'))
-- if err == 0 then
--     print('Span Calibration Weight: ', device.readSpanWeight())
--     print('Span MVV: ', device.readSpanMVV())
-- end
-- print(msg)
function _M.calibrateSpan(span)
    if type(span) == 'string' then
        span = tonumber(span)
    end

    local msg, err = private.writeReg(REG_CALIBWGT, _M.toPrimary(span), 1.0)
    if not msg then
        return msg, err
    end

    return doCalibrate(REG_CALIBSPAN, nil, 1.0)
end

-------------------------------------------------------------------------------
-- Command to calibrate Zero using MV/V signal
-- @param MVV signal for zero
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- local MVV = device.edit('MVV ZERO', '0', 'number')
-- local ret, msg = device.calibrateZeroMVV(MVV)
-- print(msg)
function _M.calibrateZeroMVV(MVV)
    if type(MVV) == 'string' then
        MVV = tonumber(MVV)
    end
    return doCmd(REG_CALIBDIRZERO, _M.toPrimary(MVV, 4), 1.0)
end

-------------------------------------------------------------------------------
-- Command to calibrate Span using MV/V signal
-- @param MVV signal for fullscale
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- local MVV = device.edit('MVV SPAN','2.0','number')
-- local ret, msg = device.calibrateSpanMVV(MVV)
-- print(msg)
function _M.calibrateSpanMVV(MVV)
    if type(MVV) == 'string' then
        MVV = tonumber(MVV)
    end
    return doCmd(REG_CALIBDIRSPAN, _M.toPrimary(MVV, 4), 1.0)
end

-------------------------------------------------------------------------------
-- Command read calibration code
-- @param reg Register to query
-- @param dp Number of decimal places in value (optional)
-- @return value or nil on error
-- @return error string if error encountered, nil otherwise
-- @local
local function readCalibration(reg, dp)
    local data, err = private.readRegHex(reg)
    if data then
        data = private.toFloat(data, dp)
        return data, nil
    else
        return nil, err
    end
end

-------------------------------------------------------------------------------
-- Command to read MVV zero calibration
-- @return MVV signal or nil on error
-- @return error string if error encountered, nil otherwise
-- @usage
-- local msg, err = device.calibrateZero()
-- if err == nil then
--     print('Zero MVV:', device.readZeroMVV())
-- end
-- print(msg)
function _M.readZeroMVV()
    return readCalibration(REG_ZEROMVV, 4)
end

-------------------------------------------------------------------------------
-- Command to read MVV span calibration
-- @return MVV signal or nil on error
-- @return error string if error encountered, nil otherwise
-- @usage
-- local msg, err = device.readSpanMVV(device.editReg('calibwgt'))
-- if err == nil then
--     print('Span Calibration Weight: ', device.readSpanWeight())
--     print('Span MVV: ', device.readSpanMVV())
-- end
-- print(msg)
function _M.readSpanMVV()
    return readCalibration(REG_SPANMVV, 4)
end

-------------------------------------------------------------------------------
-- Command to read span calibration weight
-- @return span weight used on the last span calibration or nil on error
-- @return error string if error encountered, nil otherwise
-- @usage
-- local msg, err = device.readSpanWeight(device.editReg('calibwgt'))
-- if err == nil then
--     print('Span Calibration Weight: ', device.readSpanWeight())
--     print('Span MVV: ', device.readSpanMVV())
-- end
-- print(msg)
function _M.readSpanWeight()
    return readCalibration(REG_SPANWGT)
end

-------------------------------------------------------------------------------
-- Command to read linearisation results
-- @return linearisation results in a table of 10 lines with each line having
-- pc (percentage of fullscale that point in applied),
-- correction (amount of corrected weight)
-- @return error string or nil for no error
-- @usage
-- local ret, msg = device.calibrateLin(pt, device.editReg('calibwgt'))
-- if ret == 0 then
--     print('Linearisation Calibration: ', device.readLinCal())
-- end
-- print(msg)
function _M.readLinCal()
    local t = {}
    for i = 1, NUM_LINPTS do
        table.insert(t,{})
        local msg, err = private.exReg(REG_LINPC, i-1, 1.0)
        if not msg then
            return msg, err
        else
            t[i].pc = private.toFloat(msg,0)
        end

        msg, err = private.exReg(REG_LINWGT, i-1, 1.0)
        if not msg then
            return msg, err
        else
            t[i].correction = private.toFloat(msg)
        end
    end
    return t, nil
end

-------------------------------------------------------------------------------
-- Command to calibrate linearisation point
-- @param pt is the linearisation point 1..10
-- @param val is the weight value for the current linearisation point
-- @return command string, nil on error
-- @return error code or nil for none
-- @usage
-- local msg, err = device.calibrateLin(pt, device.editReg('calibwgt'))
-- if err == nil then
--     print('Linearisation Calibration: ', device.readLinCal())
-- end
-- print(msg)
function _M.calibrateLin(pt, val)
    if type(pt) == 'string' then
       pt = tonumber(pt)
    end

    if (pt < 1) or (pt > NUM_LINPTS) then
        return nil, 'Linearisation point out of range'
    end

    if type(val) == 'string' then
       val = tonumber(val)
    end
    local msg, err = private.writeReg(REG_CALIBWGT, _M.toPrimary(val), 1.0)
    if not msg then
        return msg, err
    end

    return doCalibrate(REG_CALIBLIN, pt-1, 1.0)
end

-------------------------------------------------------------------------------
-- Command to calibrate Span
-- @param pt is the linearisation point 1..10
-- @return command string, nil on error
-- @return error string, nil if no error
-- @usage
-- local ret, msg = device.clearLin(pt)
-- if ret == 0 then
--     print('Linearisation Calibration: ', device.readLinCal())
-- end
-- print(msg)
function _M.clearLin(pt)
    if type(pt) == 'string' then
       pt = tonumber(pt)
    end

    if (pt < 1) or (pt > NUM_LINPTS) then
        return nil, 'Linearisation point out of range'
    end

    return doCmd(REG_CLRLIN, pt-1, 1.0)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_ADC_ZERO         = REG_ADC_ZERO
deprecated.REG_ADC_TARE         = REG_ADC_TARE
deprecated.REG_ADC_PT           = REG_ADC_PT
deprecated.REG_ADC_GROSS_NET    = REG_ADC_GROSS_NET
deprecated.REG_ADC_HI_RES       = REG_ADC_HI_RES
deprecated.REG_CALIBWGT         = REG_CALIBWGT
deprecated.REG_CALIBZERO        = REG_CALIBZERO
deprecated.REG_CALIBSPAN        = REG_CALIBSPAN
deprecated.REG_CALIBLIN         = REG_CALIBLIN
deprecated.REG_CLRLIN           = REG_CLRLIN
deprecated.REG_CALIBDIRZERO     = REG_CALIBDIRZERO
deprecated.REG_CALIBDIRSPAN     = REG_CALIBDIRSPAN

deprecated.REG_ZEROMVV          = REG_ZEROMVV
deprecated.REG_SPANWGT          = REG_SPANWGT
deprecated.REG_SPANMVV          = REG_SPANMVV
deprecated.REG_LINWGT           = REG_LINWGT
deprecated.REG_LINPC            = REG_LINPC

deprecated.NUM_LINPTS           = NUM_LINPTS

end
