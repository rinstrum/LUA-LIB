-------------------------------------------------------------------------------
---  Streaming Utilities.
-- Functions associated with streaming registers
-- @module rinLibrary.Device.Stream
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local string = string
local tonumber = tonumber
local pairs = pairs
local table = table

local bit32 = require "bit"
local timers = require 'rinSystem.rinTimers'
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local utils = require 'rinSystem.utilities'

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--  Stream Register Definitions
local REG_STREAMDATA    = 0x0040
local REG_STREAMMODE    = 0x0041
local REG_STREAMREG1    = 0x0042
local REG_STREAMREG2    = 0x0043
local REG_STREAMREG3    = 0x0044
local REG_STREAMREG4    = 0x0045
local REG_STREAMREG5    = 0x0046

-- Define the available stream register blocks.  These are either nil or should
-- be binary ORed into the above register values.
local REG_LUALIB        = 0x0300
local REG_LUAUSER       = 0x0310
local REG_STANDARD      = 0x0000

local STM_START         = 1
local STM_STOP          = 0

local STM_FREQ_MANUAL   = 0
local STM_FREQ_AUTO     = 1
local STM_FREQ_AUTO10   = 2
local STM_FREQ_AUTO3    = 3
local STM_FREQ_AUTO1    = 4
local STM_FREQ_ONCHANGE = 5

local frequencyTable = {
    auto     = STM_FREQ_AUTO,
    auto10   = STM_FREQ_AUTO10,
    auto3    = STM_FREQ_AUTO3,
    auto1    = STM_FREQ_AUTO1,
    onchange = STM_FREQ_ONCHANGE,
}
--- Frequencey streaming setttings
-- @table StreamingFrequencies
-- @param auto 20Hz streaming
-- @param auto10 10Hz streaming
-- @param auto3 3Hz streaming
-- @param auto1 1Hz streaming
-- @param onchange Stream values when they change only

local freq = 'onchange'
local freqUser = nil
local availRegisters, streamRegisters = {}, {}

local standardMap = { initialised = false }

-----------------------------------------------------------------------------
-- Initialise the mappings
-- @local
local function initialiseStreamMaps()
    if not standardMap.initialised then
        for k, v in pairs{              -- conditioning these on platform isn't
            adcsample           = 1,    -- strictly necessary, if a register
            sysstatus           = 2,    -- isn't found, no entry is added
            syserr              = 3,
            absmvv              = 4,
            grossnet            = 5,
            --dispUser            = 6,
            gross               = 7,
            net                 = 8,
            tare                = 9,
            peakhold            = private.nonbatching(10),
            manhold             = private.nonbatching(11),
            grandtotal          = 12,
            altgross            = private.nonbatching(13),
            altnet              = private.nonbatching(14),
            fullscale           = 15,
            io_status           = 16,
            piececount          = private.nonbatching(17),
            unfiltered_weight   = private.k422(18),
            get_key             = private.k422(19)
        } do
            local reg = private.getRegisterNumber(k, true)
            if reg ~= nil then
                standardMap[reg] = v
            end
        end
        standardMap.initialised = true
    end
end

-----------------------------------------------------------------------------
-- Initialise/reset the volatile streaming fields in a stream register
-- @param reg Streaming register to initialise
-- @return The initialised streaming register
-- @local
local function initStreamRegister(reg)
    reg.reg = 0
    reg.callback = nil
    reg.onChange = 'change'
    reg.lastData = ''
    reg.dp = 0
    reg.typ = 'long'
    return reg
end

-----------------------------------------------------------------------------
-- Add a group of streaming registers to the available register list
-- @param base Stream registers base location
-- @param mapping Mapping from register numbers to stream IDs
-- @local
local function addStreamingRegisters(base, mapping)
    if base ~= nil then
        local data = bit32.bor(base, REG_STREAMDATA)
        local mode = bit32.bor(base, REG_STREAMMODE)

        for _, r in pairs{
            REG_STREAMREG1, REG_STREAMREG2, REG_STREAMREG3,
            REG_STREAMREG4, REG_STREAMREG5
        } do
            table.insert(availRegisters, initStreamRegister{
                data = data,
                mode = mode,
                stream = bit32.bor(base, r),
                position = (r - REG_STREAMREG1) * 8,
                map = mapping
            })
        end
    end
end

addStreamingRegisters(REG_LUALIB)
addStreamingRegisters(REG_LUAUSER)
addStreamingRegisters(REG_STANDARD, standardMap)

-----------------------------------------------------------------------------
-- Convert a frequency string to a frequency value
-- @param f Frequency string
-- @return Frequency value
-- @local
local function convertFrequency(f)
    return naming.convertNameToValue(f, frequencyTable, STM_FREQ_ONCHANGE,
                                        STM_FREQ_MANUAL, STM_FREQ_ONCHANGE)
end

-----------------------------------------------------------------------------
-- Convert the streamed value into a value for the callback
-- @param s Streamed data
-- @param v Streaming field record
-- @local
local function convertCallbackArg(s, v)
    if s == nil then
        return nil
    end
    if v.typ == 'weight' and _M.isHiRes() then
        return private.toFloat(s, v.dp+1)
    end
    return private.toFloat(s, v.dp)
end

-----------------------------------------------------------------------------
-- Divide the data stream up and run the relevant callbacks
-- @param reg Register being streamed
-- @param data Data received from register
-- @param err Potential error message
-- @local
local function streamCallback(reg, data, err)
    if err then return end
    if string.len(data) % 8 ~= 0 or string.find(data,'%X') then
          dbg.error('Corrupt Stream Data: ', data)
          return
    end

    for k = 1, #availRegisters do
        local v = availRegisters[k]
        if v.data == reg and v.reg ~= 0 then
            local ind = v.position
            local substr = string.sub(data, ind+1, ind+8)

            if substr and substr ~= "" then
                if v.onChange == 'always' or v.lastData ~= substr then
                     v.lastData = substr
                     timers.addEvent(v.callback, convertCallbackArg(substr, v), err)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Add a stream to the device (must be connected)
-- Takes parameter 'change' (default) to run callback only if data
-- received changed, 'always' otherwise
-- @string streamReg Register to stream from (e.g. @{rinLibrary.Device.Reg.rdgRegisters})
-- @func callback Function to bind to streaming register
-- @string[opt] onChange Change parameter ('change' or 'always'). Default 'change'.
-- @treturn string streamReg
-- @see setStreamFreq
-- @usage
-- local function handleWeight(data, err)
--     print('Weight = ', data)
-- end
-- device.addStream('grossnet', handleWeight, 'change')
function _M.addStream(streamReg, callback, onChange)
    initialiseStreamMaps()
    utils.checkCallback(callback)
    if streamReg ~= nil then
        local reg = private.getRegisterNumber(streamReg)
        if streamRegisters[reg] ~= nil then
            return nil, "already streaming that register"
        end

        local dp = private.getRegDecimalPlaces(reg)
        local type = private.getRegType(reg)
        local data, err = private.readRegHex(reg)
        local regid, availReg
        for k = 1, #availRegisters do
            local v = availRegisters[k]
            if v.reg == 0 then
                if v.map ~= nil then
                    if v.map[reg] ~= nil then
                        regid = v.map[reg]
                        availReg = v
                        break
                    end
                else
                    regid = reg
                    availReg = v
                    break
                end
            end
        end

        if availReg == nil then
            return nil, "no more registers available"
        end

        availReg.dp = dp
        availReg.reg = reg
        availReg.callback = callback
        availReg.onChange = onChange or 'change'
        availReg.lastData = data
        availReg.typ = type

        streamRegisters[reg] = availReg
        utils.call(callback, convertCallbackArg(availReg.lastData, availReg), err)

        private.writeRegHexAsync(availReg.mode, convertFrequency(freqUser))
        private.writeRegHexAsync(availReg.stream, regid)
        private.exRegAsync(availReg.data, STM_START)

        private.bindRegister(availReg.data, function(data, err)
            streamCallback(availReg.data, data, err)
        end)
    end
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the device
-- @string streamReg Register to stream from (e.g. @{rinLibrary.Device.Reg.rdgRegisters})
-- @usage
-- device.removeStream('grossnet')
function _M.removeStream(streamReg)
    if streamReg ~= nil then
        local reg = private.getRegisterNumber(streamReg)
        local availReg = streamRegisters[reg]

        if availReg ~= nil then
            initStreamRegister(availReg)
            streamRegisters[reg] = nil

            local stop = true
            for k = 1, #availRegisters do
                v = availRegisters[k]
                if v.data == availReg.data and v.reg ~= 0 then
                    stop = false
                end
            end
            if stop then
                private.exReg(availReg.data, STM_STOP)
            end

            private.writeReg(availReg.stream, 0)
            private.unbindRegister(availReg.stream)
        end
    end
end

-------------------------------------------------------------------------------
-- Cleanup any unused streaming.
-- This routine is called automatically by the rinApp application framework.
-- @usage
-- device.streamCleanup()
-- @local
function _M.streamCleanup()
    local function stop(r)
        if r ~= nil then
            private.exReg(bit32.bor(r, REG_STREAMDATA), STM_STOP)
        end
    end
    stop(REG_STANDARD)
    stop(REG_LUALIB)
    stop(REG_LUAUSER)

    for k = 1, #availRegisters do
        private.writeRegAsync(availRegisters[k].stream, 0)
        availRegisters[k].reg = 0
    end
    streamRegisters = {}
end

-------------------------------------------------------------------------------
-- Set the frequency used for streaming.
-- @tparam StreamingFrequencies freq Frequency of streaming
-- @treturn StreamingFrequencies The previous frequency
-- @usage
-- device.setStreamFreq('onchange')
function _M.setStreamFreq(freq)
    local f = freqUser
    freqUser = freq or f
    return f
end

-------------------------------------------------------------------------------
-- Called to force all stream registers to resend current state.
-- @usage
-- device.renewStreamData()
function _M.renewStreamData()
    local cleanup = {}

    for k = 1, #availRegisters do
        availRegisters[k].lastData = ''
        if availRegisters[k].reg ~= 0 then
            table.insert(cleanup, availRegisters[k].data)
        end
    end
    private.renewStatusBinds()

    for k = 1, #cleanup do
        private.readRegHex(cleanup[k])
    end
end


-------------------------------------------------------------------------------
-- Called to initalise the instrument and read initial conditions.
-- This routine is called automatically by the rinApp application framework.
-- @usage
-- device.init()
-- @local
function _M.init()
    _M.renewStreamData()
    _M.sendKey('cancel', 'long')
end

if _TEST then
  deprecated.STM_START         = STM_START
  deprecated.STM_STOP          = STM_STOP
  deprecated.STM_FREQ_MANUAL   = STM_FREQ_MANUAL
  deprecated.STM_FREQ_AUTO     = STM_FREQ_AUTO
  deprecated.STM_FREQ_AUTO10   = STM_FREQ_AUTO10
  deprecated.STM_FREQ_AUTO3    = STM_FREQ_AUTO3
  deprecated.STM_FREQ_AUTO1    = STM_FREQ_AUTO1
  deprecated.STM_FREQ_ONCHANGE = STM_FREQ_ONCHANGE
end

end
