

local _M = {}

------------------------------------------------------------------------------------------------------------ 
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
    local keyGroup = keyGroup or _M.inst.keyGroup.all
    local f = keyGroup.callback
   
   _M.inst.setKeyGroupCallback(keyGroup, _M.getKeyCallback)  

   _M.getKeyState = ''
   while _M.getKeyState == '' do
      _M.system.handleEvents()
    end     
  _M.inst.setKeyGroupCallback(keyGroup, f)
  
  return _M.getKeyPressed, _M.getKeyState  
 
 end

   
-------------------------------------------------------------------------------
-- Called to prompt operator to enter a value
-- @param prompt string displayed on bottom right LCD
-- @param def  default value
-- @typ  type of value to enter ('integer','number','string' 
-- @return value

function _M.edit(prompt, def, typ)

  local bl = _M.inst.curBotLeft
  local br = _M.inst.curBotRight
  
  local editVal = def or ''
  local editType = typ or 'integer'
  
  _M.inst.writeBotRight(prompt)
  _M.inst.writeBotLeft(editVal)

   local editing = true
   local first = true
      
	  
   while editing do
      key, state = _M.getKey(_M.inst.keyGroup.keypad)
	  print(key,state)
      if state == 'short' then
        if key >= _M.inst.KEY_0 and key <= _M.inst.KEY_9 then
           if first then editVal = key else editVal = editVal .. key end
		   first = false
        elseif key == _M.inst.KEY_DP then
           if editType ~= 'integer' then editVal = editVal .. '.' end
        elseif key == _M.inst.KEY_OK then		 
	       editing = false
        elseif key == _M.inst.KEY_CANCEL then		 
	       if #editVal == 0 then
		      editVal = def
			  editing = false
  		   else
             editVal = string.sub(editVal,1,-2)
		   end	
        end		 
    elseif state == 'long' then
     if key == _M.inst.KEY_CANCEL then
	     editVal = def
		 editing = false
        end
    end 
	_M.inst.writeBotLeft(editVal)
  end 
  _M.inst.writeBotRight(br)
  _M.inst.writeBotLeft(bl)
 
 return editVal
end
 
 
 
 
 
    
-------------------------------------------------------------------------------------------------------------
_M.sendRegWaiting = false
_M.sendRegData = ''
_M.sendRegErr = ''

function _M.sendRegCallback(data, err)
     _M.sendRegWaiting = false
	 _M.sendRegData = data
	 _M.sendRegErr = err
end

-------------------------------------------------------------------------------
-- Called to send command and wait for response
-- @param cmd CMD_  command
-- @param reg REG_  register 
-- @param data to send
-- @param t timeout in msec
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
function _M.sendRegWait(cmd, reg, data, t)
   
   local t = t or 500
   
   if reg == nil then
        return nil, 'Nil Register'
	end	
	
   local f = _M.inst.deviceRegisters[reg]
   _M.inst.bindRegister(reg, _M.sendRegCallback)  
   _M.sendRegWaiting = true
   _M.inst.send(nil, cmd, reg, data, "reply")
   _M.system.timers.addTimer(0, t, _M.sendRegCallback, nil, "Timeout")

   while _M.sendRegWaiting do
      _M.system.handleEvents()
     end
   if f then
      _M.inst.bindRegister(reg, _M.handleReply)  
   end
  
   return _M.sendRegData, _M.sendRegErr   
end

-------------------------------------------------------------------------------
-- Called to read register contents
-- @param reg REG_  register 
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
function _M.readRegWait(reg)
    return _M.sendRegWait(_M.inst.CMD_RDFINALDEC,reg)
end

-------------------------------------------------------------------------------
-- Called to request response based on custom transmit token string
-- @param tokenStr  custom token string
function _M.reqCustomTransmit(tokenStr)
    return _M.sendRegWait(_M.inst.CMD_WRFINALHEX, _M.inst.REG_REPLYTOKENSTR, tokenStr, 1000)
end



----------------------------------------------------------------------------------------------------------------
_M.delayWaiting = false
function _M.delayCallback()
  _M.delayWaiting = false
end

-------------------------------------------------------------------------------
-- Called to delay for t msec while keeping event handlers running
-- @param t delay time in msec 
function _M.delay(t)
   _M.system.timers.addTimer(0, t, _M.delayCallback)
   _M.delayWaiting = true
   while _M.delayWaiting do
      _M.system.handleEvents()
    end  
end



----------------------------------------------------------------------------------------------------------------
_M.askOKWaiting = false
_M.askOKResult = 0
function _M.askOKCallback(key, state)
   
   if state ~= 'short' then return false end
   
   if key == _M.inst.KEY_OK then
      _M.askOKWaiting = false
      _M.askOKResult = _M.inst.KEY_OK
   elseif key == _M.inst.KEY_CANCEL then
      _M.askOKWaiting = false
      _M.askOKResult = _M.inst.KEY_CANCEL
   end

   return true   
end

----------------------------------------------------------------------------------------------------------------
-- prompts operator and waits for OK or CANCEL key press
-- @param prompt string to put on bottom right LCD
-- @param q string to put on bottom left LCD
-- @return either KEY_OK or KEY_CANCEL
function _M.askOK(prompt, q)

  local f = _M.inst.keyGroup.keypad.callback
  local bl = _M.inst.curBotLeft
  local br = _M.inst.curBotRight
  local prompt = prompt or ''
  local q = q or ''  
  
  _M.inst.setKeyGroupCallback(_M.inst.keyGroup.keypad, _M.askOKCallback)  

  _M.inst.writeBotRight(prompt)
  _M.inst.writeBotLeft(q)
 
  _M.askOKWaiting = true
  while _M.askOKWaiting do
      _M.system.handleEvents()
    end     
  _M.inst.setKeyGroupCallback(_M.inst.keyGroup.keypad, f)

  
   _M.inst.writeBotRight(br)
   _M.inst.writeBotLeft(bl)
   return _M.askOKResult  
  
end  



----------------------------------------------------------------------------------------------------------------
-- Prompts operator to select from a list of options using arrow keys and KEY_OK
-- @param prompt string to put on bottom right LCD
-- @param options table of option strings
-- @param def default selection string.byte
-- @return selected string  (default selection if KEY_CANCEL pressed)
 
function _M.selectOption(prompt, options, def)

  local bl = _M.inst.curBotLeft
  local br = _M.inst.curBotRight

  local options = options or {}
  local key = 0

  local index = 1
  if def then
    for k,v in ipairs(options) do
      if v == def then
	     index = k
	  end
    end
   end	
   
  local sel = def or ''  
  
  
   _M.inst.writeBotRight(string.upper(prompt))
   _M.inst.writeBotLeft(string.upper(options[index]))

   local editing = true
   while editing do
      key = _M.getKey(_M.inst.keyGroup.cursor)    
      if key == _M.inst.KEY_DOWN then
	        index = index - 1
			if index == 0 then index = #options end
	  elseif key == _M.inst.KEY_UP then
	        index = index + 1
			if index > #options then index = 1 end
	  elseif key == _M.inst.KEY_OK then 
          sel = options[index]
		  editing = false
      elseif key == _M.inst.KEY_CANCEL then
          sel = def
		  editing = false 	  
	  end
     _M.inst.writeBotLeft(string.upper(options[index]))
	  
	end  
	  
  _M.inst.writeBotRight(br)
  _M.inst.writeBotLeft(bl)
 
 return sel
end
 









_M.RTC = {hour = 0, min = 0, sec = 0, day = 1, month = 1, year = 2010}
_M.RTC['first'] = 'day'
_M.RTC['second'] = 'month'
_M.RTC['third'] = 'year'

---------------------------------------------------------------------------------------------------
-- Read Real TIme Clock data from instrument into local RTC table
-- @param d is 'all' for date and time read, 'date' or 'time' to read these fields only
function _M.RTCread(d)
  local d = d or 'all'
   

  local timestr, err = _M.sendRegWait(_M.inst.CMD_RDLIT,_M.inst.REG_TIMECUR)
  if err then timestr = '01/01/2000 00-00' end  
  if d == 'date' or d == 'all' then
      _M.RTC.day, _M.RTC.month, _M.RTC.year = string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
  end
  if d == 'time' or d == 'all' then
      _,_,_, _M.RTC.hour, _M.RTC.min = string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
  end	  
  _M.RTC.sec, err = _M.readRegWait(_M.inst.REG_TIMESEC)
  if err then _M.RTC.sec = 0  end
  
end

-----------------------------------------------------------------------------------------------------------
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

------------------------------------------------------------------------------------------------------------------
-- returns formated date/time string 
function _M.RTCtostring()
  return string.format("%02d/%02d/%02d %02d:%02d:%02d",_M.RTC[_M.RTC.first],_M.RTC[_M.RTC.second],_M.RTC[_M.RTC.third],_M.RTC.hour,_M.RTC.min,_M.RTC.sec)
end

------------------------------------------------------------------------------------------------------------------
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



_M.cmdString = {}
_M.cmdString[0] = 'OK'
_M.cmdString[1] = 'CANCEL'
_M.cmdString[2] = 'IN PROG'
_M.cmdString[3] = 'ERROR'
_M.cmdString[4] = 'OL-UL'
_M.cmdString[5] = 'BUSY'
_M.cmdString[6] = 'MOTION'
_M.cmdString[7] = 'BAND'
_M.cmdString[8] = 'RES'
_M.cmdString[9] = 'COMMAND'
_M.cmdString[10] = 'DUPLIC'
_M.cmdString[11] = 'HI RES'



function _M.zero()
 local msg, err = _M.sendRegWait(_M.inst.CMD_EX,_M.inst.REG_ADC_ZERO,nil,15000)
 print (msg, err)
 
 msg = tonumber(msg)
 return msg, _M.cmdString[msg]
end

function _M.tare()
 
   local msg, err = _M.sendRegWait(_M.inst.CMD_EX,_M.inst.REG_ADC_TARE,nil,15000)
   print (msg, err) 
   if msg then
      msg = tonumber(msg)
      return msg, _M.cmdString[msg]
	else 
      return msg, err
	end  
end

function _M.presetTare(pt)
local pt = pt or 0
  print(_M.sendRegWait(_M.inst.CMD_EX,_M.inst.REG_ADC_PT,pt,5000))
end

function _M.gross()
 print(_M.sendRegWait(_M.inst.CMD_EX,_M.inst.REG_ADC_GROSSNET,nil,1000))
end

function _M.net()
 print(_M.sendRegWait(_M.inst.CMD_EX,_M.inst.REG_ADC_GROSSNET,_M.inst.ADCGN_NET,1000))
end

function _M.grossNetToggle()
 print(_M.sendRegWait(_M.inst.CMD_EX,_M.inst.REG_ADC_GROSSNET,_M.inst.ADCGN_TOGGLE,1000))
end




function _M.connect(inst, system)
   _M.inst = inst
   _M.system = system
end


  

return _M
