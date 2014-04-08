-------------------------------------------------------------------------------
---  General Utilities.
-- General Functions for configuring the instrument
-- @module rinLibrary.K400Util
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local string = string
local tonumber = tonumber
local type = type
local math = math
local bit32 = require "bit"

-- build rest of K400 on top of rinCon
local tmp = require "rinLibrary.K400Reg"
local _M = tmp  
package.loaded["rinLibrary.K400Reg"] = nil



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
  end                              -- TODO: how to handle non-numbers elegantly here?  
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
       
            local _,cmd,reg,data,err = _M.processMsg(line)
            if err then
               _M.dbg.error('RIS error: ',err)
            end   
            _M.sendRegWait(cmd,reg,data)
         end
    end
    _M.saveSettings()
    file:close()
end




return _M
