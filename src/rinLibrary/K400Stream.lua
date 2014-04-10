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


-- build rest of K400 on top of rinCon
local tmp = require "rinLibrary.K400Util"
local _M = tmp  
package.loaded["rinLibrary.K400Util"] = nil



  
--  Stream Register Definitions
_M.REG_STREAMDATA       = 0x0040
_M.REG_STREAMMODE       = 0x0041
_M.REG_STREAMREG1       = 0x0042
_M.REG_STREAMREG2       = 0x0043
_M.REG_STREAMREG3       = 0x0044
_M.REG_STREAMREG4       = 0x0045
_M.REG_STREAMREG5       = 0x0046
_M.REG_LUALIB           = 0x0300    -- Should be bor'd with other stream regs
_M.REG_LUAUSER          = 0x0310    -- should be bor'd with base stream regs
_M.STM_START            = 1
_M.STM_STOP             = 0

_M.STM_FREQ_MANUAL      = 0
_M.STM_FREQ_AUTO        = 1
_M.STM_FREQ_AUTO10      = 2
_M.STM_FREQ_AUTO3       = 3
_M.STM_FREQ_AUTO1       = 4
_M.STM_FREQ_ONCHANGE    = 5

_M.freqLib = _M.STM_FREQ_ONCHANGE
_M.freqUser = _M.STM_FREQ_ONCHANGE

_M.availRegistersUser = {
                        [_M.REG_STREAMREG1]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0,
                                              ['typ'] = _M.TYP_LONG}, 
                        [_M.REG_STREAMREG2]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0,
                                              ['typ'] = _M.TYP_LONG}, 
                        [_M.REG_STREAMREG3]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0,
                                              ['typ'] = _M.TYP_LONG}, 
                        [_M.REG_STREAMREG4]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0,
                                              ['typ'] = _M.TYP_LONG}, 
                        [_M.REG_STREAMREG5]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0,
                                              ['typ'] = _M.TYP_LONG}
                    }
_M.streamRegisters = {}

-----------------------------------------------------------------------------
-- Divide the data stream up and run the relevant callbacks
-- @param data Data received from register
-- @param err Potential error message
function _M.streamCallback(data, err)
   
    if err then return end
    if (string.len(data) % 8 ~= 0) or
       (string.find(data,'%X')) then 
          _M.dbg.error('Corrupt Stream Data: ',data)
          return
    end      
    
    for k,v in pairs(_M.availRegistersUser) do
        if v.reg ~= 0 then
            local ind = (k - _M.REG_STREAMREG1) * 8
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
-- @param streamReg Register to stream from (_M.REG_*)
-- @param callback Function to bind to streaming register
-- @param onChange Change parameter
-- return streamReg identity
function _M.addStream(streamReg, callback, onChange)
    local availReg = nil
    
    for k,v in pairs(_M.availRegistersUser) do
        if v.reg == 0 and (availReg == nil or k < availReg) then
            availReg = k
        end
    end

    if availReg == nil then
        return nil, "no more registers available"
    end

    _,_M.availRegistersUser[availReg].dp = _M.getRegDP(streamReg)
    local typ = tonumber(_M.sendRegWait(_M.CMD_RDTYPE,streamReg),16)
    _M.availRegistersUser[availReg].reg = streamReg
    _M.availRegistersUser[availReg].callback = callback
    _M.availRegistersUser[availReg].onChange = onChange
    _M.availRegistersUser[availReg].lastData = ''
    _M.availRegistersUser[availReg].typ = typ
    _M.streamRegistersUser[streamReg] = availReg

    _M.sendReg(_M.CMD_WRFINALHEX, 
                bit32.bor(_M.REG_LUAUSER,_M.REG_STREAMMODE), 
                _M.freqUser)
    _M.sendReg(_M.CMD_WRFINALDEC, 
                bit32.bor(_M.REG_LUAUSER, availReg), 
                streamReg)
    _M.sendReg(_M.CMD_EX, 
                bit32.bor(_M.REG_LUAUSER, _M.REG_STREAMDATA), 
                _M.STM_START)
    
    _M.bindRegister(bit32.bor(_M.REG_LUAUSER,_M.REG_STREAMDATA), _M.streamCallback)
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the device 
-- @param streamReg Register to be removed(_M.REG_*)
function _M.removeStream(streamReg)
    local availReg = _M.streamRegistersUser[streamReg]

     if availReg == nil then return end   -- stream already removed
     
    _M.sendRegWait(_M.CMD_WRFINALDEC,bit32.bor(_M.REG_LUAUSER,availReg),0)
    _M.unbindRegister(bit32.bor(_M.REG_LUAUSER, availReg))
    
    _M.availRegistersUser[availReg].reg = 0
    _M.streamRegistersUser[streamReg] = nil
end

_M.availRegistersLib = {
                        [_M.REG_STREAMREG1]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0}, 
                        [_M.REG_STREAMREG2]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0}, 
                        [_M.REG_STREAMREG3]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0}, 
                        [_M.REG_STREAMREG4]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0}, 
                        [_M.REG_STREAMREG5]= {['reg'] = 0, 
                                              ['callback'] = nil, 
                                              ['onChange'] = 'change', 
                                              ['lastData'] = '',
                                              ['dp'] = 0}
                    }
_M.streamRegistersLib = {}

-----------------------------------------------------------------------------
-- Divide the data stream up and run the callbacks for Library streams
-- @param data Data received from register
-- @param err Potential error message
function _M.streamCallbackLib(data, err)
    
    if err then return end
    if (string.len(data) % 8 ~= 0) or
       (string.find(data,'%X')) then 
          _M.dbg.error('Corrupt Lib Stream Data: ',data)
          return
    end      
    
    for k,v in pairs(_M.availRegistersLib) do
        if v.reg ~= 0 then
            local ind = (k - _M.REG_STREAMREG1) * 8
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
-- @param streamReg Register to stream from (_M.REG_*)
-- @param callback Function to bind to streaming register
-- @param onChange Change parameter
-- return streamReg indentity
function _M.addStreamLib(streamReg, callback, onChange)
    local availReg = nil
    
    for k,v in pairs(_M.availRegistersLib) do
        if v.reg == 0 and (availReg == nil or k < availReg) then
            availReg = k
        end
    end

    if availReg == nil then
        return nil, "no more registers available"
    end

    _,_M.availRegistersLib[availReg].dp = _M.getRegDP(streamReg)
    _M.availRegistersLib[availReg].reg = streamReg
    _M.availRegistersLib[availReg].callback = callback
    _M.availRegistersLib[availReg].onChange = onChange
    _M.availRegistersLib[availReg].lastData = ''
    
    _M.streamRegistersLib[streamReg] = availReg

    _M.sendReg(_M.CMD_WRFINALHEX, 
                bit32.bor(_M.REG_LUALIB,_M.REG_STREAMMODE), 
                _M.freqLib)
    _M.sendReg(_M.CMD_WRFINALDEC, 
                bit32.bor(_M.REG_LUALIB, availReg), 
                streamReg)
    _M.sendReg(_M.CMD_EX, 
                bit32.bor(_M.REG_LUALIB, _M.REG_STREAMDATA), 
                _M.STM_START)
   
   _M.bindRegister(bit32.bor(_M.REG_LUALIB,_M.REG_STREAMDATA), _M.streamCallbackLib)
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the library set of streams 
-- @param streamReg Register to be removed(_M.REG_*)
function _M.removeStreamLib(streamReg)
    local availReg = _M.streamRegistersLib[streamReg]

     if availReg == nil then return end   -- stream already removed
     
    _M.sendRegWait(_M.CMD_WRFINALDEC,bit32.bor(_M.REG_LUALIB,availReg),0)
    _M.unbindRegister(bit32.bor(_M.REG_LUALIB, availReg))
    
    _M.availRegistersLib[availReg].reg = 0
    _M.streamRegistersLib[streamReg] = nil
end

-------------------------------------------------------------------------------
--  Called to cleanup any unused streaming
function _M.streamCleanup()
    _M.sendRegWait(_M.CMD_EX,
                bit32.bor(_M.REG_LUAUSER, _M.REG_STREAMDATA),
                _M.STM_STOP)  -- stop streaming first
    _M.sendRegWait(_M.CMD_EX,
                bit32.bor(_M.REG_LUALIB, _M.REG_STREAMDATA),
                _M.STM_STOP)  -- stop streaming first

    for k,v in pairs(_M.availRegistersUser) do
        _M.sendRegWait(_M.CMD_WRFINALDEC, bit32.bor(_M.REG_LUAUSER, k), 0)
        v.reg = 0
    end
    for k,v in pairs(_M.availRegistersLib) do
        _M.sendRegWait(_M.CMD_WRFINALDEC, bit32.bor(_M.REG_LUALIB, k), 0)
        v.reg = 0
    end
    
    _M.streamRegistersUser = {}
    _M.streamRegistersLib = {}

end

-------------------------------------------------------------------------------
--  Set the frequency used for streaming
-- @param freq Frequency of streaming (_M.STM_FREQ_*)
function _M.setStreamFreq(freq)
    local freq = freq or _M.freqUser
    _M.freqUser = freq
end

-------------------------------------------------------------------------------
--  Set the frequency used for library streaming
-- @param freq Frequency of streaming (_M.STM_FREQ_*)
function _M.setStreamFreqLib(freq)
    local freq = freq or _M.freqLib
    _M.freqLib = freq
end


-------------------------------------------------------------------------------
-- Called to force all stream registers to resend current state
function _M.renewStreamData()
  local streamUser = false
   for k,v in pairs(_M.availRegistersLib) do
            v.lastData = ''
   end
   for k,v in pairs(_M.availRegistersUser) do
            if v.reg ~= 0 then
                streamUser = true
            end    
            v.lastData = ''
   end 
   for k,v in pairs(_M.IOBinds) do
       v.lastStatus = 0xFFFFFFFF
   end       
   for k,v in pairs(_M.SETPBinds) do
       v.lastStatus = 0xFFFFFFFF
   end       
   for k,v in pairs(_M.statBinds) do
       v.lastStatus = 0xFFFFFFFF
   end       
   for k,v in pairs(_M.eStatBinds) do
       v.lastStatus = 0xFFFFFFFF
   end       
    

   if streamUser then
      _M.send(nil,_M.CMD_RDFINALHEX,
                 bit32.bor(_M.REG_LUAUSER,_M.REG_STREAMDATA),
                 '','reply')
    end 
   _M.send(nil,_M.CMD_RDFINALHEX,
                 bit32.bor(_M.REG_LUALIB,_M.REG_STREAMDATA),
                 '','reply')
        
end


-------------------------------------------------------------------------------
-- Called to initalise the instrument and read initial conditions
function _M.init()
    _M.renewStreamData()
    _M.sendKey(_M.KEY_CANCEL,'long')
end


return _M
