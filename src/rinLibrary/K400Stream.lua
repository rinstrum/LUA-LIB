-------------------------------------------------------------------------------
---  Streaming Utilities.
-- Functions associated with streaming registers
-- @module rinLibrary.K400Stream
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local string = string
local tonumber = tonumber
local pairs = pairs
local bit32 = require "bit"
local timers = require 'rinSystem.rinTimers.Pack'
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'

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
local REG_LUALIB        = 0x0300    -- Should be bor'd with other stream regs
local REG_LUAUSER       = 0x0310    -- should be bor'd with base stream regs

local STM_START         = 1
local STM_STOP          = 0

local STM_FREQ_MANUAL   = 0
local STM_FREQ_AUTO     = 1
local STM_FREQ_AUTO10   = 2
local STM_FREQ_AUTO3    = 3
local STM_FREQ_AUTO1    = 4
local STM_FREQ_ONCHANGE = 5

local frequencyTable = {
    manual   = STM_FREQ_MANUAL,
    auto     = STM_FREQ_AUTO,
    auto10   = STM_FREQ_AUTO10,
    auto3    = STM_FREQ_AUTO3,
    auto1    = STM_FREQ_AUTO1,
    onchange = STM_FREQ_ONCHANGE,
}

local freqLib = 'onchange'
local freqUser = 'onchange'

local availRegistersUser, streamRegistersUser = {}, {}
local availRegistersLib, streamRegistersLib = {}, {}

for _, r in pairs({
    REG_STREAMREG1, REG_STREAMREG2, REG_STREAMREG3,
    REG_STREAMREG4, REG_STREAMREG5
}) do
    availRegistersUser[r] = {   reg = 0,
                                callback = nil,
                                onChange = 'change',
                                lastData = '',
                                dp = 0,
                                typ = 'long'
                              }
    availRegistersLib[r] = {    reg = 0,
                                callback = nil,
                                onChange = 'change',
                                lastData = '',
                                dp = 0
                              }
end


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
-- Divide the data stream up and run the relevant callbacks
-- @param data Data received from register
-- @param err Potential error message
-- @local
local function streamCallback(data, err)

    if err then return end
    if (string.len(data) % 8 ~= 0) or
       (string.find(data,'%X')) then
          dbg.error('Corrupt Stream Data: ',data)
          return
    end

    for k,v in pairs(availRegistersUser) do
        if v.reg ~= 0 then
            local ind = (k - REG_STREAMREG1) * 8
            local substr = string.sub(data,ind+1,ind+8)

            if substr and substr ~= "" then
                if (v.onChange ~= 'change') or (v.lastData ~= substr) then
                     v.lastData = substr
                     if v.typ == 'weight' and _M.isHiRes() then
                         timers.addEvent(v.callback, private.toFloat(substr,v.dp+1), err)
                     else
                         timers.addEvent(v.callback, private.toFloat(substr,v.dp), err)
                     end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Add a stream to the device (must be connected)
-- Takes parameter 'change' (default) to run callback only if data
-- received changed, 'always' otherwise
-- @param streamReg Register to stream from
-- @param callback Function to bind to streaming register
-- @param onChange Change parameter
-- @return streamReg identity
-- @return error message
-- @usage
-- local function handleWeight(data, err)
--     print('Weight = ', data)
-- end
-- device.addStream('grossnet', handleWeight, 'change')
function _M.addStream(streamReg, callback, onChange)
    local reg = private.getRegisterNumber(streamReg)
    local availReg = nil

    for k,v in pairs(availRegistersUser) do
        if v.reg == 0 and (availReg == nil or k < availReg) then
            availReg = k
        end
    end

    if availReg == nil then
        return nil, "no more registers available"
    end

    availRegistersUser[availReg].dp = private.getRegDecimalPlaces(reg)
    availRegistersUser[availReg].reg = reg
    availRegistersUser[availReg].callback = callback
    availRegistersUser[availReg].onChange = onChange
    availRegistersUser[availReg].lastData = ''
    availRegistersUser[availReg].typ = private.getRegType(reg)
    streamRegistersUser[reg] = availReg

    private.writeRegHexAsync(bit32.bor(REG_LUAUSER, REG_STREAMMODE), convertFrequency(freqUser))
    private.writeRegAsync(bit32.bor(REG_LUAUSER, availReg), reg)
    private.exRegAsync(bit32.bor(REG_LUAUSER, REG_STREAMDATA), STM_START)

    _M.bindRegister(bit32.bor(REG_LUAUSER, REG_STREAMDATA), streamCallback)
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the device
-- @param streamReg Register to be removed
-- @usage
-- device.removeStream('grossnet')
function _M.removeStream(streamReg)
    local reg = private.getRegisterNumber(streamReg)
    local availReg = streamRegistersUser[reg]

     if availReg == nil then return end   -- stream already removed

    private.writeReg(bit32.bor(REG_LUAUSER, availReg), 0)
    _M.unbindRegister(bit32.bor(REG_LUAUSER, availReg))

    availRegistersUser[availReg].reg = 0
    streamRegistersUser[reg] = nil
end

-----------------------------------------------------------------------------
-- Divide the data stream up and run the callbacks for Library streams
-- @param data Data received from register
-- @param err Potential error message
-- @local
local function streamCallbackLib(data, err)
    if err then return end
    if (string.len(data) % 8 ~= 0) or
       (string.find(data,'%X')) then
          dbg.error('Corrupt Lib Stream Data: ',data)
          return
    end

    for k,v in pairs(availRegistersLib) do
        if v.reg ~= 0 then
            local ind = (k - REG_STREAMREG1) * 8
            local substr = string.sub(data,ind+1,ind+8)

            if substr and substr ~= "" then
                if (v.onChange ~= 'change') or (v.lastData ~= substr) then
                     v.lastData = substr
                     timers.addEvent(v.callback, private.toFloat(substr,v.dp), err)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Add a stream to the device (must be connected)
-- Takes parameter 'change' (default) to run callback only if data
-- received changed, 'always' otherwise
-- These stream registers are used by standard library functions so
-- not all of the 5 registers will be available for general use.
-- In other words, don't use this function.
-- @param streamReg Register to stream from
-- @param callback Function to bind to streaming register
-- @param onChange Change parameter
-- @return streamReg identity
-- @return error message
-- @local
function private.addStreamLib(streamReg, callback, onChange)
    local reg = private.getRegisterNumber(streamReg)
    local availReg = nil

    for k,v in pairs(availRegistersLib) do
        if v.reg == 0 and (availReg == nil or k < availReg) then
            availReg = k
        end
    end

    if availReg == nil then
        return nil, "no more registers available"
    end

    availRegistersLib[availReg].dp = private.getRegDecimalPlaces(reg)
    availRegistersLib[availReg].reg = reg
    availRegistersLib[availReg].callback = callback
    availRegistersLib[availReg].onChange = onChange
    availRegistersLib[availReg].lastData = ''

    streamRegistersLib[reg] = availReg

    private.writeRegHexAsync(bit32.bor(REG_LUALIB, REG_STREAMMODE), convertFrequency(freqLib))
    private.writeRegAsync(bit32.bor(REG_LUALIB, availReg), reg)
    private.exRegAsync(bit32.bor(REG_LUALIB, REG_STREAMDATA), STM_START)

   _M.bindRegister(bit32.bor(REG_LUALIB, REG_STREAMDATA), streamCallbackLib)
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the library set of streams
-- @param streamReg Register to be removed
-- @local
function private.removeStreamLib(streamReg)
    local reg = private.getRegisterNumber(streamReg)
    local availReg = streamRegistersLib[reg]

     if availReg == nil then return end   -- stream already removed

    private.writeReg(bit32.bor(REG_LUALIB, availReg), 0)
    _M.unbindRegister(bit32.bor(REG_LUALIB, availReg))

    availRegistersLib[availReg].reg = 0
    streamRegistersLib[reg] = nil
end

-------------------------------------------------------------------------------
-- Cleanup any unused streaming.
-- This routine is called automatically by the rinApp application framework.
-- @usage
-- device.streamCleanup()
function _M.streamCleanup()
    private.exReg(bit32.bor(REG_LUAUSER, REG_STREAMDATA), STM_STOP) -- stop streaming first
    private.exReg(bit32.bor(REG_LUALIB, REG_STREAMDATA), STM_STOP)  -- stop streaming first

    for k,v in pairs(availRegistersUser) do
        private.writeReg(bit32.bor(REG_LUAUSER, k), 0)
        v.reg = 0
    end
    for k,v in pairs(availRegistersLib) do
        private.writeReg(bit32.bor(REG_LUALIB, k), 0)
        v.reg = 0
    end

    streamRegistersUser = {}
    streamRegistersLib = {}
end

-------------------------------------------------------------------------------
-- Set the frequency used for streaming.
-- @param freq Frequency of streaming
-- @return The previous frequency
-- @usage
-- device.setStreamFreq('onchange')
function _M.setStreamFreq(freq)
    local f = freqUser
    freqUser = freq or f
    return f
end

-------------------------------------------------------------------------------
-- Set the frequency used for library streaming.
-- @param freq Frequency of streaming
-- @return The previous frequency
-- @usage
-- device.setStreamFreqLib('onchange')
-- @local
function private.setStreamFreqLib(freq)
    local f = freqLib
    freqLib = freq or f
    return f
end

-------------------------------------------------------------------------------
-- Called to force all stream registers to resend current state.
-- @usage
-- device.renewStreamData()
function _M.renewStreamData()
    local streamUser = false
    for _,v in pairs(availRegistersLib) do
            v.lastData = ''
    end
    for _,v in pairs(availRegistersUser) do
        if v.reg ~= 0 then
            streamUser = true
        end
        v.lastData = ''
    end
    private.renewStatusBinds()


    if streamUser then
        _M.send(nil, 'rdfinalhex',
                    bit32.bor(REG_LUAUSER, REG_STREAMDATA),
                    '', 'reply')
    end
    _M.send(nil, 'rdfinalhex',
                bit32.bor(REG_LUALIB, REG_STREAMDATA),
                '', 'reply')
end


-------------------------------------------------------------------------------
-- Called to initalise the instrument and read initial conditions.
-- This routine is called automatically by the rinApp application framework.
-- @usage
-- device.init()
function _M.init()
    _M.renewStreamData()
    _M.sendKey('cancel', 'long')
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_STREAMDATA    = REG_STREAMDATA
deprecated.REG_STREAMMODE    = REG_STREAMMODE
deprecated.REG_STREAMREG1    = REG_STREAMREG1
deprecated.REG_STREAMREG2    = REG_STREAMREG2
deprecated.REG_STREAMREG3    = REG_STREAMREG3
deprecated.REG_STREAMREG4    = REG_STREAMREG4
deprecated.REG_STREAMREG5    = REG_STREAMREG5
deprecated.REG_LUALIB        = REG_LUALIB
deprecated.REG_LUAUSER       = REG_LUAUSER

deprecated.STM_START         = STM_START
deprecated.STM_STOP          = STM_STOP
deprecated.STM_FREQ_MANUAL   = STM_FREQ_MANUAL
deprecated.STM_FREQ_AUTO     = STM_FREQ_AUTO
deprecated.STM_FREQ_AUTO10   = STM_FREQ_AUTO10
deprecated.STM_FREQ_AUTO3    = STM_FREQ_AUTO3
deprecated.STM_FREQ_AUTO1    = STM_FREQ_AUTO1
deprecated.STM_FREQ_ONCHANGE = STM_FREQ_ONCHANGE

deprecated.addStreamLib      = private.addStreamLib
deprecated.removeStreamLib   = private.removeStreamLib
deprecated.setStreamFreqLib  = private.setStreamFreqLib

end
