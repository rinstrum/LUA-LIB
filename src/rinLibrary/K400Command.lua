-------------------------------------------------------------------------------
-- Library for K400 high level command support.
-- @module rinLibrary.K400Command
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local tonumber = tonumber
local tostring = tostring
local bit32 = require "bit"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, depricated)

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
-- @usage
-- device.zero()
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
-- @usage
-- device.tare()
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
-- @usage
-- device.presetTare(0)
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
-- @usage
-- device.gross()
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
-- @usage
-- device.net()
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
-- @usage
-- device.grossNetToggle()
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

local passcodes = {}
passcodes.full = {}
passcodes.safe = {}
passcodes.oper = {}
passcodes.full.pcode     = _M.REG_FULLPCODE
passcodes.full.pcodeData = _M.REG_FULLPCODEDATA
passcodes.safe.pcode     = _M.REG_SAFEPCODE
passcodes.safe.pcodeData = _M.REG_SAFEPCODEDATA
passcodes.oper.pcode     = _M.REG_OPERPCODE
passcodes.oper.pcodeData = _M.REG_OPERPCODEDATA

-------------------------------------------------------------------------------
-- Command to check to see if passcode entry required and prompt if so
-- @param pc = 'full','safe','oper'
-- @param code = passcode to unlock, nil to prompt user
-- @param tries = number of tries to make before giving up (default 1)
-- @return true if unlocked false otherwise
-- @usage
-- if device.checkPasscode('full', _, 5) then
--     print('you have full access now')
-- end
function _M.checkPasscode(pc, code, tries)
    local pc = pc or 'full'
    local pcode = passcodes[pc].pcode
    local f = _M.removeErrHandler()
    local pass = ''
    local tries = tries or 1
    local count = 1
    _M.startDialog()
    while _M.dialogRunning() and _M.app.running do 
       msg, err = _M.sendRegWait(_M.CMD_RDFINALHEX,pcode,nil,1.0)
       if not msg then
          if  count > tries then
                _M.setErrHandler(f)
                _M.abortDialog()
                return false
          end          
          if count > 1 and err then
             _M.writeBotLeft(string.upper(err),1.0)
             _M.buzz(1,_M.BUZZ_LONG)
             _M.delay(2.0)
          end   
          if code then
             pass = code
             code = nil
          else   
            pass, ok = _M.edit('ENTER PCODE','','passcode')            
            if not ok or not pass then
                _M.setErrHandler(f)
                _M.abortDialog()
                return false
             end 
          end              
          msg, err = _M.sendRegWait(_M.CMD_WRFINALHEX,pcode,_M.toPrimary(pass,0),1.0) 
          count = count + 1 
       else
          break
       end   
    end    
    _M.abortDialog()
    _M.setErrHandler(f)
    return true
end

-------------------------------------------------------------------------------
-- Command to lock instrument
-- @param pc = 'full','safe','oper'
-- Set a timeout of thirty seconds before full access is lost
-- timers = require 'rinSystem.rinTimers.Pack'
-- timers.addTimer(0, 30, function() device.lockPasscode('full') end)
function _M.lockPasscode(pc)
    local pc = pc or 'full'
    local pcode = passcodes[pc].pcode
    local pcodeData = passcodes[pc].pcodeData
 
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
-- @usage
-- local pc = device.selectOption('ENTER PASSCODE', {'full', 'safe', 'oper'}, 'full', true)
-- if pc then
--     device.changePasscode(pc)
-- end
function _M.changePasscode(pc, oldCode, newCode)
   local pc = pc or 'full'
   local pcodeData = passcodes[pc].pcodeData
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
-- @return CMD_ constant
-- @return command return string
-- @usage
-- local ret, msg = device.calibrateZero()
-- if ret == 0 then
--     print('Zero MVV:', device.readZeroMVV())
-- end
-- print(msg)
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
-- @return CMD_ constant
-- @return command return string
-- @usage
-- local ret, msg = device.calibrateSpan(device.editReg('calibwgt')) 
-- if ret == 0 then
--     print('Span Calibration Weight: ', device.readSpanWeight())
--     print('Span MVV: ', device.readSpanMVV())
-- end
-- print(msg)
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
-- @return CMD_ constant
-- @return command return string
-- @usage
-- local MVV = device.edit('MVV ZERO', '0', 'number')
-- local ret, msg = device.calibrateZeroMVV(MVV) 
-- print(msg)
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
-- @usage
-- local MVV = device.edit('MVV SPAN','2.0','number')
-- local ret, msg = device.calibrateSpanMVV(MVV)   
-- print(msg)
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
-- @return MVV signal or nil on error
-- @return error string if error encountered, nil otherwise
-- @usage
-- local ret, msg = device.calibrateZero()
-- if ret == 0 then
--     print('Zero MVV:', device.readZeroMVV())
-- end
-- print(msg)
function _M.readZeroMVV()
    local data, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_ZEROMVV)
    if data then
        data = _M.toFloat(data,4)
        return data, nil
    else
        return data, error
    end     
end

-------------------------------------------------------------------------------
-- Command to read MVV span calibration
-- @return MVV signal or nil on error
-- @return error string if error encountered, nil otherwise
-- @usage
-- local ret, msg = device.calibrateSpan(device.editReg('calibwgt')) 
-- if ret == 0 then
--     print('Span Calibration Weight: ', device.readSpanWeight())
--     print('Span MVV: ', device.readSpanMVV())
-- end
-- print(msg)
function _M.readSpanMVV()
    local data, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_SPANMVV)
    if data then
        data = _M.toFloat(data,4)
        return data, nil
    else
         return data, error
    end   
end

-------------------------------------------------------------------------------
-- Command to read span calibration weight
-- @return span weight used on the last span calibration or nil on error
-- @return error string if error encountered, nil otherwise
-- @usage
-- local ret, msg = device.calibrateSpan(device.editReg('calibwgt')) 
-- if ret == 0 then
--     print('Span Calibration Weight: ', device.readSpanWeight())
--     print('Span MVV: ', device.readSpanMVV())
-- end
-- print(msg)
function _M.readSpanWeight()
    local data, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_SPANWGT)
    if data then
        data = _M.toFloat(data)
        return data, nil
    else
        return data, error
    end   
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
-- @usage
-- local ret, msg = device.calibrateLin(pt, device.editReg('calibwgt'))   
-- if ret == 0 then  
--     print('Linearisation Calibration: ', device.readLinCal())
-- end
-- print(msg)
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
-- @return CMD_ constant
-- @return command return string
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

end
