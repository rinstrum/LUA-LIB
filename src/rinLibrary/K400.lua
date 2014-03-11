-------------------------------------------------------------------------------
-- Library for K400 application support.
-- Provides wrappers for all device services
-- @module rinLibrary.K400
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

-- build rest of K400 on top of rinCon
local con = require "rinLibrary.rinCon"
local _M = con  

local string = string
local tonumber = tonumber
local package = package
local type = type
local math = math
local pairs = pairs
local ipairs = ipairs
local tostring = tostring

local bit32 = require "bit"

-- remove information that rinCON is already loaded to facilitate multiple connections
package.loaded["rinLibrary.rinCon"] = nil

-------------------------------------------------------------------------------
--- Register Functions.
-- Functions to read, write and execute commands on instrument registers directly
-- @section registers
 
_M.REG_KEYBUFFER        = 0x0008
_M.REG_LCD              = 0x0009

_M.REG_SAVESETTING      = 0x0010

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
-- @field REG_USERID2         the first 2 are integers
-- @field REG_USERID3         the last 3 are weight values
-- @field REG_USERID4         
-- @field REG_USERID5       
-- @field REG_USERNUM1        Data for 5 User ID numbers
-- @field REG_USERNUM2      
-- @field REG_USERNUM3      
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

--- K412 Product Registers.
--@table productRegisters
-- @field REG_ACTIVE_PRODUCT_NO    Read the Active Product Number, Write to set the active product by number
-- @field REG_ACTIVE_PRODUCT_NAME  Read the Active Product Name, Write to set Active Product by name
-- @field REG_CLR_ALL_TOTALS       Clears all product totals (EXECUTE) 
-- @field REG_CLR_DOCKET_TOTALS    Clears all docket sub-totals (EXECUTE)
-- @field REG_SELECT_PRODUCT_NO    Read the Selected Product Number, Write to set the Selected product by number
-- @field REG_SELECT_PRODUCT_NAME  Read the Selected Product Name, Write to set the Selected product by Name
-- @field REG_SELECT_PRODUCT_DELETE Delete Selected Product (EXECUTE)
-- @field REG_SELECT_PRODUCT_RENAME Write to change name of selected product

_M.REG_ACTIVE_PRODUCT_NO        = 0xB000
_M.REG_ACTIVE_PRODUCT_NAME      = 0xB006
_M.REG_CLR_ALL_TOTALS           = 0xB002
_M.REG_CLR_DOCKET_TOTALS        = 0xB004
_M.REG_SELECT_PRODUCT_NO        = 0xB00F
_M.REG_SELECT_PRODUCT_NAME      = 0xB010
_M.REG_SELECT_PRODUCT_DELETE    = 0xB011
_M.REG_SELECT_PRODUCT_RENAME    = 0xB012

_M.REG_SYSERR           = 0x0022
_M.REG_ABSMVV           = 0x0023

_M.REG_GROSSNET         = 0x0025
_M.REG_GROSS            = 0x0026
_M.REG_NET              = 0x0027
_M.REG_TARE             = 0x0028
_M.REG_PEAKHOLD         = 0x0029
_M.REG_MANHOLD          = 0x002A

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
-- @param crc - 'crc' if message sent with crc, false (default) otherwise
function _M.sendReg(cmd, reg, data, crc)
  _M.send(nil, cmd, reg, data, "noReply",crc)
end

-------------------------------------------------------------------------------
-- Called to send command and wait for response
-- @param cmd CMD_  command
-- @param reg REG_  register 
-- @param data to send
-- @param t timeout in sec
-- @return reply received from instrument, nil if error
-- @return err error string if error received, nil otherwise
-- @param crc - 'crc' if message sent with crc, false (default) otherwise
function _M.sendRegWait(cmd, reg, data, t, crc)
    
    local t = t or 0.500
    
    if reg == nil then
          return nil, 'Nil Register'
    end 
    
    local waiting = true
    local regData = ''
    local regError = ''
    local function waitf(data, err)
          regData = data
          regErr = err
          waiting = false
    end  
    
    local f = _M.deviceRegisters[reg]
    _M.bindRegister(reg, waitf)  
    _M.send(nil, cmd, reg, data, "reply", crc)
    local tmr = _M.system.timers.addTimer(0, t, waitf, nil,'Timeout')

    while waiting do
        _M.system.handleEvents()
    end
    
    if f then
        _M.bindRegister(reg, f)  
    else 
        _M.unbindRegister(reg)
    end
    
    _M.system.timers.removeTimer(tmr)   
    return regData, regErr    
end

-------------------------------------------------------------------------------
-- processes the return string from CMD_RDLIT command
-- if data is a floating point number then the converted number is returned
-- otherwise the original data string is returned
-- @param data returned from _CMD_RDLIT 
-- @return floating point number or data string
function _M.literalToFloat(data)
      local a,b = string.find(data,'[+-]?%s*%d*%.?%d*')
      if not a then
           return data
      else
       data = string.gsub(string.sub(data,a,b),'%s','')  -- remove spaces
       return tonumber(data)    
      end   
end

-------------------------------------------------------------------------------
-- called to convert hexadecimal return string to a floating point number
-- @param data returned from _CMD_RDFINALHEX or from stream
-- @param dp decimal position (if nil then instrument dp used)
-- @return floating point number
function _M.toFloat(data, dp)
   local dp = dp or _M.settings.dispmode[_M.DISPMODE_PRIMARY].dp  -- use instrument dp if not specified otherwise
   
   data = tonumber(data,16)
   if data > 0x7FFFFFFF then
        data = data - 0xFFFFFFFF - 1
    end
    
   for i = dp,1,-1 do
      data = data / 10
   end
   
   return data
end

-------------------------------------------------------------------------------
-- Called to read register contents
-- @param reg REG_  register 
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
function _M.readReg(reg)
    local data, err
    
    data, err = _M.sendRegWait(_M.CMD_RDLIT,reg)
    if err then
       _M.dbg.debug('Read Error', err)
       return nil, err
    else
       return _M.literalToFloat(data), nil
    end
end

-------------------------------------------------------------------------------
-- Called to write data to an instrument register 
-- @param reg REG_  register 
-- @param data to send
function _M.writeReg(reg, data)
  _M.sendRegWait(_M.CMD_WRFINALDEC, reg, data)
end

-------------------------------------------------------------------------------
-- Called to run a register execute command with data as the execute parameter 
-- @param reg REG_  register 
-- @param data to send
function _M.exReg(reg, data)
  _M.sendRegWait(_M.CMD_EX, reg, data)
end

-------------------------------------------------------------------------------
---  General Utilities.
-- General Functions for configuring the instrument
-- @section general

_M.REG_LCDMODE          = 0x000D
-------------------------------------------------------------------------------
-- Called to setup LCD control
-- @param mode  is 'lua' to control display from script or 'default' 
-- to return control to the default instrement application 
function _M.lcdControl(mode)
    local mode = mode or ''
    
    if mode == 'lua' then
     _M.sendRegWait(_M.CMD_EX,_M.REG_LCDMODE,2)
    else
     _M.sendRegWait(_M.CMD_EX,_M.REG_LCDMODE,1)
    end
end 

-------------------------------------------------------------------------------
-- Called to connect the K400 library to a socket and a system
-- @param model Software model expected for the instrument (eg "K401")
-- @param sockA, sockB TCP sockets to connect  SERA and SERB ports
-- @param app application framework
_M.model = ''
function _M.connect(model,sockA, sockB, app)
    _M.model = model
    _M.socketA = sockA
    _M.socketB = sockB
    _M.app = app
    _M.system = app.system
    local ip, port = sockA:getpeername()
end 

-------------------------------------------------------------------------------
-- Called to read a register value and return value and dp position
-- Used to work out the dp position of a register value so subsequent 
-- reads can use the hexadecimal format and convert locally using 
-- toFloat 
-- @param reg  register to read
-- @return register value number and dp position
function _M.getRegDP(reg)
    local data, err = _M.sendRegWait(_M.CMD_RDLIT,reg)
    if err then
       _M.dbg.error('getDP: ', reg, err)
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

-------------------------------------------------------------------------------
-- Called to save any changed settings and re-initialise instrument 
--
function _M.saveSettings()
    _M.sendRegWait(_M.CMD_EX,_M.REG_SAVESETTING)
end

_M.REG_PRIMARY_DISPMODE   = 0x0306
_M.REG_SECONDARY_DISPMODE = 0x0307

_M.DISPMODE_PRIMARY      = 1
_M.DISPMODE_PIECES       = 2
_M.DISPMODE_SECONDARY    = 3
_M.units = {"  ","kg","lb","t ","g ","oz","N ","  ","p ","l ","  "}
_M.countby = {1,2,5,10,20,50,100,200,500}
_M.settings = {}
_M.settings.fullscale = 3000
_M.settings.dispmode = {}
_M.settings.dispmode[_M.DISPMODE_PRIMARY] =   {reg = _M.REG_PRIMARY_DISPMODE, units = _M.units[2], dp = 0, countby = {1,2,5}}
_M.settings.dispmode[_M.DISPMODE_PIECES] =    {reg = 0,                       units = _M.units[9], dp = 0, countby = {1,1,1}}
_M.settings.dispmode[_M.DISPMODE_SECONDARY] = {reg = _M.REG_SECONDARY_DISPMODE,units = _M.units[3], dp = 0, countby = {2,5,10}}
_M.settings.curDispMode = _M.DISPMODE_PRIMARY
_M.settings.hiRes = false
_M.settings.curRange = 1

function _M.readSettings()
    _M.settings.fullscale = _M.getRegDP(_M.REG_FULLSCALE)
    for mode = _M.DISPMODE_PRIMARY, _M.DISPMODE_SECONDARY do
        if _M.settings.dispmode[mode].reg ~= 0 then
            local data, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.settings.dispmode[mode].reg)
            if data and not err then 
                data = tonumber(data, 16)
                if data ~= nil then
                    _M.settings.dispmode[mode].dp = bit32.band(data,0x0000000F)
                    _M.settings.dispmode[mode].units = _M.units[1+bit32.band(bit32.rshift(data,4),0x0000000F)]
                    _M.settings.dispmode[mode].countby[3] = _M.countby[1+bit32.band(bit32.rshift(data,8),0x000000FF)]
                    _M.settings.dispmode[mode].countby[2] = _M.countby[1+bit32.band(bit32.rshift(data,16),0x000000FF)]
                    _M.settings.dispmode[mode].countby[1] = _M.countby[1+bit32.band(bit32.rshift(data,24),0x000000FF)]
                else
                    _M.dbg.warn('Bad settings data: ', data)
                end
            else
                _M.dbg.warn('Incorrect read: ',data,err)
            end
        end
    end
    _M.saveAutoTopLeft = _M.readAutoTopLeft()
    _M.saveAutoBotLeft = _M.readAutoBotLeft()
 end
 
-------------------------------------------------------------------------------
-- Called to configure the instrument library
-- @return nil if ok or error string if model doesn't match
function _M.configure(model)
    local s, err = _M.sendRegWait(_M.CMD_RDLIT,_M.REG_SOFTMODEL)
    if not err then 
        _M.model = s
        _M.serialno, err = _M.sendRegWait(_M.CMD_RDLIT,_M.REG_SERIALNO)
    end
    
     _M.dbg.info(_M.model,_M.serialno)
     
    _M.readSettings()
    
    if err then 
      _M.model = ''
      return err
    elseif model ~= _M.model then
      return "Wrong Software Model"
    else  
      return nil    
    end  
end

-------------------------------------------------------------------------------
-- Called to convert a floating point value to a decimal integer based on then
-- primary instrument weighing settings 
-- @param v is value to convert
-- @param dp decimal position (if nil then instrument dp used) 
-- @return floating point value suitable for a WRFINALDEC
function _M.toPrimary(v, dp)
 local dp = dp or _M.settings.dispmode[_M.settings.curDispMode].dp  -- use instrument dp if not specified otherwise
 
 if type(v) == 'string' then
    v = tonumber(v)
  end   
 for i = 1,dp do
    v = v*10
  end
  v = math.floor(v+0.5)
  return(v)
end

-------------------------------------------------------------------------------
-- Read a RIS file and send valid commands to the device
-- @param filename Name of the RIS file
function _M.loadRIS(filename)
    local file = io.open(filename, "r")
    if not file then
      _M.dbg.warn('RIS file not found',filename)
      return
    end  
    for line in file:lines() do
         if (string.find(line, ':') and tonumber(string.sub(line, 1, 8), 16)) then
            local endCh = string.sub(line, -1, -1)
            if endCh ~= '\r' and endCh ~= '\n' then
                 line = line .. ';'
            end     
       
            _,cmd,reg,data,err = _M.processMsg(line)
            if err then
               _M.dbg.error('RIS error: ',err)
            end   
            _M.sendRegWait(cmd,reg,data)
         end
    end
    _M.saveSettings()
    file:close()
end

-------------------------------------------------------------------------------- 
--- Streaming.
-- This section is for functions associated with streaming registers 
-- @section Streaming
  
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
    
    _M.bindRegister(bit32.bor(_M.REG_LUAUSER,_M.REG_STREAMDATA), _M.streamCallback)
    
    for k,v in pairs(_M.availRegistersUser) do
        if v.reg == 0 and (availReg == nil or k < availReg) then
            availReg = k
        end
    end

    if availReg == nil then
        return nil, "no more registers available"
    end
    
    _M.availRegistersUser[availReg].reg = streamReg
    _M.availRegistersUser[availReg].callback = callback
    _M.availRegistersUser[availReg].onChange = onChange
    _M.availRegistersUser[availReg].lastData = ''
    _,_M.availRegistersUser[availReg].dp = _M.getRegDP(streamReg)
    local typ = tonumber(_M.sendRegWait(_M.CMD_RDTYPE,streamReg),16)
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
    
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the device 
-- @param streamReg Register to be removed(_M.REG_*)
function _M.removeStream(streamReg)
    local availReg = _M.streamRegistersUser[streamReg]

     if availReg == nil then return end   -- stream already removed
     
    _M.sendReg(_M.CMD_WRFINALDEC,bit32.bor(_M.REG_LUAUSER,availReg),0)
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
          _M.dbg.error('Corrupt Stream Data: ',data)
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
    
    _M.bindRegister(bit32.bor(_M.REG_LUALIB,_M.REG_STREAMDATA), _M.streamCallbackLib)
    
    for k,v in pairs(_M.availRegistersLib) do
        if v.reg == 0 and (availReg == nil or k < availReg) then
            availReg = k
        end
    end

    if availReg == nil then
        return nil, "no more registers available"
    end
    
    _M.availRegistersLib[availReg].reg = streamReg
    _M.availRegistersLib[availReg].callback = callback
    _M.availRegistersLib[availReg].onChange = onChange
    _M.availRegistersLib[availReg].lastData = ''
    _,_M.availRegistersLib[availReg].dp = _M.getRegDP(streamReg)
    
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
    
    return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the library set of streams 
-- @param streamReg Register to be removed(_M.REG_*)
function _M.removeStreamLib(streamReg)
    local availReg = _M.streamRegistersLib[streamReg]

     if availReg == nil then return end   -- stream already removed
     
    _M.sendReg(_M.CMD_WRFINALDEC,bit32.bor(_M.REG_LUALIB,availReg),0)
    _M.unbindRegister(bit32.bor(_M.REG_LUALIB, availReg))
    
    _M.availRegistersLib[availReg].reg = 0
    _M.streamRegistersLib[streamReg] = nil
end

-------------------------------------------------------------------------------
--  Called to cleanup any unused streaming
function _M.streamCleanup()
    _M.sendReg(_M.CMD_EX,
                bit32.bor(_M.REG_LUAUSER, _M.REG_STREAMDATA),
                _M.STM_STOP)  -- stop streaming first
    _M.sendReg(_M.CMD_EX,
                bit32.bor(_M.REG_LUALIB, _M.REG_STREAMDATA),
                _M.STM_STOP)  -- stop streaming first

    for k,v in pairs(_M.availRegistersUser) do
        _M.sendReg(_M.CMD_WRFINALDEC, bit32.bor(_M.REG_LUAUSER, k), 0)
        v.reg = 0
    end
    for k,v in pairs(_M.availRegistersLib) do
        _M.sendReg(_M.CMD_WRFINALDEC, bit32.bor(_M.REG_LUALIB, k), 0)
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
--- Status Monitoring.
-- Functions are associated with the status monitoring 
-- @section status 

--- Status Bits for REG_SYSSTATUS.
--@table sysstatus
-- @field SYS_OVERLOAD         Scale overloaded
-- @field SYS_UNDERLOAD        Scale underload
-- @field SYS_ERR              Error active 
-- @field SYS_SETUP            Instrument in setup mode
-- @field SYS_CALINPROG      Instrument calibration in progress
-- @field SYS_MOTION           Weight unstable
-- @field SYS_CENTREOFZERO     Centre of Zero (within 0.25 divisions of zero)
-- @field SYS_ZERO             Weight within zero band setting
-- @field SYS_NET              Instrument in Net mode

_M.SYS_OVERLOAD         = 0x00020000
_M.SYS_UNDERLOAD        = 0x00010000
_M.SYS_ERR              = 0x00008000
_M.SYS_SETUP            = 0x00004000
_M.SYS_CALINPROG        = 0x00002000
_M.SYS_MOTION           = 0x00001000
_M.SYS_CENTREOFZERO     = 0x00000800
_M.SYS_ZERO             = 0x00000400
_M.SYS_NET              = 0x00000200

_M.REG_LUA_STATUS   = 0x0329
_M.REG_LUA_ESTAT    = 0x0305
_M.REG_LUA_STAT_RTC = 0x032A
_M.REG_LUA_STAT_RDG = 0x032B
_M.REG_LUA_STAT_IO  = 0x032C
_M.REG_IOSTATUS     = 0x0051
_M.REG_SETPSTATUS  = 0x032E 

_M.lastIOStatus = 0

-- Status
_M.STAT_NET             = 0x00000001
_M.STAT_GROSS           = 0x00000002
_M.STAT_ZERO            = 0x00000004
_M.STAT_NOTZERO         = 0x00000008
_M.STAT_COZ             = 0x00000010
_M.STAT_NOTCOZ          = 0x00000020
_M.STAT_MOTION          = 0x00000040
_M.STAT_NOTMOTION       = 0x00000080
_M.STAT_RANGE1          = 0x00000100
_M.STAT_RANGE2          = 0x00000200
_M.STAT_PT              = 0x00000400
_M.STAT_NOTPT           = 0x00000800
_M.STAT_ERROR           = 0x00001000
_M.STAT_ULOAD           = 0x00002000
_M.STAT_OLOAD           = 0x00004000
_M.STAT_NOTERROR        = 0x00008000
-- K412 specific status bits
_M.STAT_IDLE            = 0x00010000
_M.STAT_RUN             = 0x00020000
_M.STAT_PAUSE           = 0x00040000
_M.STAT_SLOW            = 0x00080000
_M.STAT_MED             = 0x00100000
_M.STAT_FAST            = 0x00200000
_M.STAT_TIME            = 0x00400000
_M.STAT_INPUT           = 0x00800000
_M.STAT_NO_INFO         = 0x01000000
_M.STAT_FILL            = 0x02000000
_M.STAT_DUMP            = 0x04000000
_M.STAT_PULSE           = 0x08000000
_M.STAT_START           = 0x10000000
_M.STAT_NO_TYPE         = 0x20000000
_M.STAT_INIT            = 0x80000000

-- Extended status bits
_M.ESTAT_HIRES           = 0x00000001
_M.ESTAT_DISPMODE        = 0x00000006
_M.ESTAT_DISPMODE_RS     = 1
_M.ESTAT_RANGE           = 0x00000018
_M.ESTAT_RANGE_RS        = 3
_M.ESTAT_INIT            = 0x01000000
_M.ESTAT_RTC             = 0x02000000
_M.ESTAT_RDG             = 0x04000000
_M.ESTAT_IO              = 0x08000000
_M.ESTAT_SER1            = 0x10000000
_M.ESTAT_SER2            = 0x20000000

_M.statBinds = {}
_M.statID = nil          

_M.eStatBinds = {}
_M.eStatID = nil          

_M.IOBinds = {}
_M.IOID = nil   

_M.SETPBinds = {}
_M.SETPTID = nil   

-------------------------------------------------------------------------------
-- Called when status changes are streamed 
-- @param data Data on status streamed
-- @param err Potential error message
function _M.statusCallback(data, err)
    _M.curStatus = data    
    for k,v in pairs(_M.statBinds) do
       local status = bit32.band(data,k)
       if status ~= v.lastStatus  then
           if v.running then
               _M.dbg.warn('Status Event lost: ',string.format('%08X %08X',k,status))
           else
              v.running = true
              v.lastStatus = status
              v.f(k, status ~= 0)
              v.running = false
           end   
        end     
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a status bit
-- @param stat STAT_ status bit
-- @param callback Function to run when there is an event on change in status
function _M.setStatusCallback(stat, callback)
    _M.statBinds[stat] = {}
    _M.statBinds[stat]['f'] = callback
    _M.statBinds[stat]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Called when IO status changes are streamed 
-- @param data Data on SETP status streamed
-- @param err Potential error message
function _M.IOCallback(data, err)
    _M.curIO = data    
    for k,v in pairs(_M.IOBinds) do       
       local status = bit32.band(data,k)
       if k == 0 then  --handle the all IO case
          status = _M.curIO
       end   
       if status ~= v.lastStatus  then
           if v.running then
               if k == 0 then
                   _M.dbg.warn('IO Event lost: ',v.IO,string.format('%08X',status))
               else
                   _M.dbg.warn('IO Event lost: ',v.IO,status ~=0)
               end    
           else
              v.running = true
              v.lastStatus = status
              if k == 0 then
                  v.f(status)
              else
                  v.f(v.IO, status ~= 0)
              end    
              v.running = false
           end   
        end     
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a IO 
-- @param IO 1..32
-- @param callback Function taking IO and on/off status as parameters
-- @usage
-- function handleIO1(IO, active)
--    if (active) then
--       print (IO,' is on!')
--    end
-- end
-- dwi.setIOCallback(1,handleIO1)
--
function _M.setIOCallback(IO, callback)
    
    if callback then
       local status = bit32.lshift(0x00000001,IO-1)
       _M.IOBinds[status] = {}
       _M.IOBinds[status]['IO'] = IO
       _M.IOBinds[status]['f'] = callback
       _M.IOBinds[status]['lastStatus'] = 0xFFFFFFFF
    else
       _M.dbg.warn('','setIOCallback:  nil value for callback function')
    end       
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any IO status changes 
-- @param callback Function taking current IO status as a parameter
-- @usage
-- function handleIO(data)
--    -- 4 bits of status information for IO 3..6 turned into a grading indication 
--    curGrade = bit32.rshift(bit32.band(data,0x03C),2) 
-- end
-- dwi.setAllIOCallback(handleIO)
--
function _M.setAllIOCallback(callback)
    _M.IOBinds[0] = {}   -- setup a callback for all SETP changes 
    _M.IOBinds[0]['IO'] = 'All'
    _M.IOBinds[0]['f'] = callback
    _M.IOBinds[0]['lastStatus'] = 0xFFFFFF
end

-------------------------------------------------------------------------------
-- Called when SETP status changes are streamed 
-- @param data Data on SETP status streamed
-- @param err Potential error message
function _M.SETPCallback(data, err)
    _M.curSETP = bit32.band(data, 0xFFFF)    
    for k,v in pairs(_M.SETPBinds) do       
       local status = bit32.band(data,k)
       if k == 0 then  --handle the all setp case
          status = _M.curSETP
       end   
       if status ~= v.lastStatus  then
           if v.running then
               if k == 0 then
                   _M.dbg.warn('SETP Event lost: ',v.SETP,string.format('%04X',status))
               else
                   _M.dbg.warn('SETP Event lost: ',v.SETP,status ~=0)
               end    
           else
              v.running = true
              v.lastStatus = status
              if k == 0 then
                  v.f(status)
              else
                  v.f(v.SETP, status ~= 0)
              end    
              v.running = false
           end   
        end     
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a SETP 
-- @param SETP 1..16
-- @param callback Function taking SETP and on/off status as parameters
-- @usage
-- function handleSETP1(SETP, active)
--    if (active) then
--       print (SETP,' is on!')
--    end
-- end
-- dwi.setSETPCallback(1,handleSETP1)
--
function _M.setSETPCallback(SETP, callback)
    local status = bit32.lshift(0x00000001,SETP-1)
    _M.SETPBinds[status] = {}
    _M.SETPBinds[status]['SETP'] = SETP
    _M.SETPBinds[status]['f'] = callback
    _M.SETPBinds[status]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any SETP status changes 
-- @param callback Function taking current SETP status as a parameter
-- @usage
-- function handleSETP(data)
--    -- 4 bits of status information for SETP 3..6 turned into a grading indication 
--    curGrade = bit32.rshift(bit32.band(data,0x03C),2) 
-- end
-- dwi.setAllSETPCallback(handleSETP)
--
function _M.setAllSETPCallback(callback)
    _M.SETPBinds[0] = {}   -- setup a callback for all SETP changes 
    _M.SETPBinds[0]['SETP'] = 'All'
    _M.SETPBinds[0]['f'] = callback
    _M.SETPBinds[0]['lastStatus'] = 0xFFFFFF
end

-------------------------------------------------------------------------------
-- Called when extended status changes are streamed 
-- @param data Data on status streamed
-- @param err Potential error message
function _M.eStatusCallback(data, err)
   if bit32.band(data,_M.ESTAT_HIRES) > 0 then
       _M.settings.hiRes = true
   else 
       _M.settings.hiRes = false
   end    
     
   _M.settings.curDispMode = 1 + bit32.rshift(bit32.band(data,_M.ESTAT_DISPMODE),_M.ESTAT_DISPMODE_RS)
   _M.settings.curRange    = 1 + bit32.rshift(bit32.band(data,_M.ESTAT_RANGE),_M.ESTAT_RANGE_RS)
   
    for k,v in pairs(_M.eStatBinds) do
       local status = bit32.band(data,k)
       if status ~= v.lastStatus  then
           if v.running then
              _M.dbg.warn('Ext Status Event lost: ',string.format('%08X',k),status ~= 0)
           else
              v.running = true
              v.lastStatus = status
              if v.mainf then
                  v.mainf(k,status ~= 0)
              end    
              if v.f then
                  v.f(k, status ~= 0)
              end  
              v.running = false      
            end              
        end     
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for an extended status bit
-- @param eStat ESTAT_ status bit
-- @param callback Function to run when there is an event on change in status
function _M.setEStatusCallback(eStat, callback)
    _M.eStatBinds[eStat] = _M.eStatBinds[eStat] or {}
    _M.eStatBinds[eStat]['f'] = callback
    _M.eStatBinds[eStat]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Set the main library callback function for an extended status bit
-- @param eStat ESTAT_ status bit
-- @param callback Function to run when there is an event on change in status
function _M.setEStatusMainCallback(eStat, callback)
    _M.eStatBinds[eStat] = _M.eStatBinds[eStat] or {}
    _M.eStatBinds[eStat]['mainf'] = callback
    _M.eStatBinds[eStat]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Called to get current instrument status 
-- @return 32 bits of status data with bits as per STAT_ definitions
function _M.getCurStatus()
  return _M.curStatus
end

-------------------------------------------------------------------------------
-- Called to check state of current instrument status 
-- @return true if any of the status bits are set in cur instrument status
-- @usage
-- dwi.enableOutput(5) 
-- if dwi.anyStatusSet(dwi.STAT_MOTION,
--                     dwi.STAT_ERR,
--                     dwi.STAT_OLOAD,
--                     dwi.STAT_ULOAD) then
--     dwi.turnOn(5)  -- turn on output 5 if motion or any errors
-- else
--     dwi.turnOff(5)
-- end 
function _M.anyStatusSet(...)
  local ret = false
  
  if arg.n == 0 then
     return false
  end
  
  for i,v in ipairs(arg) do
     if bit32.band(_M.curStatus,v) ~= 0 then
        ret = true
     end
   end     
  
  return  ret
end

-------------------------------------------------------------------------------
-- Called to check state of current instrument status 
-- @return true if all of the status bits are set in cur instrument status
-- @usage
-- dwi.enableOutput(5) 
-- if dwi.allStatusSet(dwi.STAT_NOTMOTION,
--                     dwi.STAT_NOTZERO,
--                     dwi.STAT_GROSS) then
--     dwi.turnOn(5)  -- turn on output 5 if stable gross weight not in zeroband
-- else
--     dwi.turnOff(5)
-- end 
function _M.allStatusSet(...)
  local ret = true
  
  if arg.n == 0 then
     return false
  end
  
  for i,v in ipairs(arg) do
     if bit32.band(_M.curStatus,v) == 0 then
        ret = false
     end
   end     
  
  return  ret
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO 
-- @return 32 bits of IO data 
function _M.getCurIO()
  return _M.curIO
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO as a string of 1s and 0s 
-- @return 32 characters of IO data
-- @local 
function _M.getBitStr(data,bits)
  local s = {}
  for i = bits-1,0,-1 do
    if bit32.band(data,bit32.lshift(0x01,i)) ~= 0 then
        ch = '1'
    else
        ch = '0' 
    end        
    table.insert(s,ch)
  end  
  return(table.concat(s))
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO as a string of 1s and 0s 
-- @return 32 characters of IO data 
function _M.getCurIOStr()
  return getBitStr(_M.curIO,32)
end

local function anyBitSet(data,...)
  local ret = false
  
  if arg.n == 0 then
     return false
  end
  
  for i,v in ipairs(arg) do
     
     if bit32.band(bit32.lshift(0x01,v-1),data) ~= 0 then
        ret = true
     end
   end     
  
  return  ret
end

local function allBitSet(data,...)
  local ret = true
  
  if arg.n == 0 then
     return false
  end
  
  for i,v in ipairs(arg) do
     if bit32.band(bit32.lshift(0x01,v-1),data) == 0 then
        ret = false
     end
   end     
  
  return  ret
end

-------------------------------------------------------------------------------
-- Called to check state of current IO 
-- @return true if any of the listed IO are active
-- @usage
-- dwi.enableOutput(3) 
-- if not dwi.anyIOSet(1,2,4,5) then
--     dwi.turnOn(3)  -- turn on output 3 if no other outputs on
-- else
--     dwi.turnOff(3)
-- end 
function _M.anyIOSet(...)
  return anyBitSet(_M.curIO,...)
end

-------------------------------------------------------------------------------
-- Called to check state of IO 
-- @return true if all of the listed IO are active
-- @usage
-- dwi.enableOutput(3) 
-- if dwi.allIOSet(1,2) then
--     dwi.turnOn(3)  -- turn on output 3 if IO 1 and 2 both on
-- else
--     dwi.turnOff(3)
-- end 
function _M.allIOSet(...)
   return(allBitSet(_M.curIO,...))
end

-------------------------------------------------------------------------------
-- Called to get current state of the 16 setpoints 
-- @return 16 bits of SETP status data 
function _M.getCurSETP()
  return _M.curSETP
end

-------------------------------------------------------------------------------
-- Called to check state of current IO 
-- @return true if any of the listed IO are active
-- @usage
-- dwi.enableOutput(1) 
-- if not dwi.anySETPSet(1,2) then
--     dwi.turnOn(1)  -- turn on output 1 if setpoints 1 and 2 are both inactive 
-- else
--     dwi.turnOff(1)
-- end 
function _M.anySETPSet(...)
  return anyBitSet(_M.curSETP,...)
end

-------------------------------------------------------------------------------
-- Called to check state of IO 
-- @return true if all of the listed IO are active
-- @usage
-- dwi.enableOutput(1) 
-- if dwi.allSETPSet(1,2) then
--     dwi.turnOn(1)  -- turn on output 1 if Setpoints 1 and 2 are active
-- else
--     dwi.turnOff(1)
-- end 
function _M.allIOSet(...)
  return(allBitSet(_M.curSETP,...))
end

-------------------------------------------------------------------------------
-- Wait until selected status bits are true 
-- @param stat status bits to monitor
-- @usage
-- dwi.waitStatus(dwi.STAT_NOTMOTION) -- wait for no motion
-- dwi.waitStatus(dwi.STAT_COZ)  -- wait for Centre of zero
-- dwi.waitStatus(bit32.bor(dwi.STAT_ZERO,
--                          dwi.STAT_NOTMOTION)) -- wait for no motion and zero 
--
function _M.waitStatus(stat)
   while bit32.bor(_M.curStatus,stat) do
     _M.system.handleEvents()
   end 
end

-------------------------------------------------------------------------------
-- Wait until IO is in a particular state 
-- @param IO 1..32
-- @param state true to wait for IO to come on or false to wait for it to go off
-- @usage
-- dwi.waitIO(1,true) -- wait until IO1 turns on
--
function _M.waitIO(IO, state)
   local mask = bit32.lshift(0x00000001,(IO-1))
   while true do
     local data = bit32.band(_M.curIO,mask) 
     if (state and data ~= 0) or 
        (not state and data == 0) then 
          break
     end
     _M.system.handleEvents()
   end 
end

-------------------------------------------------------------------------------
-- Wait until SETP is in a particular state 
-- @param SETP 1..16
-- @param state true to wait for SETP to come on or false to wait for it to go off
-- @usage
-- dwi.waitSETP(1,true) -- wait until Setpoint 1 turns on
--
function _M.waitSETP(SETP, state)
   local mask = bit32.lshift(0x00000001,(SETP-1))
   while true do
     local data = bit32.band(_M.curSETP,mask) 
     if (state and data ~= 0) or 
        (not state and data == 0) then 
          break
     end
     _M.system.handleEvents()
   end 
end

-------------------------------------------------------------------------------
-- Control the use of RTC status bit
-- @param s true to enable RTC change monitoring, false to disable
function _M.writeRTCStatus(s)
   local s = s or true
   if s then s = 1 else s = 0 end
   _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_RTC,s) 
end

function _M.handleRTC(status, active)
    _M.RTCtick()
end

function _M.handleINIT(status, active)
   _M.dbg.info('INIT',string.format('%08X',status),active)
   if active then
       _M.readSettings()
       _M.RTCread()
   end    
end
-------------------------------------------------------------------------------
-- Setup status monitoring via a stream
function _M.setupStatus()
    _M.curStatus = 0 
    _M.statID = _M.addStreamLib(_M.REG_LUA_STATUS, _M.statusCallback, 'change')
    _M.eStatID = _M.addStreamLib(_M.REG_LUA_ESTAT, _M.eStatusCallback, 'change')
    _M.IOID =   _M.addStreamLib(_M.REG_IOSTATUS, _M.IOCallback, 'change')
    _M.SETPID =  _M.addStreamLib(_M.REG_SETPSTATUS, _M.SETPCallback, 'change')
    _M.RTCread()
    _M.setEStatusMainCallback(_M.ESTAT_RTC, _M.handleRTC)
    _M.setEStatusMainCallback(_M.ESTAT_INIT, _M.handleINIT)
    _M.writeRTCStatus(true)
end

-------------------------------------------------------------------------------
-- Cancel status handling
function _M.endStatus()
    _M.removeStream(_M.statID)
    _M.removeStream(_M.eStatID)
    _M.removeStream(_M.IOID)
    _M.removeStream(_M.SETPID)
end

-------------------------------------------------------------------------------
-- Cancel IO status handling
function _M.endIOStatus()
   _M.removeStream(_M.IOID)
end
-------------------------------------------------------------------------------
-- Cancel SETP status handling
function _M.endSETPStatus()
   _M.removeStream(_M.SETPID)
end

-------------------------------------------------------------------------------
--- Key Handling.
-- Functions associated with the handing key presses 
-- @section key
   
_M.firstKey = true    -- flag to catch any garbage

--- Keys.
--@table keys
-- @field KEY_0
-- @field KEY_1               
-- @field KEY_2               
-- @field KEY_3               
-- @field KEY_4               
-- @field KEY_5               
-- @field KEY_6               
-- @field KEY_7               
-- @field KEY_8               
-- @field KEY_9               
-- @field KEY_POWER           
-- @field KEY_ZERO            
-- @field KEY_TARE            
-- @field KEY_SEL             
-- @field KEY_F1              
-- @field KEY_F2              
-- @field KEY_F3              
-- @field KEY_PLUSMINUS       
-- @field KEY_DP              
-- @field KEY_CANCEL          
-- @field KEY_UP              
-- @field KEY_DOWN            
-- @field KEY_OK              
-- @field KEY_SETUP
-- @field KEY_PWR_ZERO   
-- @field KEY_PWR_TARE              
-- @field KEY_PWR_SEL     
-- @field KEY_PWR_F1     
-- @field KEY_PWR_F2     
-- @field KEY_PWR_F3     
-- @field KEY_PWR_CANCEL 

_M.KEY_0                = 0x0000
_M.KEY_1                = 0x0001
_M.KEY_2                = 0x0002
_M.KEY_3                = 0x0003
_M.KEY_4                = 0x0004
_M.KEY_5                = 0x0005
_M.KEY_6                = 0x0006
_M.KEY_7                = 0x0007
_M.KEY_8                = 0x0008
_M.KEY_9                = 0x0009
_M.KEY_POWER            = 0x000A
_M.KEY_ZERO             = 0x000B
_M.KEY_TARE             = 0x000C
_M.KEY_SEL              = 0x000D
_M.KEY_F1               = 0x000E
_M.KEY_F2               = 0x000F
_M.KEY_F3               = 0x0010
_M.KEY_PLUSMINUS        = 0x0011
_M.KEY_DP               = 0x0012
_M.KEY_CANCEL           = 0x0013
_M.KEY_UP               = 0x0014
_M.KEY_DOWN             = 0x0015
_M.KEY_OK               = 0x0016
_M.KEY_SETUP            = 0x0017
_M.KEY_PWR_ZERO         = 0x0018
_M.KEY_PWR_TARE         = 0x0019
_M.KEY_PWR_SEL          = 0x001A
_M.KEY_PWR_F1           = 0x001B
_M.KEY_PWR_F2           = 0x001C
_M.KEY_PWR_F3           = 0x001D
_M.KEY_PWR_CANCEL       = 0x001E
_M.KEY_IDLE             = 0x001F

--Lua key handling
_M.REG_GET_KEY          = 0x0321
_M.REG_FLUSH_KEYS       = 0x0322
_M.REG_APP_DO_KEYS      = 0x0324
_M.REG_APP_KEY_HANDLER  = 0x0325  

_M.keyID = nil

_M.keyGroup = {}

-- Be sure to update the ldoc table below to match the defined keyGroups
_M.keyGroup.all         = {callback = nil}
_M.keyGroup.primary     = {callback = nil}
_M.keyGroup.functions   = {callback = nil}
_M.keyGroup.keypad      = {callback = nil}
_M.keyGroup.numpad      = {callback = nil}
_M.keyGroup.cursor      = {callback = nil}
_M.keyGroup.extended    = {callback = nil}

_M.keyBinds = {
    [_M.KEY_0]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_1]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_2]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_3]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_4]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_5]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_6]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_7]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_8]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_9]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_POWER]      = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_ZERO]       = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_TARE]       = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_SEL]         = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_F1]         = {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
    [_M.KEY_F2]         = {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
    [_M.KEY_F3]         = {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
    [_M.KEY_PLUSMINUS]  = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_DP]         = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_CANCEL]     = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_UP]         = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_DOWN]       = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_OK]         = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_SETUP]      = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_PWR_ZERO]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_TARE]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_SEL ]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_F1  ]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_F2  ]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_F3  ]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_CANCEL ]   = {_M.keyGroup.extended, _M.keyGroup.all}
}

-------------------------------------------------------------------------------
-- Setup key handling stream
function _M.setupKeys()
    _M.sendReg(_M.CMD_EX, _M.REG_FLUSH_KEYS, 0)
    _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 1)
    _M.keyID = _M.addStreamLib(_M.REG_GET_KEY, _M.keyCallback, 'change')
end

-------------------------------------------------------------------------------
-- Cancel keypress handling
-- @param flush Flush the current keypresses that have not yet been handled
function _M.endKeys(flush)
    if flush then
        _M.sendRegWait(_M.CMD_EX, _M.REG_FLUSH_KEYS, 0)
    end

    _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 0)
    
    _M.removeStream(_M.keyID)
end

_M.runningKeyCallback = nil  -- keeps track of any running callback to prevent recursive calls 

-- Called when keys are streamed, send the keys to each group it is bound to 
-- in order of priority, until one of them returns true.
-- key states are 'short','long','up'
-- Note: keybind tables should be sorted by priority
-- @param data Data on key streamed
-- @param err Potential error message
function _M.keyCallback(data, err)
    
    local state = "short"
    local key = bit32.band(data, 0x3F)
    
    if bit32.band(data, 0x80) > 0 then
        state = "long"
    end
    
    if bit32.band(data, 0x40) > 0 then
        state = "up"
    end    

    -- Debug - throw away first 0 key garbage
    if data == 0 and _M.firstKey then
        return
    end
    _M.firstKey = false
    
    -- Debug  - throw away up and idle events
    if (state == "up" and key ~= _M.KEY_POWER) or data == _M.KEY_IDLE then
       return
    end

    local handled = false
    local groups = _M.keyBinds[key]
    if groups ~= nil then
       
       if groups.directCallback then 
            if _M.runningKeyCallback == groups.directCallback then
               _M.dbg.warn('Attempt to call Key Event Handler recursively : ', key) 
               return
            end    
            _M.runningKeyCallback = groups.directCallback
            if groups.directCallback(key, state) == true then
                handled = true
            end    
            _M.runningKeyCallback = nil
       end
              
      if not handled then      
          for i=1,#groups do
            if groups[i].callback then
                if _M.runningKeyCallback == groups[i].callback then
                    _M.dbg.warn('Attempt to call Key Group Event Handler recursively : ', key) 
                    return
                end    
                _M.runningKeyCallback = groups[i].callback
                if groups[i].callback(key, state) == true then
                    handled = true
                    break
                end     
            end
          end 
          _M.runningKeyCallback = nil           
       end
     end  
    
    if not handled then
        _M.sendReg(_M.CMD_WRFINALDEC,_M.REG_APP_DO_KEYS, data)
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for an existing key
-- @param key to monitor (KEY_* )
-- @param callback Function to run when there is an event for that key.
-- Callback function parameters are key (.KEY_OK etc) and state ('short' or 'long')
-- @usage
-- local function F1Pressed(key, state)
--  if state == 'short' then
--       dbg.info('F1 pressed')
--    end
--    return true    -- F1 handled here so don't send back to instrument for handling
--  end
--  dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)
--
function _M.setKeyCallback(key, callback)
    _M.keyBinds[key].directCallback = callback
end

--- Key Groups.
--@table keygroups
-- @field keyGroup.all      
-- @field keyGroup.primary  
-- @field keyGroup.functions
-- @field keyGroup.keypad   
-- @field keyGroup.numpad   
-- @field keyGroup.cursor   
-- @field keyGroup.extended   

-------------------------------------------------------------------------------
-- Set the callback function for an existing key group
-- Return true in the callback to prevent the handling from being passed along to the next keygroup
-- @param keyGroup A keygroup given in keyGroup.*
-- @param callback Function to run when there is an event on the keygroup
-- Callback function parameters are key (.KEY_OK etc) and state ('short' or 'long')
function _M.setKeyGroupCallback(keyGroup, callback)
    keyGroup.callback = callback
end

-------------------------------------------------------------------------------
-- Send an artificial  key press to the instrument 
-- @param key (.KEY_*)
-- @param status 'long' or 'short'
function _M.sendKey(key,status)
    if key then
        local data = key
        if status == 'long' then
            data = bit32.bor(data, 0x80)
        end
        _M.sendReg(_M.CMD_WRFINALDEC,_M.REG_APP_DO_KEYS, data)
    end
end

-------------------------------------------------------------------------------
--- LCD Services.
-- Functions to configure the LCD
-- @section lcd 

--LCD display registers
_M.REG_DISP_BOTTOM_LEFT     = 0x000E    -- Takes string
_M.REG_DISP_BOTTOM_RIGHT    = 0x000F    -- Takes string
_M.REG_DISP_TOP_LEFT        = 0x00B0    -- Takes string
_M.REG_DISP_TOP_RIGHT       = 0x00B1    -- Takes string
_M.REG_DISP_TOP_ANNUN       = 0x00B2
_M.REG_DISP_TOP_UNITS       = 0x00B3    -- Takes string
_M.REG_DISP_BOTTOM_ANNUN    = 0x00B4
_M.REG_DISP_BOTTOM_UNITS    = 0x00B5

_M.REG_DISP_AUTO_TOP_ANNUN  = 0x00B6    -- Register number  REG_*
_M.REG_DISP_AUTO_TOP_LEFT   = 0x00B7    -- Register number  REG_*
_M.REG_DISP_AUTO_BOTTOM_LEFT= 0x00B8    -- Register number  REG_*

_M.REG_BUZ_LEN      = 0x0327
_M.REG_BUZ_NUM      = 0x0328

_M.botAnnunState = 0
_M.topAnnunState = 0
_M.waitPos = _M.WAIT

_M.curTopLeft = ''
_M.curTopRight = ''
_M.curBotLeft = ''
_M.curBotRight = ''
_M.curTopUnits = 0
_M.curBotUnits = 0
_M.curBotUnitsOther = 0
_M.curAutoTopLeft = 0
_M.curAutoBotLeft = 0

_M.saveBotLeft = ''
_M.saveAutoTopLeft = 0
_M.saveAutoBotLeft = 0
_M.saveBotRight = ''
_M.saveBotUnits = 0
_M.saveBotUnitsOther = 0 

function _M.saveBot()
   _M.saveBotLeft = _M.curBotLeft
   _M.saveBotRight = _M.curBotRight
   _M.saveBotUnits = _M.curBotUnits
   _M.saveBotUnitsOther = _M.curBotUnitsOther
end

function _M.restoreBot()
  _M.writeBotLeft(_M.saveBotLeft)
  _M.writeBotRight(_M.saveBotRight)
  _M.writeBotUnits(_M.saveBotUnits, _M.saveBotUnitsOther)
end

local function strLenR400(s)
   local len = 0
   local dotFound = true
   for i = 1,#s do
     local ch = string.sub(s,i,i)
     if not dotFound and  ch == '.' then
         dotFound = true
     else
        if ch ~= '.' then
           dotFound = false
        end   
        len = len + 1
     end   
   end    
  return(len)
end

local function strSubR400(s,stPos,endPos)
   local len = 0
   local dotFound = true
   local substr = ''
   if stPos < 1 then
       stPos = #s + stPos + 1
   end
   if endPos < 1 then
       endPos = #s + endPos + 1
   end
   
   for i = 1,#s do
     local ch = string.sub(s,i,i)
     if not dotFound and  ch == '.' then
         dotFound = true
     else
        if ch ~= '.' then
           dotFound = false
        end   
        len = len + 1
     end   
     if (len >= stPos) and (len <= endPos) then
          substr = substr .. ch
     end     
   end    
  return(substr)
end

-- takes a string and pads ... with . . . for R420 to handle
local function padDots(s)
    if #s == 0 then
        return s
    end         
    local str = string.gsub(s,'%.%.','%. %.')
    str = string.gsub(str,'%.%.','%. %.')
    if string.sub(str,1,1) == '.' then
        str = ' '..str
    end    
    return(str)    
end

-- local function to split a long string into shorter strings of multiple words
-- that fit into length len
local function splitWords(s,len)
  local t = {}
  local p = ''
  local len = len or 8
  
  if strLenR400(s) <= len then
     table.insert(t,s)
     return t
     end
     
  for w in string.gmatch(s, "%S+") do 
    if strLenR400(p) + strLenR400(w) < len then
       if p == '' then
          p = w
       else   
          p = p .. ' '..w
       end          
    elseif strLenR400(p) > len then
       table.insert(t,strSubR400(p,1,len))
       p = strSubR400(p,len+1,-1)
       if strLenR400(p) + strLenR400(w) < len then
           p = p .. ' ' .. w
       else
          table.insert(t,p)
          p = w
       end           
    else
       if #p > 0 then
           table.insert(t,p)
       end    
       p = w
    end   
   end
   
   while strLenR400(p) > len do
      table.insert(t,strSubR400(p,1,len))
      p = strSubR400(p,len+1,-1)
   end
   if #p > 0 or #t == 0 then
     table.insert(t,p)
   end  
 return t
end

function _M.slideTopLeft()
    local function dispWord()
        _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_TOP_LEFT, 
             string.format('%-6s',padDots(_M.slideTopLeftWords[_M.slideTopLeftPos])))
     end
    _M.slideTopLeftPos = _M.slideTopLeftPos + 1
    if _M.slideTopLeftPos > #_M.slideTopLeftWords then
       _M.slideTopLeftPos = 1
       dispWord()       
       return
    end 
    dispWord()    
end
-------------------------------------------------------------------------------
-- Write string to Top Left of LCD, curTopLeft is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
function _M.writeTopLeft(s,t)
    local t = t or 0.8
    
    if t < 0.2 then 
       t = 0.2 
    end
    if s then
        if s ~= _M.curTopLeft then
            _M.writeAutoTopLeft(0)
            _M.curTopLeft = s
            _M.slideTopLeftWords = splitWords(s,6)
            _M.slideTopLeftPos = 1
            if _M.slideTopLeftTimer then     -- remove any running display
                _M.system.timers.removeTimer(_M.slideTopLeftTimer)
            end    
            _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_TOP_LEFT, 
                 string.format('%-6s',padDots(_M.slideTopLeftWords[_M.slideTopLeftPos])))
            if #_M.slideTopLeftWords > 1 then
                _M.slideTopLeftTimer = _M.system.timers.addTimer(t,t,_M.slideTopLeft)
            end    
        end
    elseif _M.curAutoTopLeft == 0 then
       _M.writeAutoTopLeft(_M.saveAutoTopLeft)
    end
end

-------------------------------------------------------------------------------
-- Write string to Top Right of LCD, curTopRight is set to s
-- @param s string to display
function _M.writeTopRight(s)
    if s then
        if s ~= _M.curTopRight then
           _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_DISP_TOP_RIGHT, s)
           _M.curTopRight = s
        end   
    end
end

function _M.slideBotLeft()
    local function dispWord()
        _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_LEFT, 
             string.format('%-9s',padDots(_M.slideBotLeftWords[_M.slideBotLeftPos])))
     end
    _M.slideBotLeftPos = _M.slideBotLeftPos + 1
    if _M.slideBotLeftPos > #_M.slideBotLeftWords then
       _M.slideBotLeftPos = 1
       dispWord()       
       return
    end 
    dispWord()    
end

-------------------------------------------------------------------------------
-- Write string to Bottom Left of LCD, curBotLeft is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
function _M.writeBotLeft(s, t)
    local t = t or 0.8
    
    if t < 0.2 then 
       t = 0.2 
    end
    
    if s then
        if s ~= _M.curBotLeft then
            _M.writeAutoBotLeft(0)
            _M.curBotLeft = s
            _M.slideBotLeftWords = splitWords(s,9)
            _M.slideBotLeftPos = 1
            if _M.slideBotLeftTimer then     -- remove any running display
                _M.system.timers.removeTimer(_M.slideBotLeftTimer)
            end    
            _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_LEFT, 
                 string.format('%-9s',padDots(_M.slideBotLeftWords[_M.slideBotLeftPos])))
            if #_M.slideBotLeftWords > 1 then
                _M.slideBotLeftTimer = _M.system.timers.addTimer(t,t,_M.slideBotLeft)
            end    
        end
    elseif _M.curAutoBotLeft == 0 then
       _M.writeAutoBotLeft(_M.saveAutoBotLeft)
    end
end

function _M.slideBotRight()
    local function dispWord()
        _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_RIGHT, 
             string.format('%-8s',padDots(_M.slideBotRightWords[_M.slideBotRightPos])))
     end
    _M.slideBotRightPos = _M.slideBotRightPos + 1
    if _M.slideBotRightPos > #_M.slideBotRightWords then
       _M.slideBotRightPos = 1
       dispWord()       
       return
    end 
    dispWord()    
end

-------------------------------------------------------------------------------
-- Write string to Bottom Right of LCD, curBotRight is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
function _M.writeBotRight(s, t)
    local t = t or 0.8
    
    if t < 0.2 then 
       t = 0.2 
    end

    if s then
     if s ~= _M.curBotRight then
            _M.curBotRight = s
            _M.slideBotRightWords = splitWords(s,8)
            _M.slideBotRightPos = 1
            if _M.slideBotRightTimer then     -- remove any running display
                _M.system.timers.removeTimer(_M.slideBotRightTimer)
            end    
            _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_RIGHT, 
                 string.format('%-8s',padDots(_M.slideBotRightWords[_M.slideBotRightPos])))
            if #_M.slideBotRightWords > 1 then
                _M.slideBotRightTimer = _M.system.timers.addTimer(t,t,_M.slideBotRight)
            end    
        end
    end
end

_M.writeBotAnnuns   = _M.preconfigureMsg(_M.REG_DISP_BOTTOM_ANNUN,
                                         _M.CMD_WRFINALHEX,
                                         "noReply")                                      
_M.writeTopAnnuns   = _M.preconfigureMsg(_M.REG_DISP_TOP_ANNUN,
                                         _M.CMD_WRFINALHEX,
                                         "noReply")                                      

-----------------------------------------------------------------------------
-- link register address  with Top annunciators to update automatically 
--@function writeAutoTopAnnun
--@param reg address of register to link Top Annunciator state to.
-- Set to 0 to enable direct control of the area                                         
_M.writeAutoTopAnnun  = _M.preconfigureMsg(_M.REG_DISP_AUTO_TOP_ANNUN,
                                         _M.CMD_WRFINALHEX,
                                         "noReply")

_M.setAutoTopAnnun = _M.writeAutoTopAnnun                                         
-----------------------------------------------------------------------------
-- link register address with Top Left display to update automatically 
--@param reg address of register to link Top Left display to.
-- Set to 0 to enable direct control of the area                                         
function _M.writeAutoTopLeft(reg)
   if reg ~= _M.curAutoTopLeft then
       if _M.slideTopLeftTimer then     -- remove any running display
          _M.system.timers.removeTimer(_M.slideTopLeftTimer)
       end 
       _M.curTopLeft = nil   
       _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_DISP_AUTO_TOP_LEFT, reg, "noReply")
       _M.saveAutoTopLeft = _M.curAutoTopLeft
       _M.curAutoTopLeft = reg
   end    
end        

_M.setAutoTopLeft = _M.writeAutoTopLeft

-----------------------------------------------------------------------------
-- reads the current Top Left auto update register 
-- @return register that is being used for auto update, 0 if none                                         
function _M.readAutoTopLeft()
   local reg = _M.sendRegWait(_M.CMD_RDFINALDEC,_M.REG_DISP_AUTO_TOP_LEFT)
   reg = tonumber(reg)
   _M.curAutoTopLeft = reg
   return reg
end        
-----------------------------------------------------------------------------
-- link register address with Bottom Left display to update automatically 
--@param reg address of register to link Bottom Left display to.
-- Set to 0 to enable direct control of the area                                         
function _M.writeAutoBotLeft(reg)
   if reg ~= _M.curAutoBotLeft then
       if _M.slideBotLeftTimer then     -- remove any running display
          _M.system.timers.removeTimer(_M.slideBotLeftTimer)
       end 
       _M.curBotLeft = nil   
       _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_DISP_AUTO_BOTTOM_LEFT, reg, "noReply")
       _M.saveAutoBotLeft = _M.curAutoBotLeft
       _M.curAutoBotLeft = reg
   end    
end                                         
_M.setAutoBotLeft = _M.writeAutoBotLeft

-----------------------------------------------------------------------------
-- reads the current Bottom Left auto update register 
-- @return register that is being used for auto update, 0 if none                                         
function _M.readAutoBotLeft()
   local reg = _M.sendRegWait(_M.CMD_RDFINALDEC,_M.REG_DISP_AUTO_BOT_LEFT)
   reg = tonumber(reg)
   _M.curAutoBotLeft = reg
   return reg
end        

--- Bottom LCD Annunciators
--@table BotAnnuns
-- @field BATTERY   
-- @field CLOCK            
-- @field BAT_LO           
-- @field BAT_MIDL         
-- @field BAT_MIDH         
-- @field BAT_HI           
-- @field BAT_FULL         
-- @field WAIT             
-- @field WAIT45           
-- @field WAIT90           
-- @field WAIT135          
-- @field WAITALL          

-- REG_DISP_BOTTOM_ANNUN BIT SETTINGS
_M.BATTERY   = 0x0001
_M.CLOCK     = 0x0002
_M.BAT_LO    = 0x0004
_M.BAT_MIDL  = 0x0008
_M.BAT_MIDH  = 0x0010
_M.BAT_HI    = 0x0020
_M.BAT_FULL  = 0x003D
_M.WAIT      = 0x0040
_M.WAIT45    = 0x0100
_M.WAIT90    = 0x0200
_M.WAIT135   = 0x0080
_M.WAITALL   = 0x03C0

-------------------------------------------------------------------------------
-- Sets the annunciator bits for Bottom Annunciators
-- @param d holds bit locations
function _M.setBitsBotAnnuns(d)
  _M.botAnnunState = bit32.bor(_M.botAnnunState,d)
  _M.writeBotAnnuns(_M.botAnnunState)
end

-------------------------------------------------------------------------------
-- Clears the annunciator bits for Bottom Annunciators
-- @param d holds bit locations
function _M.clrBitsBotAnnuns(d)
  _M.botAnnunState = bit32.band(_M.botAnnunState,bit32.bnot(d))
  _M.writeBotAnnuns(_M.botAnnunState)
end

-------------------------------------------------------------------------------
-- Rotate the WAIT annunciator 
-- @param dir  1 clockwise, -1 anticlockwise 0 no change
function _M.rotWAIT(dir)

    if _M.waitPos == _M.WAIT then
        if dir > 0 then 
            _M.waitPos = _M.WAIT45 
        elseif dir < 0 then 
            _M.waitPos = _M.WAIT135 
        end
    elseif _M.waitPos == _M.WAIT45 then
        if dir > 0 then 
            _M.waitPos = _M.WAIT90 
        elseif dir < 0 then 
            _M.waitPos = _M.WAIT 
        end
    elseif _M.waitPos == _M.WAIT90 then
        if dir > 0 then 
            _M.waitPos = _M.WAIT135 
        elseif dir < 0 then 
            _M.waitPos = _M.WAIT45
        end
    else   -- Must be WAIT135
        if dir > 0 then 
            _M.waitPos = _M.WAIT 
        elseif dir < 0 then 
            _M.waitPos = _M.WAIT90 
        end
  end
 
  _M.botAnnunState = bit32.band(_M.botAnnunState,bit32.bnot(_M.WAITALL))
 
  _M.botAnnunState = bit32.bor(_M.botAnnunState,_M.waitPos)
  _M.writeBotAnnuns(_M.botAnnunState)  
  
end

--- Top LCD Annunciators
--@table TopAnnuns
-- @field SIGMA       
-- @field BALANCE         
-- @field COZ             
-- @field HOLD            
-- @field MOTION          
-- @field NET             
-- @field RANGE           
-- @field ZERO            
-- @field BAL_SEGA        
-- @field BAL_SEGB        
-- @field BAL_SEGC        
-- @field BAL_SEGD      
-- @field BAL_SEGE        
-- @field BAL_SEGF        
-- @field BAL_SEGG        
-- @field RANGE_SEGADG    
-- @field RANGE_SEGC      
-- @field RANGE_SEGE      
   
-- REG_DISP_TOP_ANNUN BIT SETTINGS
_M.SIGMA        = 0x00001
_M.BALANCE      = 0x00002
_M.COZ          = 0x00004
_M.HOLD         = 0x00008
_M.MOTION       = 0x00010
_M.NET          = 0x00020
_M.RANGE        = 0x00040
_M.ZERO         = 0x00080
_M.BAL_SEGA     = 0x00100
_M.BAL_SEGB     = 0x00200
_M.BAL_SEGC     = 0x00400
_M.BAL_SEGD     = 0x00800
_M.BAL_SEGE     = 0x01000
_M.BAL_SEGF     = 0x02000
_M.BAL_SEGG     = 0x04000
_M.RANGE_SEGADG = 0x08000
_M.RANGE_SEGC   = 0x10000
_M.RANGE_SEGE   = 0x20000

-------------------------------------------------------------------------------
-- Sets the annunciator bits for Top Annunciators
-- @param d holds bit locations
function _M.setBitsTopAnnuns(d)
  _M.topAnnunState = bit32.bor(_M.topAnnunState,d)
  _M.writeTopAnnuns(_M.topAnnunState)
end

-------------------------------------------------------------------------------
-- Clears the annunciator bits for Top Annunciators
-- @param d holds bit locations
function _M.clrBitsTopAnnuns(d)
  _M.topAnnunState = bit32.band(_M.topAnnunState,bit32.bnot(d))
  _M.writeTopAnnuns(_M.topAnnunState)
end

--- Main Units 
--@table Units
-- @field UNITS_NONE     
-- @field UNITS_KG           
-- @field UNITS_LB           
-- @field UNITS_T            
-- @field UNITS_G            
-- @field UNITS_OZ           
-- @field UNITS_N            
-- @field UNITS_ARROW_L      
-- @field UNITS_P            
-- @field UNITS_L            
-- @field UNITS_ARROW_H      
-- REG_DISP UNITS BIT SETTINGS
_M.UNITS_NONE    = 0x00
_M.UNITS_KG      = 0x01
_M.UNITS_LB      = 0x02
_M.UNITS_T       = 0x03
_M.UNITS_G       = 0x04
_M.UNITS_OZ      = 0x05
_M.UNITS_N       = 0x06
_M.UNITS_ARROW_L = 0x07
_M.UNITS_P       = 0x08
_M.UNITS_L       = 0x09
_M.UNITS_ARROW_H = 0x0A

--- Additional modifiers on bottom display 
--@table Other
-- @field UNITS_OTHER_PER_H   
-- @field UNITS_OTHER_PER_M       
-- @field UNITS_OTHER_PER_S       
-- @field UNITS_OTHER_PC          
-- @field UNITS_OTHER_TOT         
_M.UNITS_OTHER_PER_H   = 0x14
_M.UNITS_OTHER_PER_M   = 0x11
_M.UNITS_OTHER_PER_S   = 0x12
_M.UNITS_OTHER_PC      = 0x30
_M.UNITS_OTHER_TOT     = 0x08

-------------------------------------------------------------------------------
-- Set top units 
-- @param units (.UNITS_NONE etc)
function _M.writeTopUnits (units)
   local units = units or _M.UNITS_NONE
   _M.writeReg(_M.REG_DISP_TOP_UNITS,units)
   _M.curTopUnits = units
end
-------------------------------------------------------------------------------
-- Set bottom units 
-- @param units (.UNITS_NONE etc)
-- @param other (.UNITS_OTHER_PER_H etc)
function _M.writeBotUnits (units, other)
   local units = units or _M.UNITS_NONE
   local other = other or _M.UNITS_NONE
   _M.writeReg(_M.REG_DISP_BOTTOM_UNITS,bit32.bor(bit32.lshift(other,8),units))
   _M.curBotUnits = units
   _M.curBotUnitsOther = other
end

-------------------------------------------------------------------------------
-- Called to restore the LCD to its default state
function _M.restoreLcd()
   _M.writeAutoTopAnnun(0)
   _M.writeAutoTopLeft(_M.REG_GROSSNET)
   _M.writeAutoBotLeft(0)
   _M.writeTopRight('')
   _M.writeBotLeft('')
   _M.writeBotRight('')
   _M.writeBotAnnuns(0)
   _M.writeBotUnits()
end

-------------------------------------------------------------------------------
--- Buzzer Control.
-- Functions to control instrument buzzer
-- @section buzzer

-- The lengths of beeps, takes 0 (short), 1(med) or 2(long). 
-- There are no gaps between long beeps
_M.REG_BUZZ_LEN =  0x0327
-- takes 1 – 4, will clear to 0 once beeps have been executed
_M.REG_BUZZ_NUM =  0x0328        

_M.BUZZ_SHORT = 0
_M.BUZZ_MEDIUM = 1
_M.BUZZ_LONG = 2
_M.lastBuzzLen = nil
-------------------------------------------------------------------------------
-- Called to set the length of the buzzer sound
-- @param len - length of buzzer sound (BUZZ_SHORT, BUZZ_MEDIUM, BUZZ_LONG)
function _M.setBuzzLen(len)

   local len = len or _M.BUZZ_SHORT
   if len > _M.BUZZ_LONG then len = _M.BUZZ_LONG end
   if len ~= _M.lastBuzzLen then
      _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_BUZZ_LEN, len)
      _M.lastBuzzLen = len
   end  

end

-------------------------------------------------------------------------------
-- Called to trigger instrument buzzer
-- @param times  - number of times to buzz, 1..4
-- @param len - length of buzzer sound (BUZZ_SHORT, BUZZ_MEDIUM, BUZZ_LONG)
function _M.buzz(times, len)
    local times = times or 1
    local len = len or _M.BUZZ_SHORT
    times = tonumber(times)
    if times > 4 then 
        times = 4 
    end
    _M.setBuzzLen(len)
    _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_BUZZ_NUM, times)
end

-------------------------------------------------------------------------------
--- Analogue Output Control.
-- Functions to configure and control the analogue output module
-- @section analogue

_M.REG_ANALOGUE_DATA = 0x0323
_M.REG_ANALOGUE_TYPE = 0xA801
_M.REG_ANALOGUE_CLIP = 0xA806
_M.REG_ANALOGUE_SOURCE = 0xA805  -- must be set to option 3 "COMMS" if we are to control it via the comms
  
_M.CUR = 0
_M.VOLT = 1

_M.curAnalogType = -1 

_M.ANALOG_COMMS = 3
-------------------------------------------------------------------------------
-- Set the analog output type
-- @param src Source for output.  
-- Must be set to ANALOG_COMMS to control directly
function _M.setAnalogSource(src)
   _M.sendReg(_M.CMD_WRFINALDEC,
                _M.REG_ANALOGUE_SOURCE,
                src)
  _M.saveSettings()                
end
                                         
-------------------------------------------------------------------------------
-- Set the analog output type
-- @param typ Type for output (.CUR or .VOLT)
function _M.setAnalogType(typ)
    local prev = _M.curAnalogType
    
    if typ == _M.CUR then
        _M.curAnalogType = _M.CUR
    else
        _M.curAnalogType = _M.VOLT
    end  
    
    if _M.curAnalogType ~= prev then 
        _M.sendReg(_M.CMD_WRFINALDEC,
                _M.REG_ANALOGUE_TYPE,
                _M.curAnalogType) 
    end
end   

-------------------------------------------------------------------------------
-- Control behaviour of analog output outside of normal range.
-- If clip is active then output will be clipped to the nominal range 
-- otherwise the output will drive to the limit of the hardware
-- @function setAnalogClip
-- @param c 0 for clipping disabled, 1 for clipping enabled
_M.setAnalogClip = _M.preconfigureMsg(  _M.REG_ANALOGUE_CLIP, 
                                        _M.CMD_WRFINALDEC, "noReply")
-------------------------------------------------------------------------------
-- Sets the analog output to minimum 0 through to maximum 50,000
-- @param raw value in raw counts (0..50000)
function _M.setAnalogRaw(raw)
   if _M.lastAnalogue ~= raw then 
       _M.send(nil, _M.CMD_WRFINALDEC, _M.REG_ANALOGUE_DATA, raw, 'noReply')
       _M.lastAnalogue = raw
   end    
end                                         
-------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0 through to maximum 1.0
-- @param val value 0.0 to 1.0
function _M.setAnalogVal(val)
   _M.setAnalogRaw(math.floor((50000*val)+0.5))
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0% through to maximum 100%
-- @param val value 0 to 100 %
function _M.setAnalogPC(val)
  val = val / 100
  _M.setAnalogVal(val)
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0V through to maximum 10.0V
-- @param val value 0.0 to 10.0
function _M.setAnalogVolt(val)
  _M.setAnalogType(_M.VOLT)
  val = val / 10 
 _M.setAnalogVal(val)
end

 ------------------------------------------------------------------------------
-- Sets the analogue output to minimum 4.0 through to maximum 20.0 mA
-- @param val value 4.0 to 20.0
function _M.setAnalogCur(val)
  _M.setAnalogType(_M.CUR)
  val = (val - 4)/16
 _M.setAnalogVal(val)
end

-------------------------------------------------------------------------------
--- Setpoint Control.
-- Functions to setup adn control setpoint outputs
-- @section setpoint
----------------------------------------------------------------------------

_M.REG_IO_STATUS    = 0x0051
_M.REG_IO_ENABLE    = 0x0054

_M.REG_SETP_NUM     = 0xA400

-- add Repeat to each registers below for each setpoint 0..15
_M.REG_SETP_REPEAT  = 0x0020
_M.REG_SETP_TYPE    = 0xA401
_M.REG_SETP_OUTPUT  = 0xA402
_M.REG_SETP_LOGIC   = 0xA403
_M.REG_SETP_ALARM   = 0xA404
_M.REG_SETP_NAME    = 0xA40E
_M.REG_SETP_SOURCE  = 0xA406
_M.REG_SETP_HYS     = 0xA409
_M.REG_SETP_SOURCE_REG = 0xA40A

_M.REG_SETP_TIMING  = 0xA410
_M.REG_SETP_RESET   = 0xA411
_M.REG_SETP_PULSE_NUM = 0xA412
_M.REG_SETP_TIMING_DELAY  = 0xA40C
_M.REG_SETP_TIMING_ON     = 0xA40D

-- targets are stored in the product database rather than the setpoint one
_M.REG_SETP_TARGET  = 0xB080  -- add setpoint offset (0..15) for the other 16 setpoint targets

_M.LOGIC_HIGH = 0
_M.LOGIC_LOW = 1

_M.ALARM_NONE = 0
_M.ALARM_SINGLE = 1
_M.ALARM_DOUBLE = 2
_M.ALARM_FLASH = 3

_M.TIMING_LEVEL = 0
_M.TIMING_EDGE  = 1
_M.TIMING_PULSE = 2
_M.TIMING_LATCH = 3

_M.SOURCE_GROSS = 0
_M.SOURCE_NET = 1
_M.SOURCE_DISP = 2
_M.SOURCE_ALT_GROSS = 3
_M.SOURCE_ALT_NET = 4
_M.SOURCE_ALT_DISP = 5
_M.SOURCE_PIECE = 6
_M.SOURCE_REG = 7

_M.TYPE_OFF      = 0
_M.TYPE_ON       = 1
_M.TYPE_OVER     = 2
_M.TYPE_UNDER    = 3
_M.TYPE_COZ      = 4
_M.TYPE_ZERO     = 5
_M.TYPE_NET      = 6
_M.TYPE_MOTION   = 7
_M.TYPE_ERROR    = 8
_M.TYPE_LGC_AND  = 9
_M.TYPE_LGC_OR   = 10
_M.TYPE_LGC_XOR  = 11
_M.TYPE_BUZZER   = 12

_M.lastOutputs = 0
-- bits set if under LUA control, clear if under instrument control
_M.lastIOEnable = 0    

_M.setp = {}

_M.NUM_SETP = 16
 
_M.setOutputs = _M.preconfigureMsg(_M.REG_IO_STATUS, _M.CMD_WRFINALDEC)
_M.setOutputEnable = _M.preconfigureMsg(_M.REG_IO_ENABLE, _M.CMD_WRFINALDEC)

-------------------------------------------------------------------------------
-- Turns IO Output on
-- @param IO is output 1..32
function _M.turnOn(IO)
   local curOutputs = bit32.bor(_M.lastOutputs, bit32.lshift(0x0001,(IO-1)))
   if (curOutputs ~= _M.lastOutputs) then
      _M.setOutputs(curOutputs)
      _M.lastOutputs = curOutputs
      end
end

-------------------------------------------------------------------------------
-- Turns IO Output off
-- @param IO is output 1..32
function _M.turnOff(IO)
 local curOutputs = bit32.band(_M.lastOutputs,
                               bit32.bnot(bit32.lshift(0x0001,(IO-1))))
 if (curOutputs ~= _M.lastOutputs) then
      _M.setOutputs(curOutputs)
      _M.lastOutputs = curOutputs
      end
      
end
-------------------------------------------------------------------------------
-- Turns IO Output on
-- @param IO is output 1..32
-- @param t is time in seconds
function _M.turnOnTimed(IO, t)
  _M.turnOn(IO)
  _M.system.timers.addTimer(0, t, _M.turnOff, IO)
end

-------------------------------------------------------------------------------
-- Sets IO Output under LUA control
-- @param ... list of IO to enable (input 1..32)
-- @usage
-- dwi.enableOutput(1,2,3,4)
-- dwi.turnOn(1)
-- dwi.turnOff(2)
-- dwi.turnOnTimed(3, 0.500)  -- pulse output 3 for 500 milliseconds
-- dwi.releaseOutput(1,2,3,4)

function _M.enableOutput(...)
    local curIOEnable =  _M.lastIOEnable
    
    for i,v in ipairs(arg) do
        v = tonumber(v)
        curIOEnable = bit32.bor(curIOEnable, bit32.lshift(0x0001,(v-1)))
       end  
   if (curIOEnable ~= _M.lastIOEnable) then
      _M.setOutputEnable(curIOEnable)
      _M.lastIOEnable = curIOEnable
    end  
end

-------------------------------------------------------------------------------
-- Sets IO Output under instrument control
-- @param ... list of IO to release to the instrument(input 1..32)
-- @usage
-- dwi.enableOutput(1,2,3,4)
-- dwi.turnOn(1)
-- dwi.turnOff(2)
-- dwi.turnOnTimed(3, 0.500)  -- pulse output 3 for 500 milliseconds
-- dwi.releaseOutput(1,2,3,4)
function _M.releaseOutput(...)
    local curIOEnable =  _M.lastIOEnable
    
    for i,v in ipairs(arg) do
        v = tonumber(v)
        curIOEnable = bit32.band(curIOEnable, 
                                   bit32.bnot(bit32.lshift(0x0001,(v-1))))
       end  

    if (curIOEnable ~= _M.lastIOEnable) then
        _M.setOutputEnable(curIOEnable)
        _M.lastIOEnable = curIOEnable
    end 
end

--------------------------------------------------------------------------------
-- returns actual register address for a particular setpoint parameter
-- @param setp is setpoint 1..16
-- @param reg is REG_SETP_*
-- @return address of this registet for setpoint setp
function _M.setpRegAddress(setp,reg)
  if (setp > _M.NUM_SETP) or (setp < 1) then
     _M.dbg.error('Setpoint Invalid: ', setp)
     return(0)
  elseif reg == _M.REG_SETP_TARGET then
     return (reg+setp-1)
  else
     return (reg+((setp-1)*_M.REG_SETP_REPEAT))
  end     
end

--------------------------------------------------------------------------------
-- Private function
function _M.setpParam(setp,reg,v)
   _M.sendReg(_M.CMD_WRFINALDEC, _M.setpRegAddress(setp,reg), v)       
end

-------------------------------------------------------------------------------
-- Set the number of Setpoints 
-- @param n is the number of setpoints 0..8
function _M.setNumSetp(n)
  _M.sendReg(_M.CMD_WRFINALDEC,_M.REG_SETP_NUM,n)
end

-------------------------------------------------------------------------------
-- Set Target for setpoint
-- @param setp Setpoint 1..16
-- @param target Target value
function _M.setpTarget(setp,target)
    _M.sendReg(_M.CMD_WRFINALDEC, _M.setpRegAddress(setp,_M.REG_SETP_TARGET), target)
end

-------------------------------------------------------------------------------
-- Set which Output the setpoint controls
-- @param setp is setpount 1..16
-- @param IO is output 1..32, 0 for none
function _M.setpIO(setp, IO)
    _M.setpParam(setp,_M.REG_SETP_OUTPUT, IO)
end

--- Setpoint Types.
--@table Types
-- @field TYPE_OFF     
-- @field TYPE_ON      
-- @field TYPE_OVER    
-- @field TYPE_UNDER   
-- @field TYPE_COZ     
-- @field TYPE_ZERO    
-- @field TYPE_NET     
-- @field TYPE_MOTION  
-- @field TYPE_ERROR   
-- @field TYPE_LGC_AND 
-- @field TYPE_LGC_OR  
-- @field TYPE_LGC_XOR 
-- @field TYPE_BUZZER  
-------------------------------------------------------------------------------
-- Set the TYPE of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint type
function _M.setpType(setp, v)
  _M.setpParam(setp,_M.REG_SETP_TYPE, v)
  
end

-------------------------------------------------------------------------------
-- Set the Logic for the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint logic type (.LOGIC_HIGH, .LOGIC_LOW)
function _M.setpLogic(setp, v)
  _M.setpParam(setp,_M.REG_SETP_LOGIC, v)
 
end
--- Setpoint Alarms Types.
--@table Alarms
-- @field ALARM_NONE      
-- @field ALARM_SINGLE      
-- @field ALARM_DOUBLE    
-- @field ALARM_FLASH    

-------------------------------------------------------------------------------
-- Set the Alarm for the setpoint
-- @param setp is setpount 1..16
-- @param v is alarm type
function _M.setpAlarm(setp, v)
 _M.setpParam(setp,_M.REG_SETP_ALARM, v)
end

-------------------------------------------------------------------------------
-- Set the Name of the setpoint
-- @param setp is setpount 1..16
-- @param v is setpoint name (8 character string)
function _M.setpName(setp, v)
  _M.setpParam(setp,_M.REG_SETP_NAME, v)
end

--- Setpoint Source Types.
--@table Source
-- @field SOURCE_GROSS 
-- @field SOURCE_NET 
-- @field SOURCE_DISP 
-- @field SOURCE_ALT_GROSS 
-- @field SOURCE_ALT_NET 
-- @field SOURCE_ALT_DISP 
-- @field SOURCE_PIECE 
-- @field SOURCE_REG 
-------------------------------------------------------------------------------
-- Set the data source of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint source type
-- @param reg is register address for setpoints using .SOURCE_REG type source data.  
-- For other setpoint source types parameter reg is not required.
function _M.setpSource(setp, v, reg)
  _M.setpParam(setp,_M.REG_SETP_SOURCE, v)
  if (v == _M.SOURCE_REG) and reg then
     _M.setpParam(setp,_M.REG_SETP_SOURCE_REG, reg)
  end   
end

-------------------------------------------------------------------------------
-- Set the Hysteresis for of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint hysteresis
function _M.setpHys(setp, v)
  _M.setpParam(setp,_M.REG_SETP_HYS, _M.toPrimary(v))
end

-------------------------------------------------------------------------------
--- Dialog Control.
-- Functions for user interface dialogues
-- @section dialog
-------------------------------------------------------------------------------

_M.getKeyPressed = 0
_M.getKeyState = ''

function _M.getKeyCallback(key, state)
    _M.getKeyPressed = key
    _M.getKeyState = state
    return true
end 

-------------------------------------------------------------------------------
-- Called to get a key from specified key group
-- @param keyGroup keyGroup.all is default group 
-- @return key (KEY_), state ('short','long','up')
function _M.getKey(keyGroup)
    local keyGroup = keyGroup or _M.keyGroup.all
    local f = keyGroup.callback
    
    _M.setKeyGroupCallback(keyGroup, _M.getKeyCallback)  

    _M.getKeyState = ''
    _M.getKeyPressed = nil
    while _M.app.running and _M.getKeyState == '' do
        _M.system.handleEvents()
    end   
    _M.setKeyGroupCallback(keyGroup, f)
  
    return _M.getKeyPressed, _M.getKeyState  
 
 end
_M.editing = false
-------------------------------------------------------------------------------
-- Check to see if editing routines active
-- @return true of editing false otherwise
function _M.isEditing()
   return _M.editing
end

_M.scrUpdTm = 0.5  -- screen update frequency in mSec
_M.blink = false   -- blink cursor for string editing
_M.inMenu = false  -- true when a menu is active, prevents entering another menu

-----------------------------------------------------------------------------------------------
-- return a character for the key pressed, according to the number of times it has been pressed
-- @param k key pressed
-- @param p number of times key has been pressed
-- @return letter, number or symbol character represented on the number key pad
-----------------------------------------------------------------------------------------------

_M.keyChar = function(k, p)

    local n = math.fmod(p, 4)   -- fmod returns the remainder of the integer division

    if k == _M.KEY_1 then
        if n == 1 then          -- one key press
            return "$"
        elseif n == 2 then      -- two key presses
            return "/"
        elseif n == 3 then      -- three key presses
            return "\\"
        elseif n == 0 then      -- four key presses
            return "1"
        end
    elseif k == _M.KEY_2 then
        if n == 1 then          -- one key press
            return "A"
        elseif n == 2 then      -- two key presses
            return "B"
        elseif n == 3 then      -- three key presses
            return "C"
        elseif n == 0 then      -- four key presses
            return "2"
        end
    elseif k == _M.KEY_3 then
        if n == 1 then          -- one key press
            return "D"
        elseif n == 2 then      -- two key presses
            return "E"
        elseif n == 3 then      -- three key presses
            return "F"
        elseif n == 0 then      -- four key presses
            return "3"
        end
    elseif k == _M.KEY_4 then
        if n == 1 then          -- one key press
            return "G"
        elseif n == 2 then      -- two key presses
            return "H"
        elseif n == 3 then      -- three key presses
            return "I"
        elseif n == 0 then      -- four key presses
            return "4"
        end
    elseif k == _M.KEY_5 then
        if n == 1 then          -- one key press
            return "J"
        elseif n == 2 then      -- two key presses
            return "K"
        elseif n == 3 then      -- three key presses
            return "L"
        elseif n == 0 then      -- four key presses
            return "5"
        end
    elseif k == _M.KEY_6 then
        if n == 1 then          -- one key press
            return "M"
        elseif n == 2 then      -- two key presses
            return "N"
        elseif n == 3 then      -- three key presses
            return "O"
        elseif n == 0 then      -- four key presses
            return "6"
        end
    elseif k == _M.KEY_7 then
        n = math.fmod(p, 5)     -- special case with 5 options
        if n == 1 then          -- one key press
            return "P"
        elseif n == 2 then      -- two key presses
            return "Q"
        elseif n == 3 then      -- three key presses
            return "R"
        elseif n == 4 then      -- four key presses
            return "S"
        elseif n == 0 then      -- five key presses
            return "7"
        end
    elseif k == _M.KEY_8 then
        if n == 1 then          -- one key press
            return "T"
        elseif n == 2 then      -- two key presses
            return "U"
        elseif n == 3 then      -- three key presses
            return "V"
        elseif n == 0 then      -- four key presses
            return "8"
        end
    elseif k == _M.KEY_9 then
        n = math.fmod(p, 5)     -- special case with 5 options
        if n == 1 then          -- one key press
            return "W"
        elseif n == 2 then      -- two key presses
            return "X"
        elseif n == 3 then      -- three key presses
            return "Y"
        elseif n == 4 then      -- three key presses
            return "Z"
        elseif n == 0 then      -- five key presses
            return "9"
        end
    elseif k == _M.KEY_0 then
        n = math.fmod(p, 2)     -- special case with 2 options
        if n == 1 then          -- one key press
            return " "
        elseif n == 0 then      -- two key presses
            return "0"
        end
    end
    return nil      -- key passed to function is not a number key
end

function sTrim(s)       -- removes whitespace from strings
    return s:match'^%s*(.*%S)' or ''
end

_M.sEditVal = ' '       -- default edit value for sEdit()
_M.sEditIndex = 1       -- starting index for sEdit()
_M.sEditKeyTimer = 0    -- counts time since a key pressed for sEdit() - in _M.scrUpdTm increments
_M.sEditKeyTimeout = 4  -- number of counts before starting a new key in sEdit()

local function blinkCursor()
--  used in sEdit() function below
    _M.sEditKeyTimer = _M.sEditKeyTimer + 1 -- increment key press timer for sEdit()
    local str
    local pre
    local suf
    local max = #_M.sEditVal
    _M.blink = not _M.blink
    if _M.blink then
        pre = string.sub(_M.sEditVal, 1, _M.sEditIndex-1)
        if _M.sEditIndex < max then
            suf = string.sub(_M.sEditVal, _M.sEditIndex+1, -1)
        else
            suf = ''
        end
        str = pre .. "_" .. suf
    else
        str = _M.sEditVal
    end
--  print(str)  -- debug
    _M.writeBotLeft(str)
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a string
-- @param prompt string displayed on bottom right LCD
-- @param def default value\
-- @param maxLen maximum number of characters to include
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return value and true if ok pressed at end

_M.sEdit = function(prompt, def, maxLen, units, unitsOther)

    _M.editing = true               -- is editing occurring
    local key, state                -- instrument key values
    local pKey = nil                -- previous key pressed
    local presses = 0               -- number of consecutive presses of a key
    
    if def then                     -- if a string is supplied
        def = sTrim(def)            -- trim any whitespace
    end
    
    local default = def or ' '      -- default string to edit, if no default passed to function, default to one space
    _M.sEditVal = tostring(default) -- edit string
    local sLen = #_M.sEditVal       -- length of string being edited
    _M.sEditIndex = sLen            -- index in string of character being edited
    local ok = false                -- OK button was pressed to accept editing
    local strTab = {}               -- temporary table holding edited string characters
    local blink = false             -- cursor display variable
    local u = units or 0            -- optional units defaults to none
    local uo = unitsOther or 0      -- optional other units defaults to none
    
    cursorTmr = _M.system.timers.addTimer(_M.scrUpdTm, 0, blinkCursor)  -- add timer to blink the cursor
    _M.saveBot()

    if sLen >= 1 then   -- string length should always be >= 1 because of 'default' assignment above
        local i = 0
        repeat
            i = i + 1
            strTab[i] = string.sub(_M.sEditVal, i, i)   -- convert the string to a table for easier character manipulation 
        until i >= sLen or i >= maxLen                  -- check length of string against maxLen
--      print('strTab = ' .. table.concat(strTab))  -- debug
    end
    
    if def then         -- if a default string is given
        pKey = 'def'    -- give pKey a value so we start editing from the end
    end

    _M.writeBotRight(prompt)        -- write the prompt
    _M.writeBotLeft(_M.sEditVal)    -- write the default string to edit
    _M.writeBotUnits(u,uo)          -- display optional units

    while _M.editing do
        key, state = _M.getKey(_M.keyGroup.keypad)  -- wait for a key press
        if _M.sEditKeyTimer > _M.sEditKeyTimeout then   -- if a key is not pressed for a couple of seconds
            pKey = 'timeout'                            -- ignore previous key presses and treat this as a different key
        end
        _M.sEditKeyTimer = 0                        -- reset the timeout counter now a key has been pressed
        
        if state == "short" then                            -- short key presses for editing
            if key >= _M.KEY_0 and key <= _M.KEY_9 then     -- keys 0 to 9 on the keypad
--              print('i:' .. _M.sEditIndex .. ' l:' .. sLen)   -- debug
                if key == pKey then         -- if same as the previous key pressed
                    presses = presses + 1   -- add 1 to number of presses of this key
                else
                    presses = 1             -- otherwise reset presses to 1
                    if pKey and (_M.sEditIndex >= sLen) and (strTab[_M.sEditIndex] ~= " ") then     -- if not first key pressed
                        _M.sEditIndex = _M.sEditIndex + 1       -- new key pressed, increment the character position
                    end
                    pKey = key              -- remember the key pressed
                end
--              print('i:' .. _M.sEditIndex)    -- debug
                strTab[_M.sEditIndex] = _M.keyChar(key, presses)    -- update the string (table) with the new character
            --
            elseif (key == _M.KEY_DP) and (key ~= pKey) then        -- decimal point key (successive decimal points not allowed)
                if (pKey and (_M.sEditIndex >= sLen)) or (strTab[_M.sEditIndex] == " ") then    -- if not first key pressed and not space at end
                    _M.sEditIndex = _M.sEditIndex + 1           -- new key pressed, increment the character position
                end
                strTab[_M.sEditIndex] = "."                 -- update the string (table) with the new character
                pKey = key                                  -- remember the key pressed
            --
            elseif key == _M.KEY_UP then                    -- up key, previous character
                _M.sEditIndex = _M.sEditIndex - 1               -- decrease index
                if _M.sEditIndex < 1 then                       -- if at first character
                    _M.sEditIndex = sLen                            -- go to last character
                end
                pKey = key                                  -- remember the key pressed
            --
            elseif key == _M.KEY_DOWN then          -- down key, next character
                _M.sEditIndex = _M.sEditIndex + 1       -- increment index
                if _M.sEditIndex > sLen then            -- if at last character
                    if strTab[sLen] ~= " " then         -- and last character is not a space
                        if sLen < maxLen then               -- and length of string < maximum
                            sLen = sLen + 1                     -- increase length of string
                            strTab[sLen] = " "                  -- and add a space to the end
                        else                                -- string length = maximum
                            _M.sEditIndex = 1                   -- go to the first character
                        end
                    else                                -- otherwise (last character is a space)
                        if sLen > 1 then                    -- as long as the string is more than 1 character long
                            strTab[sLen] = nil              -- delete the last character
                            sLen = sLen - 1                 -- decrease the length of the string
                            _M.sEditIndex = 1               -- and go to the first character
                        end
                    end
                end
                pKey = key                                  -- remember the key pressed
            --
            elseif key == _M.KEY_PLUSMINUS then     -- plus/minus key - insert a character
                if sLen < maxLen then
                    sLen = sLen + 1                     -- increase the length of the string
                end
                for i = sLen, _M.sEditIndex+1, -1 do
                    strTab[i] = strTab[i-1]             -- shuffle the characters along
                end
                strTab[_M.sEditIndex] = " "             -- insert a space
                pKey = key                          -- remember the key pressed
            --
            elseif key == _M.KEY_OK then        -- OK key
                _M.editing = false                      -- finish editing
                ok = true                           -- accept changes
            --
            elseif key == _M.KEY_CANCEL then    -- cancel key
                if _M.sEditIndex < sLen then
                    for i = _M.sEditIndex, sLen-1 do    -- delete current character
                        strTab[i] = strTab[i+1]         -- shuffle characters along
                    end
                end
                strTab[sLen] = nil                  -- clear last character
                _M.sEditIndex = _M.sEditIndex - 1   -- decrease length of string
                pKey = key                          -- remember the key pressed
            end
        elseif state == "long" then         -- long key press only for cancelling editing
            if key == _M.KEY_CANCEL then    -- cancel key
                _M.sEditVal = default               -- reinstate default string
                _M.editing = false                  -- finish editing
            end
        end
        if _M.editing or ok then                    -- if editing or OK is selected
            _M.sEditVal = table.concat(strTab)      -- update edited string
            sLen = #_M.sEditVal
--          print('eVal = \'' .. _M.sEditVal .. '\'')   -- debug
        end
    end

    _M.restoreBot() -- restore previously displayed messages

    _M.system.timers.removeTimer(cursorTmr) -- remove cursor blink timer
    return _M.sEditVal, ok                  -- return edited string and OK status
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a value, numeric digits and '.' only
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param typ type of value to enter ('integer','number','string','passcode') 
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return value and true if ok pressed at end
function _M.edit(prompt, def, typ, units, unitsOther)

    local key, state

    if typ == 'passcode' then
        typ = 'integer'
        hide = true
    end    
        
    local def = def or ''
    if type(def) ~= 'string' then
         def = tostring(def)
     end    
    
    local u = units or 0
    local uo = unitsOther or 0     
    
    local editVal = def 
    local editType = typ or 'integer'
    _M.editing = true
    
    _M.saveBot()
    _M.writeBotRight(prompt)
    if hide then
       _M.writeBotLeft(string.rep('+',#editVal))
    else
       _M.writeBotLeft(editVal)
    end   
    _M.writeBotUnits(u, uo)

    local first = true

    local ok = false  
    while _M.editing do
        key, state = _M.getKey(_M.keyGroup.keypad)
        if state == 'short' then
            if key >= _M.KEY_0 and key <= _M.KEY_9 then
                if first then 
                    editVal = tostring(key) 
                else 
                    editVal = editVal .. key 
                end
                first = false
            elseif key == _M.KEY_DP and editType ~= 'integer' then
                if editType == 'number' then 
                    if first or string.len(editVal) == 0 then
                       editVal = '0.'
                       first = false
                    elseif not string.find(editVal,'%.')  then
                       editVal = editVal .. '.'
                    end
                else 
                   editVal = editVal .. '.'             
                end
            elseif key == _M.KEY_OK then         
                _M.editing = false
                 if string.len(editVal) == 0 then
                    editVal = def
                 end    
                ok = true
            elseif key == _M.KEY_CANCEL then    
                if string.len(editVal) == 0 then
                    editVal = def
                    _M.editing = false
                else
                    editVal = string.sub(editVal,1,-2)
                end 
            end      
        elseif state == 'long' then
            if key == _M.KEY_CANCEL then
                editVal = def
                _M.editing = false
            end
        end 
        if hide then 
           _M.writeBotLeft(string.rep('+',#editVal))
        else
           _M.writeBotLeft(editVal..' ')
        end   
    end 
    _M.restoreBot()
   
    return tonumber(editVal), ok
end

_M.REG_EDIT_REG = 0x0320
-------------------------------------------------------------------------------
--  Called to edit value of specified register
-- @param reg is the address of the register to edit
-- @param prompt is true if name of register to be displayed during editing, 
-- or set to a literal prompt to display
-- @return value of reg
function _M.editReg(reg,prompt)
   if (prompt) then
      _M.saveBot()
      if type(prompt) == 'string' then
         _M.writeBotRight(prompt)
      else
         _M.writeBotRight(_M.sendRegWait(_M.CMD_RDNAME,reg))
      end   
   end
   _M.sendRegWait(_M.CMD_WRFINALDEC,_M.REG_EDIT_REG,reg)
   while true do 
     local data,err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_EDIT_REG)
     
     if err or (data and tonumber(data,16) ~= reg) then 
       break
     end
     _M.delay(0.050)
   end
   if prompt then
      _M.restoreBot()
   end
   return _M.literalToFloat(_M.sendRegWait(_M.CMD_RDLIT,reg))
end

_M.delayWaiting = false

-------------------------------------------------------------------------------
-- Private function
function _M.delayCallback()
    _M.delayWaiting = false
end

-------------------------------------------------------------------------------
-- Called to delay for t sec while keeping event handlers running
-- @param t delay time in sec 
function _M.delay(t)
    local tmr = _M.system.timers.addTimer(0, t, _M.delayCallback)
    _M.delayWaiting = true
    while _M.delayWaiting do
        _M.system.handleEvents()
    end  
    _M.system.timers.removeTimer(tmr)
end

_M.askOKWaiting = false
_M.askOKResult = 0
-------------------------------------------------------------------------------
-- Private function
function _M.askOKCallback(key, state)
    
    if state ~= 'short' then 
        return false 
    end
    
    if key == _M.KEY_OK then
        _M.askOKWaiting = false
        _M.askOKResult = _M.KEY_OK
    elseif key == _M.KEY_CANCEL then
        _M.askOKWaiting = false
        _M.askOKResult = _M.KEY_CANCEL
    end

    return true 
end

-------------------------------------------------------------------------------
-- Prompts operator and waits for OK or CANCEL key press
-- @param prompt string to put on bottom right LCD
-- @param q string to put on bottom left LCD
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return either KEY_OK or KEY_CANCEL
function _M.askOK(prompt, q, units, unitsOther)

    local f = _M.keyGroup.keypad.callback
    local prompt = prompt or ''
    local q = q or ''  
    local u = units or 0
    local uo = unitsOther or 0
  
    _M.setKeyGroupCallback(_M.keyGroup.keypad, _M.askOKCallback)  

    _M.saveBot()
    _M.writeBotRight(prompt)
    _M.writeBotLeft(q)
    _M.writeBotUnits(0,0)
    _M.writeBotUnits(u,uo)
 
    _M.askOKWaiting = true
    _M.askOKResult = _M.KEY_CANCEL
    while _M.askOKWaiting and _M.app.running do
        _M.system.handleEvents()
    end   
    _M.setKeyGroupCallback(_M.keyGroup.keypad, f)

    _M.restoreBot() 
    return _M.askOKResult  
  
end  

-------------------------------------------------------------------------------
-- Prompts operator to select from a list of options using 
-- arrow keys and KEY_OK
-- @param prompt string to put on bottom right LCD
-- @param options table of option strings
-- @param def default selection string.byte
-- @param loop If true, top option loops to the bottom option and vice versa
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return selected string  if OK pressed or nil if CANCEL pressed
function _M.selectOption(prompt, options, def, loop,units,unitsOther)
    loop = loop or false
    local options = options or {'cancel'}
    local u = units or 0
    local uo = unitsOther or 0
    local key = 0
    local sel = nil

    local index = 1
    if def then
        for k,v in ipairs(options) do
            if v == def then
                index = k
            end
        end
    end 

    _M.editing = true

    _M.saveBot()
    _M.writeBotRight(string.upper(prompt))
    _M.writeBotLeft(string.upper(options[index]))
    _M.writeBotUnits(u,uo)

    while _M.editing and _M.app.running do
        key = _M.getKey(_M.keyGroup.keypad)  
        if key == _M.KEY_DOWN then
            index = index + 1
            if index > #options then
              if loop then 
                 index = 1
               else
                  index = #options
               end
            end
        elseif key == _M.KEY_UP then
            index = index - 1
            if index <= 0 then
               if loop then 
                   index = #options 
               else 
                  index = 1
               end   
            end
        elseif key == _M.KEY_OK then 
            sel = options[index]
            _M.editing = false
        elseif key == _M.KEY_CANCEL then
          _M.editing = false     
      end
      _M.writeBotLeft(string.upper(options[index]))
      
    end  
      
    _M.restoreBot()  
   
    return sel
end

-------------------------------------------------------------------------------
--- Printing Utilities.
-- Functions for printing
-- @section printing

-- Custom Print Strings

_M.REG_PRINTPORT        = 0xA317
_M.REG_PRINTTOKENSTR    = 0x004C
_M.REG_REPLYTOKENSTR    = 0x004D

_M.PRINT_SER1A          = 0
_M.PRINT_SER1B          = 1
_M.PRINT_SER2A          = 2
_M.PRINT_SER2B          = 3
_M.curPrintPort         = 0xFF

-------------------------------------------------------------------------------
-- Takes a string s and returns a formatted CustomTransmit string with all 
-- non-printable characters escaped in \xx format
-- @param s  string to convert
-- @return string with all non-printable characters escaped in \xx format
function _M.expandCustomTransmit(s)

  return string.format('%s',string.gsub(s,"[^\32-\126]",      
                        function(x) 
                            return string.format("\\%02X",string.byte(x))
                        end))
end

-------------------------------------------------------------------------------
-- Send custom print token string to instrument comms port
-- @param tokenStr  string containing custom print tokens
-- @param comPort - port to use PRINT_SER1A (default) .. PRINT_SER2B
function _M.printCustomTransmit(tokenStr, comPort)
    local comPort = comPort or _M.PRINT_SER1A
    if comPort ~= _M.curPrintPort  then
        _M.curPrintPort = comPort
        _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_PRINTPORT, comPort, 'noReply')
        _M.sendReg(_M.CMD_EX, _M.REG_SAVESETTING,0)
    end 
    _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_PRINTTOKENSTR, tokenStr, 'noReply')
end

-------------------------------------------------------------------------------
-- Called to request response based on custom transmit token string
-- @param tokenStr  custom token string
function _M.reqCustomTransmit(tokenStr)
    s =  _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_REPLYTOKENSTR, '8112004D:'..tokenStr, 1000)
    _M.dbg.printVar(s)
    -- return string.sub(s,10,-1)
    return s
end

-------------------------------------------------------------------------------
--- Real Time Clock.
-- Functions to control Real Time Clock
-- @section clock
-------------------------------------------------------------------------------

--  Time and Date
_M.REG_TIMECUR          = 0x0150
_M.REG_TIMEFORMAT       = 0x0151
_M.REG_TIMEDAY          = 0x0152
_M.REG_TIMEMON          = 0x0153
_M.REG_TIMEYEAR         = 0x0154
_M.REG_TIMEHOUR         = 0x0155
_M.REG_TIMEMIN          = 0x0156
_M.REG_TIMESEC          = 0x0157

_M.REG_MSEC1000         = 0x015C
_M.REG_MSEC             = 0x015D
_M.REG_MSECLAST         = 0x015F
_M.TM_DDMMYY            = 0
_M.TM_DDMMYYYY          = 1
_M.TM_MMDDYY            = 2
_M.TM_MMDDYYYY          = 3
_M.TM_YYMMDD            = 4
_M.TM_YYYYMMDD          = 5

-------------------------------------------------------------------------------
-- sets the instrument date format
-- @param fmt TM_MMDDYYYY or TM_DDMMYYYY
function _M.sendDateFormat(fmt)
     if fmt < _M.TM_DDMMYY or fmt > _M.TM_YYYYMMDD then
        fmt = _M.TM_DDMMYYYY
     end
  _M.sendRegWait(_M.CMD_WRFINALDEC,_M.REG_TIMEFORMAT,fmt)
end

_M.RTC = {hour = 0, min = 0, sec = 0, day = 1, month = 1, year = 2010}
_M.RTC['first'] = 'day'
_M.RTC['second'] = 'month'
_M.RTC['third'] = 'year'

-------------------------------------------------------------------------------
-- Read Real Time Clock data from instrument into local RTC table
-- @param d 'date' or 'time' to read these fields only, or 'all' for both
function _M.RTCread(d)
  local d = d or 'all'

  local fmt , err = _M.sendRegWait(_M.RDFINALDEC,_M.REG_TIMEFORMAT)
  
  if err then
    fmt = 0
  else
    fmt = tonumber(fmt)
  end
  
  if fmt == _M.TM_DDMMYYYY or fmt == _M.TM_DDMMYY then
     _M.RTCdateFormat('day','month','year')
  elseif fmt == _M.TM_MMDDYYYY or fmt == _M.TM_MMDDYY then
     _M.RTCdateFormat('month','day','year')
  else
     _M.RTCdateFormat('year','month','day')
  end
    
  local timestr, err = _M.sendRegWait(_M.CMD_RDLIT,_M.REG_TIMECUR)
  
  if err then
    timestr = '01/01/2000 00-00'
  end
  --dbg.printVar(timestr)
  
  if d == 'date' or d == 'all' then
    _M.RTC.day, _M.RTC.month, _M.RTC.year =
      string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
  end
  
  if d == 'time' or d == 'all' then
    _,_,_, _M.RTC.hour, _M.RTC.min =
      string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
  end
    
  _M.RTC.sec, err = _M.readReg(_M.REG_TIMESEC)
  
  if err then
    _M.RTC.sec = 0
  end
end

-------------------------------------------------------------------------------
-- Called every second to update local RTC 
function _M.RTCtick()
    _M.RTC.sec = _M.RTC.sec + 1
    if _M.RTC.sec > 59 then
        _M.RTC.sec = 0
        _M.RTC.min = _M.RTC.min + 1
        if _M.RTC.min > 59 then  
            _M.RTC.min = 0
            _M.RTC.hour = _M.RTC.hour + 1
            if _M.RTC.hour > 23 then    
                _M.RTC.hour = 0
                _M.RTCread()
            end                 
        end
    end
end

-------------------------------------------------------------------------------
-- Returns formated date/time string
-- Private function
function _M.RTCtostring()
    return string.format("%02d/%02d/%02d %02d:%02d:%02d",
                        _M.RTC[_M.RTC.first],
                        _M.RTC[_M.RTC.second],
                        _M.RTC[_M.RTC.third],
                        _M.RTC.hour,
                        _M.RTC.min,
                        _M.RTC.sec)
end

-------------------------------------------------------------------------------
-- Sets the order of the date string.byte
-- @param first  = 'day', 'month' or 'year'
-- @param second  = 'day', 'monht','year'
-- @param third = 'day','month','year'
function _M.RTCdateFormat(first,second,third)
    local first = first or 'day'
    local second = second or 'month'
    local third = third or 'year'
  
    _M.RTC.first = first
    _M.RTC.second = second
    _M.RTC.third = third
end  

-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------
_M.REG_ADC_ZERO         = 0x0300                  -- Execute registers
_M.REG_ADC_TARE         = 0x0301                  
_M.REG_ADC_PT           = 0x0302                  -- Tare value is parameter 
_M.REG_ADC_GROSS_NET    = 0x0303                 

_M.ADCGN_TOGGLE         = 0
_M.ADCGN_GROSS          = 1
_M.ADCGN_NET            = 2

_M.REG_ADC_HI_RES       = 0x0304                   
_M.ADCHIRES_TOGGLE      = 0
_M.ADCHIRES_ON          = 1
_M.ADCHIRES_OFF         = 2
_M.ADCHIRES_DB          = 3                       -- R420 database setting

--  Calibrate
_M.REG_CALIBWGT         = 0x0100
_M.REG_CALIBZERO        = 0x0102
_M.REG_CALIBSPAN        = 0x0103
_M.REG_CALIBLIN         = 0x0104
_M.REG_CLRLIN           = 0x0105
_M.REG_CALIBDIRZERO     = 0x0106
_M.REG_CALIBDIRSPAN     = 0x0107

--- Command Return Constants and strings.
--@table Command
-- @field CMD_OK          'OK'     command executed successfully          
-- @field CMD_CANCEL      'CANCEL'
-- @field CMD_INPROG      'IN PROG'
-- @field CMD_ERROR       'ERROR'
-- @field CMD_OL_UL       'OL-UL'
-- @field CMD_BUSY        'BUSY'
-- @field CMD_MOTION      'MOTION'
-- @field CMD_BAND        'BAND'
-- @field CMD_RESLOW      'RES LOW'
-- @field CMD_COMMAND     'COMMAND'
-- @field CMD_DUPLIC      'DUPLIC'
-- @field CMD_HIRES       'HI RES'

_M.CMD_OK         = 0
_M.CMD_CANCEL     = 1
_M.CMD_INPROG     = 2
_M.CMD_ERROR      = 3
_M.CMD_OL_UL      = 4
_M.CMD_BUSY       = 5
_M.CMD_MOTION     = 6
_M.CMD_BAND       = 7
_M.CMD_RESLOW     = 8
_M.CMD_COMMAND    = 9
_M.CMD_DUPLIC     = 10
_M.CMD_HIRES      = 11

_M.cmdString = {}
_M.cmdString[0] = 'OK'
_M.cmdString[1] = 'CANCEL'
_M.cmdString[2] = 'IN PROG'
_M.cmdString[3] = 'ERROR'
_M.cmdString[4] = 'OL-UL'
_M.cmdString[5] = 'BUSY'
_M.cmdString[6] = 'MOTION'
_M.cmdString[7] = 'BAND'
_M.cmdString[8] = 'RES LOW'
_M.cmdString[9] = 'COMMAND'
_M.cmdString[10] = 'DUPLICATE'
_M.cmdString[11] = 'HI RES'

-------------------------------------------------------------------------------
-- Called to execute a Zero command
-- @return CMD_ constant followed by command return string
function _M.zero()
    local msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_ZERO,nil,15.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end
end

-------------------------------------------------------------------------------
-- Called to execute a Tare command
-- @return CMD_ constant followed by command return string
function _M.tare()

    local msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_TARE,nil,15.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end  
end

-------------------------------------------------------------------------------
-- Called to execute a Pre-set Tare command
-- @param pt is the preset tare value 
-- @return CMD_ constant followed by command return string
function _M.presetTare(pt)
    local pt = pt or 0
    local msg, err =  _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_PT,pt,5.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end
end

-------------------------------------------------------------------------------
-- Command to set Gross Mode
-- @return CMD_ constant followed by command return string
function _M.gross()
    local msg, err =  _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_GROSS_NET,_M.ADCGN_GROSS,1.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end
end

-------------------------------------------------------------------------------
-- Command to set Net mode
-- @return CMD_ constant followed by command return string
function _M.net()
    local msg, err =  _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_GROSS_NET,_M.ADCGN_NET,1.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end
end

-------------------------------------------------------------------------------
-- Command to toggle Gross Net status
-- @return CMD_ constant followed by command return string
function _M.grossNetToggle()
    local msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_GROSS_NET,_M.ADCGN_TOGGLE,1.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end
end

_M.REG_FULLPCODEDATA     = 0x00D0
_M.REG_SAFEPCODEDATA     = 0x00D1
_M.REG_OPERPCODEDATA     = 0x00D2

_M.REG_FULLPCODE         = 0x0019
_M.REG_SAFEPCODE         = 0x001A
_M.REG_OPERPCODE         = 0x001B

_M.passcodes = {}
_M.passcodes.full = {}
_M.passcodes.safe = {}
_M.passcodes.oper = {}
_M.passcodes.full.pcode     = _M.REG_FULLPCODE
_M.passcodes.full.pcodeData = _M.REG_FULLPCODEDATA
_M.passcodes.safe.pcode     = _M.REG_SAFEPCODE
_M.passcodes.safe.pcodeData = _M.REG_SAFEPCODEDATA
_M.passcodes.oper.pcode     = _M.REG_OPERPCODE
_M.passcodes.oper.pcodeData = _M.REG_OPERPCODEDATA

-------------------------------------------------------------------------------
-- Command to check to see if passcode entry required and prompt if so
-- @param pc = 'full','safe','oper'
-- @param code = passcode to unlock, nil to prompt user
-- @return true if unlocked false otherwise
function _M.checkPasscode(pc, code)
    local pc = pc or 'full'
    local pcode = _M.passcodes[pc].pcode
    local f = _M.removeErrHandler()
    local pass = ''
    while true do    
       msg, err = _M.sendRegWait(_M.CMD_RDFINALHEX,pcode,nil,1.0)
       if not msg then
          if code then
             pass = code
             code = nil
          else   
             pass, ok = _M.edit('PCODE','','passcode')
             if not ok then
                _M.setErrHandler(f)
                return false
             end 
          end              
          msg, err = _M.sendRegWait(_M.CMD_WRFINALHEX,pcode,_M.toPrimary(pass,0),1.0) 
       else
          break
       end   
    end    
    _M.setErrHandler(f)
    return true
end

-------------------------------------------------------------------------------
-- Command to lock instrument
-- @param pc = 'full','safe','oper'
function _M.lockPasscode(pc)
    local pc = pc or 'full'
    local pcode = _M.passcodes[pc].pcode
    local pcodeData = _M.passcodes[pc].pcodeData
 
    local f = _M.removeErrHandler()
    local msg, err = _M.sendRegWait(_M.CMD_RDFINALHEX,pcodeData,nil,1.0)
    if msg then
       msg = bit32.bxor(tonumber(msg,16),0xFF)  
       msg, err = _M.sendRegWait(_M.CMD_WRFINALHEX,pcode,_M.toPrimary(msg,0),1.0) 
    end    
    _M.setErrHandler(f)
end

-------------------------------------------------------------------------------
-- Command to change instrument passcode
-- @param pc = 'full','safe','oper'
-- @param oldCode passcode to unlock, nil to prompt user
-- @param newCode passcode to set, nil to prompt user
-- @return true if successful
function _M.changePasscode(pc, oldCode, newCode)
   local pc = pc or 'full'
   local pcodeData = _M.passcodes[pc].pcodeData
   if _M.checkPasscode(pc,oldCode) then
        if not newCode then
             local pass, ok = _M.edit('NEW','','passcode')
             if not ok then
                return false
             end
             newCode = pass
        end             
        local msg, err = _M.sendRegWait(_M.CMD_WRFINALHEX,pcodeData,_M.toPrimary(newCode,0),1.0)
        if not msg then
           return false
        else
           return true
        end    
    end
    return false    
end

-------------------------------------------------------------------------------
-- Command to calibrate Zero
-- @return CMD_ constant followed by command return string
function _M.calibrateZero()
    
    local msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_CALIBZERO,nil,1.0)
    if not msg then
        return msg, err
    end    
    while true do 
       msg, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_SYSSTATUS,nil,1.0)
       if msg then
           msg = tonumber(msg,16)
           if bit32.band(msg,_M.SYS_CALINPROG) == 0 then
              msg = bit32.band(msg,0x0F)
              return msg, _M.cmdString[msg] 
           end    
       else 
           return msg, err
       end    
    end   
end

-------------------------------------------------------------------------------
-- Command to calibrate Span
-- @param span weight value for calibration
-- @return CMD_ constant followed by command return string
function _M.calibrateSpan(span)
    
    if type(span) == 'string' then
       span = tonumber(span)
    end   
    local msg, err = _M.sendRegWait(_M.CMD_WRFINALDEC,_M.REG_CALIBWGT,_M.toPrimary(span),1.0)
    if not msg then
        return msg, err
    end
    
    msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_CALIBSPAN,nil,1.0)
    if not msg then
        return msg, err
    end    

    while true do 
       msg, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_SYSSTATUS,nil,1.0)
       if msg then
           msg = tonumber(msg,16)
           if bit32.band(msg,_M.SYS_CALINPROG) == 0 then
              msg = bit32.band(msg,0x0F)
              return msg, _M.cmdString[msg] 
           end    
       else 
           return msg, err
       end    
    end 
end

-------------------------------------------------------------------------------
-- Command to calibrate Zero using MV/V signal
-- @param MVV signal for zero
-- @return CMD_ constant followed by command return string
function _M.calibrateZeroMVV(MVV)
    if type(MVV) == 'string' then
       MVV = tonumber(MVV)
    end   
    msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_CALIBDIRZERO,_M.toPrimary(MVV,4),1.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end
end

-------------------------------------------------------------------------------
-- Command to calibrate Span using MV/V signal
-- @param MVV signal for fullscale
-- @return CMD_ constant followed by command return string
function _M.calibrateSpanMVV(MVV)
    if type(MVV) == 'string' then
       MVV = tonumber(MVV)
    end   
    msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_CALIBDIRSPAN,_M.toPrimary(MVV,4),1.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end
end

_M.REG_ZEROMVV  = 0x0111
_M.REG_SPANWGT  = 0x0112
_M.REG_SPANMVV  = 0x0113
_M.REG_LINWGT   = 0x0114
_M.REG_LINPC    = 0x0115
_M.NUM_LINPTS   = 10
-------------------------------------------------------------------------------
-- Command to read MVV zero calibration
-- @return MVV signal or nil with error string if error encountered
function _M.readZeroMVV()
    local data, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_ZEROMVV)
    if data then
        data = _M.toFloat(data,4)
        return data, nil
    else
        return data,error
    end     
end

-------------------------------------------------------------------------------
-- Command to read MVV span calibration
-- @return MVV signal or nil with error string if error encountered
function _M.readSpanMVV()
    local data, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_SPANMVV)
    if data then
        data = _M.toFloat(data,4)
        return data, nil
    else
         return data,error
    end   
end
-------------------------------------------------------------------------------
-- Command to read span calibration weight
-- @return span weight used on the last span calibration
function _M.readSpanWeight()
    local data, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_SPANWGT)
    if data then
        data = _M.toFloat(data)
        return data, nil
    else
        return data,error
    end   
end

-------------------------------------------------------------------------------
-- Command to read linearisation results
-- @return linearisation results in a table of 10 lines with each line having
-- pc (percentage of fullscale that point in applied), 
-- correction (amount of corrected weight)
-- if error return nil plus error string  
function _M.readLinCal()
    local t = {}
    for i = 1,_M.NUM_LINPTS do
        table.insert(t,{})
        local msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_LINPC,i-1,1.0)
        if not msg then
            return msg, err
        else
            t[i].pc = _M.toFloat(msg,0)      
        end    
        
        msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_LINWGT,i-1,1.0)
        if not msg then
            return msg, err
        else
            t[i].correction = _M.toFloat(msg)      
        end 
    end 
    return t, nil 
end

-------------------------------------------------------------------------------
-- Command to calibrate linearisation point
-- @param pt is the linearisation point 1..10 
-- @param val is the weight value for the current linearisation point
-- @return CMD_ constant followed by command return string
function _M.calibrateLin(pt, val)
    if type(pt) == 'string' then
       pt = tonumber(pt)
    end   

    if (pt < 1) or (pt > _M.NUM_LINPTS) then
        return nil, 'Linearisation point out of range' 
    end
    
    if type(val) == 'string' then
       val = tonumber(val)
    end   
    local msg, err = _M.sendRegWait(_M.CMD_WRFINALDEC,_M.REG_CALIBWGT,_M.toPrimary(val),1.0)
    if not msg then
        return msg, err
    end
    
    msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_CALIBLIN,pt-1,1.0)
    if not msg then
        return msg, err
    end    

    while true do 
       msg, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_SYSSTATUS,nil,1.0)
       if msg then
           msg = tonumber(msg,16)
           if bit32.band(msg,_M.SYS_CALINPROG) == 0 then
              msg = bit32.band(msg,0x0F)
              return msg, _M.cmdString[msg] 
           end    
       else 
           return msg, err
       end    
    end 
end

-------------------------------------------------------------------------------
-- Command to calibrate Span
-- @param pt is the linearisation point 1..10 
-- @return CMD_ constant followed by command return string
function _M.clearLin(pt)
    if type(pt) == 'string' then
       pt = tonumber(pt)
    end   

    if (pt < 1) or (pt > _M.NUM_LINPTS) then
        return nil, 'Linearisation point out of range' 
    end
    
    msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_CLRLIN,pt-1,1.0)
    if msg then
        msg = tonumber(msg)
        return msg, _M.cmdString[msg]
    else 
        return msg, err
    end
end

-------------------------------------------------------------------------------
-- Called to trigger initial stream reads and establish initial conditions
function _M.init()
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

   if streamUser then
      _M.send(nil,_M.CMD_RDFINALHEX,
                 bit32.bor(_M.REG_LUAUSER,_M.REG_STREAMDATA),
                 '','reply')
    end             
   _M.send(nil,_M.CMD_RDFINALHEX,
              bit32.bor(_M.REG_LUALIB,_M.REG_STREAMDATA),
              '', 'reply')
   _M.sendKey(_M.KEY_CANCEL,'long')
             
end
return _M
