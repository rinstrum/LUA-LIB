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

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, depricated)

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

local frequencyTable = setmetatable({
        manual   = STM_FREQ_MANUAL,     [STM_FREQ_MANUAL]   = STM_FREQ_MANUAL,
        auto     = STM_FREQ_AUTO,       [STM_FREQ_AUTO]     = STM_FREQ_AUTO,
        auto10   = STM_FREQ_AUTO10,     [STM_FREQ_AUTO10]   = STM_FREQ_AUTO10,
        auto3    = STM_FREQ_AUTO3,      [STM_FREQ_AUTO3]    = STM_FREQ_AUTO3,
        auto1    = STM_FREQ_AUTO1,      [STM_FREQ_AUTO1]    = STM_FREQ_AUTO1,
        onchange = STM_FREQ_ONCHANGE,   [STM_FREQ_ONCHANGE] = STM_FREQ_ONCHANGE,
    }, { __index = function(t, k)
                       _M.dbg.warn("K400: unknown stream frequency", k)
                       return STM_FREQ_ONCHANGE
                   end
})

local freqLib = 'onchange'
local freqUser = 'onchange'

local availRegistersUser = {
                        [REG_STREAMREG1]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0,
                                              typ = _M.TYP_LONG},
                        [REG_STREAMREG2]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0,
                                              typ = _M.TYP_LONG},
                        [REG_STREAMREG3]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0,
                                              typ = _M.TYP_LONG},
                        [REG_STREAMREG4]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0,
                                              typ = _M.TYP_LONG},
                        [REG_STREAMREG5]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0,
                                              typ = _M.TYP_LONG}
                    }
local streamRegistersUser = {}

-----------------------------------------------------------------------------
-- Divide the data stream up and run the relevant callbacks
-- @param data Data received from register
-- @param err Potential error message
-- @local
local function streamCallback(data, err)

    if err then return end
    if (string.len(data) % 8 ~= 0) or
       (string.find(data,'%X')) then
          _M.dbg.error('Corrupt Stream Data: ',data)
          return
    end

    for k,v in pairs(availRegistersUser) do
        if v.reg ~= 0 then
            local ind = (k - REG_STREAMREG1) * 8
            local substr = string.sub(data,ind+1,ind+8)

            if substr and substr ~= "" then
                if (v.onChange ~= 'change') or (v.lastData ~= substr) then
                     v.lastData = substr
                     if v.typ == _M.TYP_WEIGHT and _M.settings.hiRes then
                         _M.system.timers.addEvent(v.callback, _M.toFloat(substr,v.dp+1), err)
                     else
                         _M.system.timers.addEvent(v.callback, _M.toFloat(substr,v.dp), err)
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

    _, availRegistersUser[availReg].dp = _M.getRegDP(reg)
    local typ = tonumber(_M.sendRegWait(_M.CMD_RDTYPE,reg),16)
    availRegistersUser[availReg].reg = reg
    availRegistersUser[availReg].callback = callback
    availRegistersUser[availReg].onChange = onChange
    availRegistersUser[availReg].lastData = ''
    availRegistersUser[availReg].typ = typ
    streamRegistersUser[reg] = availReg

    _M.sendReg(_M.CMD_WRFINALHEX,
                bit32.bor(REG_LUAUSER,REG_STREAMMODE),
                frequencyTable[freqUser])
    _M.sendReg(_M.CMD_WRFINALDEC,
                bit32.bor(REG_LUAUSER, availReg),
                reg)
    _M.sendReg(_M.CMD_EX,
                bit32.bor(REG_LUAUSER, REG_STREAMDATA),
                STM_START)

    _M.bindRegister(bit32.bor(REG_LUAUSER,REG_STREAMDATA), streamCallback)
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the device
-- @param streamReg Register to be removed
function _M.removeStream(streamReg)
    local reg = private.getRegisterNumber(streamReg)
    local availReg = streamRegistersUser[reg]

     if availReg == nil then return end   -- stream already removed

    _M.sendRegWait(_M.CMD_WRFINALDEC, bit32.bor(REG_LUAUSER,availReg), 0)
    _M.unbindRegister(bit32.bor(REG_LUAUSER, availReg))

    availRegistersUser[availReg].reg = 0
    streamRegistersUser[reg] = nil
end

local availRegistersLib = {
                        [REG_STREAMREG1]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0},
                        [REG_STREAMREG2]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0},
                        [REG_STREAMREG3]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0},
                        [REG_STREAMREG4]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0},
                        [REG_STREAMREG5]= {reg = 0,
                                              callback = nil,
                                              onChange = 'change',
                                              lastData = '',
                                              dp = 0}
                    }
local streamRegistersLib = {}

-----------------------------------------------------------------------------
-- Divide the data stream up and run the callbacks for Library streams
-- @param data Data received from register
-- @param err Potential error message
-- @local
local function streamCallbackLib(data, err)

    if err then return end
    if (string.len(data) % 8 ~= 0) or
       (string.find(data,'%X')) then
          _M.dbg.error('Corrupt Lib Stream Data: ',data)
          return
    end

    for k,v in pairs(availRegistersLib) do
        if v.reg ~= 0 then
            local ind = (k - REG_STREAMREG1) * 8
            local substr = string.sub(data,ind+1,ind+8)

            if substr and substr ~= "" then
                if (v.onChange ~= 'change') or (v.lastData ~= substr) then
                     v.lastData = substr
                     _M.system.timers.addEvent(v.callback,_M.toFloat(substr,v.dp), err)
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
-- not all of the 5 registers will be available for general use
-- @param streamReg Register to stream from
-- @param callback Function to bind to streaming register
-- @param onChange Change parameter
-- @return streamReg indentity
-- @return error message
function _M.addStreamLib(streamReg, callback, onChange)
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

    _, availRegistersLib[availReg].dp = _M.getRegDP(reg)
    availRegistersLib[availReg].reg = reg
    availRegistersLib[availReg].callback = callback
    availRegistersLib[availReg].onChange = onChange
    availRegistersLib[availReg].lastData = ''

    streamRegistersLib[reg] = availReg

    _M.sendReg(_M.CMD_WRFINALHEX,
                bit32.bor(REG_LUALIB, REG_STREAMMODE),
                frequencyTable[freqLib])
    _M.sendReg(_M.CMD_WRFINALDEC,
                bit32.bor(REG_LUALIB, availReg),
                reg)
    _M.sendReg(_M.CMD_EX,
                bit32.bor(REG_LUALIB, REG_STREAMDATA),
                STM_START)

   _M.bindRegister(bit32.bor(REG_LUALIB, REG_STREAMDATA), streamCallbackLib)
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the library set of streams
-- @param streamReg Register to be removed
function _M.removeStreamLib(streamReg)
    local reg = private.getRegisterNumber(streamReg)
    local availReg = streamRegistersLib[reg]

     if availReg == nil then return end   -- stream already removed

    _M.sendRegWait(_M.CMD_WRFINALDEC,bit32.bor(REG_LUALIB,availReg),0)
    _M.unbindRegister(bit32.bor(REG_LUALIB, availReg))

    availRegistersLib[availReg].reg = 0
    streamRegistersLib[reg] = nil
end

-------------------------------------------------------------------------------
-- Cleanup any unused streaming
function _M.streamCleanup()
    _M.sendRegWait(_M.CMD_EX,
                bit32.bor(REG_LUAUSER, REG_STREAMDATA),
                STM_STOP)  -- stop streaming first
    _M.sendRegWait(_M.CMD_EX,
                bit32.bor(REG_LUALIB, REG_STREAMDATA),
                STM_STOP)  -- stop streaming first

    for k,v in pairs(availRegistersUser) do
        _M.sendRegWait(_M.CMD_WRFINALDEC, bit32.bor(REG_LUAUSER, k), 0)
        v.reg = 0
    end
    for k,v in pairs(availRegistersLib) do
        _M.sendRegWait(_M.CMD_WRFINALDEC, bit32.bor(REG_LUALIB, k), 0)
        v.reg = 0
    end

    streamRegistersUser = {}
    streamRegistersLib = {}

end

-------------------------------------------------------------------------------
--  Set the frequency used for streaming
-- @param freq Frequency of streaming (_M.STM_FREQ_*)
-- @return The previous frequency
function _M.setStreamFreq(freq)
    local f = freqUser
    freqUser = freq or freqUser
    return f
end

-------------------------------------------------------------------------------
-- Set the frequency used for library streaming
-- @param freq Frequency of streaming
-- @return The previous frequency
function _M.setStreamFreqLib(freq)
    local f = freqLib
    freqLib = freq or freqLib
    return f
end


-------------------------------------------------------------------------------
-- Called to force all stream registers to resend current state
function _M.renewStreamData()
   local streamUser = false
   for k,v in pairs(availRegistersLib) do
            v.lastData = ''
   end
   for k,v in pairs(availRegistersUser) do
            if v.reg ~= 0 then
                streamUser = true
            end
            v.lastData = ''
   end
   private.renewStatusBinds()


   if streamUser then
      _M.send(nil,_M.CMD_RDFINALHEX,
                 bit32.bor(REG_LUAUSER, REG_STREAMDATA),
                 '','reply')
   end
   _M.send(nil,_M.CMD_RDFINALHEX,
                 bit32.bor(REG_LUALIB, REG_STREAMDATA),
                 '','reply')

end


-------------------------------------------------------------------------------
-- Called to initalise the instrument and read initial conditions
function _M.init()
    _M.renewStreamData()
    _M.sendKey(_M.KEY_CANCEL, 'long')
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the depricated fields
depricated.REG_STREAMDATA    = REG_STREAMDATA
depricated.REG_STREAMMODE    = REG_STREAMMODE
depricated.REG_STREAMREG1    = REG_STREAMREG1
depricated.REG_STREAMREG2    = REG_STREAMREG2
depricated.REG_STREAMREG3    = REG_STREAMREG3
depricated.REG_STREAMREG4    = REG_STREAMREG4
depricated.REG_STREAMREG5    = REG_STREAMREG5
depricated.REG_LUALIB        = REG_LUALIB
depricated.REG_LUAUSER       = REG_LUAUSER

depricated.STM_START         = STM_START
depricated.STM_STOP          = STM_STOP

depricated.STM_FREQ_MANUAL   = STM_FREQ_MANUAL
depricated.STM_FREQ_AUTO     = STM_FREQ_AUTO
depricated.STM_FREQ_AUTO10   = STM_FREQ_AUTO10
depricated.STM_FREQ_AUTO3    = STM_FREQ_AUTO3
depricated.STM_FREQ_AUTO1    = STM_FREQ_AUTO1
depricated.STM_FREQ_ONCHANGE = STM_FREQ_ONCHANGE

end
