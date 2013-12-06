-------------------------------------------------------------------------------
-- Libary for the L401, providing easy functionality for interfacing with
-- all aspects of the device
-- @module rinLibrary.L401
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local bit32 = require "bit"
local dbg = require "rinLibrary.rinDebug"

local con = require "rinLibrary.rinCon"
-- build rest of L401 on top of rinCon
local _M = con  
-- remove information that rinCON is already loaded to facilitate multiple connections
package.loaded["rinLibrary.rinCon"] = nil

-- Registers
--	System
_M.REG_SOFTMODEL		= 0x0003
_M.REG_SOFTVER			= 0x0004
_M.REG_SERIALNO			= 0x0005
_M.REG_KEYBUFFER		= 0x0008
_M.REG_LCD				= 0x0009

_M.REG_SAVESETTING		= 0x0010
_M.REG_FULLPASS			= 0x0019
_M.REG_SAFEPASS			= 0x001A

_M.REG_ADCSAMPLE		= 0x0020
_M.REG_SYSSTATUS		= 0x0021
_M.REG_SYSERR			= 0x0022
_M.REG_ABSMVV			= 0x0023
_M.REG_UNUSED			= 0x0024

_M.SYS_OVERLOAD			= 0x00020000
_M.SYS_UNDERLOAD		= 0x00010000
_M.SYS_ERR				= 0x00008000
_M.SYS_SETUP			= 0x00004000
_M.SYS_CALIBINPROG		= 0x00002000
_M.SYS_MOTION			= 0x00001000
_M.SYS_CENTREOFZERO		= 0x00000800
_M.SYS_ZERO				= 0x00000400
_M.SYS_NET				= 0x00000200

--	Weight
_M.REG_GROSSNET			= 0x0025
_M.REG_GROSS			= 0x0026
_M.REG_NET				= 0x0027
_M.REG_TARE				= 0x0028
_M.REG_PEAKHOLD			= 0x0029

_M.REG_RAWADC			= 0x002D

_M.REG_FULLSCALE		= 0x002F


-- USER VARIABLES
_M.REG_USERID_NAME1		= 0x0080
_M.REG_USERID_NAME2		= 0x0081
_M.REG_USERID_NAME3		= 0x0082
_M.REG_USERID_NAME4		= 0x0083
_M.REG_USERID_NAME5		= 0x0084
_M.REG_USERNUM_NAME1	= 0x0316
_M.REG_USERNUM_NAME2	= 0x0317
_M.REG_USERNUM_NAME3	= 0x0318
_M.REG_USERNUM_NAME4	= 0x0319
_M.REG_USERNUM_NAME5	= 0x031A

_M.REG_USERID1			= 0x0090
_M.REG_USERID2			= 0x0092
_M.REG_USERID3			= 0x0093
_M.REG_USERID4			= 0x0094
_M.REG_USERID5			= 0x0095
_M.REG_USERNUM1			= 0x0310
_M.REG_USERNUM2			= 0x0311
_M.REG_USERNUM3			= 0x0312
_M.REG_USERNUM4			= 0x0313
_M.REG_USERNUM5			= 0x0314

-------------------------------------------------------------------------------
-- General Utilities
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called to connect the L401 library to a socket and a system
-- @param sock TCP socket to connect
-- @param system System that manages L401 (nil if stand-alone library)
function _M.connect(sock, system)
	_M.socket = sock
	_M.system = system
	local ip, port = sock:getpeername()
	dbg.configureDebug(arg[1], true, ip)
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
	   dbg.printVar('getDP: '.. reg .. ' ', err, dbg.ERROR)
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
function _M.saveSetting()
    _M.sendRegWait(_M.CMD_EX,_M.REG_SAVESETTING)
end
-------------------------------------------------------------------------------
-- Called to collect key system data from instrument to configure 
-- the local L401 library
_M.fullscale = 3000
_M.dp = 0 
function _M.configure()
    _M.fullscale, _M.dp = _M.getRegDP(_M.REG_FULLSCALE)
end

-------------------------------------------------------------------------------
-- Called to convert a floating point value to a decimal integer based on then
-- primary instrument weighing settings 
-- @param v is value to convert
-- @return floating point value suitable for a WRFINALDEC
function _M.toPrimary(v)
 
 if type(v) == 'string' then
    v = tonumber(v)
  end	
 for i = 1,_M.dp do
    v = v*10
  end
  v = math.floor(v+0.5)
  return(v)
end
-------------------------------------------------------------------------------
-- called to convert hexadecimal return string to a floating point number
-- @param data returned from _CMD_RDFINALHEX or from stream
-- @param dp decimal position 
-- @return floating point number
function _M.toFloat(data, dp)
   local dp = dp or _M.dp  -- use instrument dp if not specified otherwise
   
   data = tonumber(data,16)
   if data > 0x7FFFFFFF then
	    data = data - 0xFFFFFFFF - 1
	end
	
   for i = dp,1,-1 do
      data = data / 10
   end
   
   return data
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- This section is for functions associated with streaming registers   
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

--	Stream Register Definitions
_M.REG_STREAMDATA		= 0x0040
_M.REG_STREAMMODE		= 0x0041
_M.REG_STREAMREG1		= 0x0042
_M.REG_STREAMREG2		= 0x0043
_M.REG_STREAMREG3		= 0x0044
_M.REG_STREAMREG4		= 0x0045
_M.REG_STREAMREG5		= 0x0046
_M.REG_LUA				= 0x0300	-- Should be bor'd with other stream regs
_M.STM_START			= 1
_M.STM_STOP				= 0

_M.STM_FREQ_MANUAL		= 0
_M.STM_FREQ_AUTO		= 1
_M.STM_FREQ_AUTO10		= 2
_M.STM_FREQ_AUTO3		= 3
_M.STM_FREQ_AUTO1		= 4
_M.STM_FREQ_ONCHANGE	= 5

_M.freq = _M.STM_FREQ_ONCHANGE

_M.availRegisters = {	[_M.REG_STREAMREG1]= {['reg'] = 0, 
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
_M.streamRegisters = {}




-------------------------------------------------------------------------------
-- Divide the data stream up and run the relevant callbacks
-- @param data Data received from register
-- @param err Potential error message
function _M.streamCallback(data, err)
   
	for k,v in pairs(_M.availRegisters) do
		if v.reg ~= 0 then
			local ind = (k - _M.REG_STREAMREG1) * 8
			local substr = string.sub(data,ind+1,ind+8)
			
			if substr and substr ~= "" then			
				if (v.onChange ~= 'change') or (v.lastData ~= substr) then  
                     v.lastData = substr				
				     v.callback(_M.toFloat(substr,v.dp), err)
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
-- return streamReg indentity
function _M.addStream(streamReg, callback, onChange)
	local availReg = nil
	
	_M.bindRegister(bit32.bor(_M.REG_LUA,_M.REG_STREAMDATA), _M.streamCallback)
	
	for k,v in pairs(_M.availRegisters) do
		if v.reg == 0 and (availReg == nil or k < availReg) then
			availReg = k
		end
	end

	if availReg == nil then
		return nil, "no more registers available"
	end
	
	_M.availRegisters[availReg].reg = streamReg
	_M.availRegisters[availReg].callback = callback
	_M.availRegisters[availReg].onChange = onChange
	_M.availRegisters[availReg].lastData = ''
	_,_M.availRegisters[availReg].dp = _M.getRegDP(streamReg)
	
	
	
	_M.streamRegisters[streamReg] = availReg

	_M.send(nil, _M.CMD_WRFINALHEX, 
				bit32.bor(_M.REG_LUA,_M.REG_STREAMMODE), 
				_M.freq, 'noReply')
	_M.send(nil, _M.CMD_WRFINALDEC, 
				bit32.bor(_M.REG_LUA, availReg), 
				streamReg, 'noReply')
	_M.send(nil, _M.CMD_EX, 
				bit32.bor(_M.REG_LUA, _M.REG_STREAMDATA), 
				_M.STM_START, 'noReply')
	
	return streamReg
end

-------------------------------------------------------------------------------
-- Remove a stream from the device 
-- @param streamReg Register to be removed(_M.REG_*)
function _M.removeStream(streamReg)
	local availReg = _M.streamRegisters[streamReg]

	 if availReg == nil then return end   -- stream already removed
	 
	_M.send(nil,_M.CMD_WRFINALDEC,bit32.bor(_M.REG_LUA,availReg),0,'noReply')
	_M.unbindRegister(bit32.bor(_M.REG_LUA, availReg))
	
	_M.availRegisters[availReg].reg = 0
	_M.streamRegisters[streamReg] = nil
end
-------------------------------------------------------------------------------
--  Called to cleanup any unused streaming
function _M.streamCleanup()
	for k,v in pairs(_M.availRegisters) do 
		_M.send(nil, _M.CMD_WRFINALDEC,	bit32.bor(_M.REG_LUA, k), 0, 'noReply')
		v.reg = 0
	end
	_M.streamRegisters = {}
end

-------------------------------------------------------------------------------
--  Set the frequency used for streaming
-- @param freq Frequency of streaming (_M.STM_FREQ_*)
function _M.setStreamFreq(freq)
	local freq = freq or _M.freq
	_M.freq = freq
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- From here onwards all functions are associated with the status monitoring      
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

_M.REG_LUA_STATUS   = 0x0329
_M.REG_LUA_STAT_RTC = 0x032A
_M.REG_LUA_STAT_RDG = 0x032B
_M.REG_LUA_STAT_IO  = 0x032A
_M.REG_IOSTATUS		= 0x0051

_M.lastIOStatus = 0

-- Status
_M.STAT_NET             = 0x00000001
_M.STAT_GROSS   		= 0x00000002
_M.STAT_ZERO			= 0x00000004
_M.STAT_NOTZERO			= 0x00000008
_M.STAT_COZ				= 0x00000010
_M.STAT_NOTCOZ			= 0x00000020
_M.STAT_MOTION			= 0x00000040
_M.STAT_NOTMOTION		= 0x00000080
_M.STAT_RANGE1			= 0x00000100
_M.STAT_RANGE2  		= 0x00000200
_M.STAT_PT				= 0x00000400
_M.STAT_NOTPT			= 0x00000800
_M.STAT_ERROR			= 0x00001000
_M.STAT_ULOAD			= 0x00002000
_M.STAT_OLOAD			= 0x00004000
_M.STAT_NOTERROR		= 0x00008000
_M.STAT_INIT			= 0x01000000
_M.STAT_RTC				= 0x02000000
_M.STAT_RDG				= 0x04000000
_M.STAT_IO			    = 0x08000000
_M.STAT_SER1			= 0x10000000
_M.STAT_SER2			= 0x20000000

_M.statBinds = {}
_M.statID = nil          

-------------------------------------------------------------------------------
-- Called when status changes are streamed 
-- @param data Data on status streamed
-- @param err Potential error message
function _M.statusCallback(data, err)
	    
	for k,v in pairs(_M.statBinds) do
	   local status = bit32.band(data,k)
       if status ~= v.lastStatus  then
	       v.lastStatus = status
		   v.f(k, status ~= 0)
		end		
	end
end

-------------------------------------------------------------------------------
-- Set the callback function for a status bit
-- @param stat given in _M.statBinds
-- @param callback Function to run when there is an event on change in status
function _M.setStatusCallback(stat, callback)
	_M.statBinds[stat] = {}
	_M.statBinds[stat]['f'] = callback
	_M.statBinds[stat]['lastStatus'] = 0xFF
	if stat == _M.STAT_RTC then  
	    _M.setRTCStatus(true)
	end
end

-------------------------------------------------------------------------------
-- Setup status monitoring via a stream
function _M.setupStatus()
	_M.statID = _M.addStream(_M.REG_LUA_STATUS, _M.statusCallback, 'change')
end

-------------------------------------------------------------------------------
-- Control the use of RTC status bit
-- @param s true to enable RTC change monitoring, false to disable
function _M.setRTCStatus(s)
   local s = s or true
   if s then s = 1 else s = 0 end
   _M.send(nil,_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_RTC,s, "noReply") 
end

-------------------------------------------------------------------------------
-- Control the use of reading count status bit.  This is useful if weight 
-- readings are not collected via an on change stream register directly
-- @param num Sets amount of readings to trigger a reading count status change
function _M.setRDGStatus(num)
    local num = num or 0
	if num > 255 then num = 255 end
	_M.send(nil,_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_RDG,num, "noReply")
end

-------------------------------------------------------------------------------
-- private function
function _M.setIOStatus(mask)
    local mask = mask or 0
	_M.send(nil,_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_IO,mask, "noReply")
end

-------------------------------------------------------------------------------
-- sets IO status IO bit to recognise this IO 
-- @param IO is output 1..32
function _M.enableIOStatus(IO)
	local curIOStatus =  bit32.bor(_M.lastIOStatus, 
									bit32.lshift(0x0001,(IO-1)))
	if (curIOStatus ~= _M.lastIOStatus) then
		_M.setIOStatus(curIOStatus)
		_M.lastIOStatus = curIOStatus
	end  
    
end

-------------------------------------------------------------------------------
-- sets IO status IO bit to ignore this IO 
-- @param IO is output 1..32
function _M.releaseIOStatus(IO)
	local curIOStatus =  bit32.band(_M.lastIOStatus,
									bit32.bnot(bit32.lshift(0x0001,(IO-1))))
	if (curIOStatus ~= _M.lastIOStatus) then
		_M.setIOStatus(curIOStatus)
		_M.lastIOStatus = curIOStatus
	end 
end

-------------------------------------------------------------------------------
-- Cancel status handling
function _M.endStatus()
	_M.removeStream(_M.statID)
end
   
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- From here onwards all functions are associated with the key presses      
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

_M.firstKey = true    -- flag to catch any garbage
-- Keys
_M.KEY_0				= 0x0000
_M.KEY_1				= 0x0001
_M.KEY_2				= 0x0002
_M.KEY_3				= 0x0003
_M.KEY_4				= 0x0004
_M.KEY_5				= 0x0005
_M.KEY_6				= 0x0006
_M.KEY_7				= 0x0007
_M.KEY_8				= 0x0008
_M.KEY_9				= 0x0009
_M.KEY_POWER			= 0x000A
_M.KEY_ZERO				= 0x000B
_M.KEY_TARE				= 0x000C
_M.KEY_SEL				= 0x000D
_M.KEY_F1				= 0x000E
_M.KEY_F2				= 0x000F
_M.KEY_F3				= 0x0010
_M.KEY_PLUSMINUS		= 0x0011
_M.KEY_DP				= 0x0012
_M.KEY_CANCEL			= 0x0013
_M.KEY_UP				= 0x0014
_M.KEY_DOWN				= 0x0015
_M.KEY_OK				= 0x0016
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
_M.REG_GET_KEY			= 0x0321
_M.REG_FLUSH_KEYS		= 0x0322
_M.REG_APP_DO_KEYS		= 0x0324
_M.REG_APP_KEY_HANDLER	= 0x0325  

_M.keyID = nil

_M.keyGroup = {}

_M.keyGroup.all			= {callback = nil}
_M.keyGroup.primary		= {callback = nil}
_M.keyGroup.functions	= {callback = nil}
_M.keyGroup.keypad 		= {callback = nil}
_M.keyGroup.numpad		= {callback = nil}
_M.keyGroup.cursor		= {callback = nil}

_M.keyBinds = {
	[_M.KEY_0]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_1]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_2]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_3]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_4]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_5]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_6]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_7]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_8]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_9]			= {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_POWER]		= {_M.keyGroup.primary, _M.keyGroup.all},
	[_M.KEY_ZERO]		= {_M.keyGroup.primary, _M.keyGroup.all},
	[_M.KEY_TARE]		= {_M.keyGroup.primary, _M.keyGroup.all},
	[_M.KEY_SEL]		= {_M.keyGroup.primary, _M.keyGroup.all},
	[_M.KEY_F1]			= {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
	[_M.KEY_F2]			= {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
	[_M.KEY_F3]			= {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
	[_M.KEY_PLUSMINUS]	= {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_DP]			= {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_CANCEL]		= {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_UP]			= {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_DOWN]		= {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_OK]			= {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
	[_M.KEY_SETUP]		= {_M.keyGroup.primary, _M.keyGroup.all}

}

-------------------------------------------------------------------------------
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
	
	local groups = _M.keyBinds[key]
	local handled = false
	if groups ~= nil then
		for i=1,#groups do
				if groups[i].callback and 
						groups[i].callback(key, state) == true then
					handled = true
				   	break
			   	end		
		end
		
		if not handled then 
		  if groups.directCallback and 
   	    		groups.directCallback(key, state) == true then
			handled = true
		  end
		end  

	end
	
	if not handled then
		_M.send(nil, _M.CMD_WRFINALDEC,_M.REG_APP_DO_KEYS, data, "noReply")
	end
end

-------------------------------------------------------------------------------
-- Set the callback function for an existing key
-- @param key A key given in _M.keyBinds
-- @param callback Function to run when there is an event on the keygroup
function _M.setKeyCallback(key, callback)
	_M.keyBinds[key].directCallback = callback
end

-------------------------------------------------------------------------------
-- Set the callback function for an existing key group
-- @param keyGroup A keygroup given in _M.keyGroup.*
-- @param callback Function to run when there is an event on the keygroup
function _M.setKeyGroupCallback(keyGroup, callback)
	keyGroup.callback = callback
end

-------------------------------------------------------------------------------
-- Setup key handling stream
function _M.setupKeys()
	_M.send(nil, _M.CMD_EX, _M.REG_FLUSH_KEYS, 0,"noReply")
	_M.send(nil, _M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 1, "noReply")
	_M.keyID = _M.addStream(_M.REG_GET_KEY, _M.keyCallback, 'change')
end

-------------------------------------------------------------------------------
-- Cancel keypress handling
-- @param flush Flush the current keypresses that have not yet been handled
function _M.endKeys(flush)
	if flush then
		_M.send(nil, _M.CMD_EX, _M.REG_FLUSH_KEYS, 0, "noReply")
	end

	_M.send(nil, _M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 0, "noReply")
	
	_M.removeStream(_M.keyID)
end

-------------------------------------------------------------------------------
-- LCD Services
-------------------------------------------------------------------------------
--LCD display registers
_M.REG_DISP_LAYOUT          = 0x000D    -- execute register to change display mode
_M.REG_DISP_BOTTOM_LEFT     = 0x000E    -- Takes string
_M.REG_DISP_BOTTOM_RIGHT    = 0x000F    -- Takes string
_M.REG_DISP_TOP_LEFT        = 0x00A0    -- Takes string
_M.REG_DISP_TOP_RIGHT       = 0x00A1    -- Takes string
_M.REG_DISP_TOP_ANNUN       = 0x00A2
_M.REG_DISP_TOP_UNITS       = 0x00A3    -- Takes string
_M.REG_DISP_BOTTOM_ANNUN    = 0x00A4
_M.REG_DISP_BOTTOM_UNITS    = 0x00A5

_M.REG_DISP_AUTO_TOP_ANNUN  = 0x00A6    -- Register number  REG_*
_M.REG_DISP_AUTO_TOP_LEFT   = 0x00A7    -- Register number  REG_*
_M.REG_DISP_AUTO_BOTTOM_LEFT= 0x00A8    -- Register number  REG_*

_M.REG_BUZ_LEN      = 0x0327
_M.REG_BUZ_NUM      = 0x0328

_M.botAnnunState = 0
_M.topAnnunState = 0
_M.waitPos = _M.WAIT

_M.curBotLeft = ''
_M.curBotRight = ''

-------------------------------------------------------------------------------
-- Write string to Bottom Left of LCD, curBotLeft is set to s
-- @param s string to display
function _M.writeBotLeft(s)
	if s then
		_M.send(nil,_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_LEFT,  s, "noReply")
		_M.curBotLeft = s
	end	 
end

-------------------------------------------------------------------------------
-- Write string to Bottom Right of LCD, curBotRight is set to s
-- @param s string to display
function _M.writeBotRight(s)
	if s then
		_M.send(nil, _M.CMD_WRFINALHEX, _M.REG_DISP_BOTTOM_RIGHT, s, "noReply")
		_M.curBotRight = s
	end	  
end   

_M.writeBotAnnuns 	= _M.preconfigureMsg(_M.REG_DISP_BOTTOM_ANNUN,
										 _M.CMD_WRFINALHEX,
										 "noReply")										 
_M.writeBotUnits  	= _M.preconfigureMsg(_M.REG_DISP_BOTTOM_UNITS, 
										 _M.CMD_WRFINALHEX, 
										 "noReply")
_M.writeTopLeft  	= _M.preconfigureMsg(_M.REG_DISP_TOP_LEFT,
										 _M.CMD_WRFINALHEX,
										 "noReply")										 
_M.writeTopRight  	= _M.preconfigureMsg(_M.REG_DISP_TOP_RIGHT,
										 _M.CMD_WRFINALHEX,
										 "noReply")										 
_M.writeTopAnnuns 	= _M.preconfigureMsg(_M.REG_DISP_TOP_ANNUN,
										 _M.CMD_WRFINALHEX,
										 "noReply")										 
_M.writeTopUnits  	= _M.preconfigureMsg(_M.REG_DISP_TOP_UNITS,
										 _M.CMD_WRFINALHEX,
										 "noReply")
  
_M.setAutoTopAnnun  = _M.preconfigureMsg(_M.REG_DISP_AUTO_TOP_ANNUN,
										 _M.CMD_WRFINALHEX,
										 "noReply")
_M.setAutoTopLeft   = _M.preconfigureMsg(_M.REG_DISP_AUTO_TOP_LEFT,
										 _M.CMD_WRFINALHEX,
										 "noReply")
_M.setAutoBotLeft   = _M.preconfigureMsg(_M.REG_DISP_AUTO_BOTTOM_LEFT,
										 _M.CMD_WRFINALHEX,
										 "noReply")


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

-- REG_DISP_TOP_ANNUN BIT SETTINGS
_M.SIGMA		= 0x00001
_M.BALANCE		= 0x00002
_M.COZ			= 0x00004
_M.HOLD			= 0x00008
_M.MOTION		= 0x00010
_M.NET			= 0x00020
_M.RANGE		= 0x00040
_M.ZERO			= 0x00080
_M.BAL_SEGA		= 0x00100
_M.BAL_SEGB		= 0x00200
_M.BAL_SEGC		= 0x00400
_M.BAL_SEGD		= 0x00800
_M.BAL_SEGE		= 0x01000
_M.BAL_SEGF		= 0x02000
_M.BAL_SEGG		= 0x04000
_M.RANGE_SEGADG	= 0x08000
_M.RANGE_SEGC   = 0x10000
_M.RANGE_SEGE	= 0x20000

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

-------------------------------------------------------------------------------
-- Called to restore the LCD to its default state
function _M.restoreLcd()
   _M.setAutoTopAnnun(0)
   _M.setAutoTopLeft(_M.REG_GROSSNET)
   _M.setAutoBotLeft(0)
   _M.writeTopRight('')
   _M.writeBotLeft('')
   _M.writeBotRight('')
   _M.writeBotAnnuns(0)
end

-------------------------------------------------------------------------------
--  Routines for Analogue Output control
-------------------------------------------------------------------------------
_M.REG_ANALOGUE_DATA = 0x0323
_M.REG_ANALOGUE_TYPE = 0xA801
_M.REG_ANALOGUE_CLIP = 0xA806
  
_M.CUR = 0
_M.VOLT = 1

_M.curAnalogType = _M.CUR 
 
_M.writeAnalogRaw   = _M.preconfigureMsg(_M.REG_ANALOGUE_DATA, 
										 _M.CMD_WRFINALDEC, 
										 "noReply")
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
   		_M.send(nil,
   				_M.CMD_WRFINALDEC,
				_M.REG_ANALOGUE_TYPE,
				_M.curAnalogType,
				"noReply") 
   	end
end   

_M.setAnalogClip = _M.preconfigureMsg(	_M.REG_ANALOGUE_CLIP, 
										_M.CMD_WRFINALDEC, "noReply")
  
-------------------------------------------------------------------------------
-- Sets the analogue output to minimum 0.0 through to maximum 1.0
-- @param val value 0.0 to 1.0
function _M.setAnalogVal(val)
   _M.writeAnalogRaw(math.floor((50000*val)+0.5))
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
  val = (val - 4)/20
 _M.setAnalogVal(val)
end

-------------------------------------------------------------------------------
--  Routines for Setpoint Output control
-------------------------------------------------------------------------------

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
_M.REG_SETP_TARGET  = 0xA408
_M.REG_SETP_HYS     = 0xA409

_M.LOGIC_HIGH = 0
_M.LOGIC_LOW = 1

_M.ALARM_NONE = 0
_M.ALARM_SINGLE = 1
_M.ALARM_DOUBLE = 2
_M.ALARM_FLASH = 3

_M.GROSS = 0
_M.NET = 1
_M.DISP = 2
_M.ALT_GROSS = 3
_M.ALT_NET = 4
_M.ALT_DISP = 5
_M.PIECE = 6
_M.REG = 7

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
-- Sets IO Output under LUA control
-- @param IO is input 1..32
function _M.enableOutput(IO)
   local curIOEnable =  bit32.bor(_M.lastIOEnable, bit32.lshift(0x0001,(IO-1)))
   if (curIOEnable ~= _M.lastIOEnable) then
      _M.setOutputEnable(curIOEnable)
      _M.lastIOEnable = curIOEnable
    end  
    
end

-------------------------------------------------------------------------------
-- Sets IO Output under instrument control
-- @param IO is output 1..32
function _M.releaseOutput(IO)
	local curIOEnable =  bit32.band(_M.lastIOEnable, 
						 		bit32.bnot(bit32.lshift(0x0001,(IO-1))))
	if (curIOEnable ~= _M.lastIOEnable) then
		_M.setOutputEnable(curIOEnable)
		_M.lastIOEnable = curIOEnable
	end 
end

--------------------------------------------------------------------------------
-- Private function
function _M.setpParam(setp,reg,v)
	_M.send(nil, _M.CMD_WRFINALDEC, reg+((setp-1)*_M.REG_SETP_REPEAT), v, "noReply")
end

--------------------------------------------------------------------------------
-- returns actual register address for a particular setpoint parameter
-- @param setp is setpoint 1..16
-- @param reg is REG_SETP_*
-- @return address of this registet for setpoint setp
function _M.setpRegAddress(setp,reg)
  return (reg+((setp-1)*_M.REG_SETP_REPEAT)) 
end
-------------------------------------------------------------------------------
-- Set Target for setpoint
-- @param setp Setpoint 1..16
-- @param target Target value
function _M.setpTarget(setp,target)
    _M.setpParam(setp,_M.REG_SETP_TARGET, _M.toPrimary(target))
	_M.saveSetting()
end

-------------------------------------------------------------------------------
-- Set which Output the setpoint controls
-- @param setp is setpount 1..16
-- @param IO is output 1..32, 0 for none
function _M.setpIO(setp, IO)
	_M.setpParam(setp,_M.REG_SETP_OUTPUT, IO)
end

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
-- @param v is setpoint logic type
function _M.setpLogic(setp, v)
  _M.setpParam(setp,_M.REG_SETP_LOGIC, v)
 
end

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
-- @param v is setpoint name
function _M.setpName(setp, v)
  _M.setpParam(setp,_M.REG_SETP_NAME, v)
end

-------------------------------------------------------------------------------
-- Set the data source of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint source type
function _M.setpSource(setp, v)
  _M.setpParam(setp,_M.REG_SETP_SOURCE, v)
end

-------------------------------------------------------------------------------
-- Set the Hysteresis for of the setpoint controls
-- @param setp is setpount 1..16
-- @param v is setpoint hysteresis
function _M.setpHys(setp, v)
  _M.setpParam(setp,_M.REG_SETP_HYS, _M.toPrimary(v))
end

-------------------------------------------------------------------------------
-- Set the number of Setpoints 
-- @param n is the number of setpoints 0..16
function _M.setNumSetp(n)
  _M.send(nil,_M.CMD_WRFINALDEC,_M.REG_SETP_NUM,n, "noReply")
end

-------------------------------------------------------------------------------
--Direct Buzzer Control
-------------------------------------------------------------------------------

-- The lengths of beeps, takes 0 (short), 1(med) or 2(long). 
-- There are no gaps between long beeps
_M.REG_BUZZ_LEN =  0x0327
-- takes 1 – 4, will clear to 0 once beeps have been executed
_M.REG_BUZZ_NUM =  0x0328        

_M.BUZZ_SHORT = 0
_M.BUZZ_MEDIUM = 1
_M.BUZZ_LONG = 2

-------------------------------------------------------------------------------
-- Called to set the length of the buzzer sound
-- @param len - length of buzzer sound (BUZZ_SHORT, BUZZ_MEDIUM, BUZZ_LONG)
function _M.setBuzzLen(len)

   local len = len or _M.BUZZ_SHORT
   if len > _M.BUZZ_LONG then len = _M.BUZZ_LONG end
   
   _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_BUZZ_LEN, len, "noReply")

end
-------------------------------------------------------------------------------
-- Called to trigger instrument buzzer
-- @param times  - number of times to buzz, 1..4
function _M.buzz(times)
    local times = times or 1
	times = tonumber(times)
	if times > 4 then 
		times = 4 
	end

    _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_BUZZ_NUM, times, "noReply")
end

-------------------------------------------------------------------------------
--  Routines for Dialog control
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
	while _M.getKeyState == '' do
		_M.system.handleEvents()
	end	  
	_M.setKeyGroupCallback(keyGroup, f)
  
	return _M.getKeyPressed, _M.getKeyState  
 
 end
	
-------------------------------------------------------------------------------
-- Called to prompt operator to enter a value
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param typ type of value to enter ('integer','number','string' 
-- @return value and true if ok pressed at end
function _M.edit(prompt, def, typ)

	local key, state

	local bl = _M.curBotLeft
	local br = _M.curBotRight
    local def = def or ''
	if type(def) ~= 'string' then
	     def = tostring(def)
	 end	 
	
	local editVal = def 
	local editType = typ or 'integer'
    
	_M.writeBotRight(prompt)
	_M.writeBotLeft(editVal)

	local editing = true
	local first = true
	
		
	local ok = false  
	while editing do
		key, state = _M.getKey(_M.keyGroup.keypad)
    	if state == 'short' then
			if key >= _M.KEY_0 and key <= _M.KEY_9 then
				if first then 
					editVal = key 
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
				editing = false
				ok = true
			elseif key == _M.KEY_CANCEL then	
    			if string.len(editVal) == 0 then
					editVal = def
					editing = false
				else
					editVal = string.sub(editVal,1,-2)
				end	
			end		 
		elseif state == 'long' then
			if key == _M.KEY_CANCEL then
				editVal = def
				editing = false
			end
		end 
		_M.writeBotLeft(editVal..' ')
	end 
	_M.writeBotRight(br)
	_M.writeBotLeft(bl)
 
	return editVal, ok
end




 
_M.sendRegWaiting = false
_M.sendRegData = ''
_M.sendRegErr = ''

-------------------------------------------------------------------------------
-- Private function
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
	
	local f = _M.deviceRegisters[reg]
	_M.bindRegister(reg, _M.sendRegCallback)  
	_M.sendRegWaiting = true
	_M.send(nil, cmd, reg, data, "reply")
	local tmr = _M.system.timers.addTimer(0, t, _M.sendRegCallback, nil, "Timeout")

	while _M.sendRegWaiting do
		_M.system.handleEvents()
	end
	
	if f then
		_M.bindRegister(reg, _M.handleReply)  
	end
    
    _M.system.timers.removeTimer(tmr)	
	return _M.sendRegData, _M.sendRegErr	
end

-------------------------------------------------------------------------------
-- Called to read register contents
-- @param reg REG_  register 
-- @return data received from instrument, nil if error
-- @return err error string if error received, nil otherwise
function _M.readRegWait(reg)
	local data, err
	
	data, err = _M.sendRegWait(_M.CMD_RDLIT,reg)
	if err then
	   dbg.printVar('Read Error', err, dbg.DEBUG)
	   return nil, err
	else
	  local a,b = string.find(data,'[+-]?%s*%d*%.?%d*')
      if not a then
           return data, nil
	  else
	   data = string.gsub(string.sub(data,a,b),'%s','')  -- remove spaces
	   return tonumber(data),nil	
	  end	
	end
end

_M.REG_EDIT_REG = 0x0320
-------------------------------------------------------------------------------
--  Called to edit value of specified register
-- @param reg is register to edit
function _M.editRegister(reg)
   _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 0)
   _M.sendRegWait(_M.CMD_WRFINALDEC,_M.REG_EDIT_REG,reg)
   while true do 
     local data,err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.REG_EDIT_REG)
	 
	 if data and tonumber(data,16) ~= reg then 
	   break
	 end
     _M.delay(50)
   end
   _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 1)
   
end



_M.delayWaiting = false
-------------------------------------------------------------------------------
-- Private function
function _M.delayCallback()
	_M.delayWaiting = false
end

-------------------------------------------------------------------------------
-- Called to delay for t msec while keeping event handlers running
-- @param t delay time in msec 
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
	
	if state ~= 'short' then return false end
	
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
-- @return either KEY_OK or KEY_CANCEL
function _M.askOK(prompt, q)

	local f = _M.keyGroup.keypad.callback
	local bl = _M.curBotLeft
	local br = _M.curBotRight
	local prompt = prompt or ''
	local q = q or ''  
  
	_M.setKeyGroupCallback(_M.keyGroup.keypad, _M.askOKCallback)  

	_M.writeBotRight(prompt)
	_M.writeBotLeft(q)
 
	_M.askOKWaiting = true
	while _M.askOKWaiting do
		_M.system.handleEvents()
	end	  
	_M.setKeyGroupCallback(_M.keyGroup.keypad, f)

	_M.writeBotRight(br)
	_M.writeBotLeft(bl)
	return _M.askOKResult  
  
end  

-------------------------------------------------------------------------------
-- Prompts operator to select from a list of options using 
-- arrow keys and KEY_OK
-- @param prompt string to put on bottom right LCD
-- @param options table of option strings
-- @param def default selection string.byte
-- @param loop If true, top option loops to the bottom option and vice versa
-- @return selected string  (default selection if KEY_CANCEL pressed)
function _M.selectOption(prompt, options, def, loop)
	loop = loop or false

	local bl = _M.curBotLeft
	local br = _M.curBotRight

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

	_M.writeBotRight(string.upper(prompt))
	_M.writeBotLeft(string.upper(options[index]))

	local editing = true
	while editing do
		key = _M.getKey(_M.keyGroup.cursor)	 
		if key == _M.KEY_DOWN then
			index = index - 1
			if index == 0 and loop then index = #options end
		elseif key == _M.KEY_UP then
			index = index + 1
			if index > #options and loop then index = 1 end
		elseif key == _M.KEY_OK then 
			sel = options[index]
			editing = false
		elseif key == _M.KEY_CANCEL then
			 sel = def
		  editing = false 	  
	  end
	  _M.writeBotLeft(string.upper(options[index]))
	  
	end  
	  
	_M.writeBotRight(br)
	_M.writeBotLeft(bl)
 
	return sel
end


-- Custom Print Strings

_M.REG_PRINTPORT		= 0x0317
_M.REG_PRINTTOKENSTR	= 0x004C
_M.REG_REPLYTOKENSTR	= 0x004D

_M.PRINT_SER1A          = 0
_M.PRINT_SER1B          = 1
_M.PRINT_SER2A          = 2
_M.PRINT_SER2B          = 3
_M.REG_PRINTPORT		= 0x0317
_M.curPrintPort         = 0xFF

-------------------------------------------------------------------------------
-- Send custom print token string to instrument comms port
-- @param tokenStr  string containing custom print tokens
-- @param comPort - port to use PRINT_SER1A (default) .. PRINT_SER2B
function _M.printCustomTransmit(tokenStr, comPort)
    local comPort = comPort or _M.PRINT_SER1A
	if comPort ~= _M.curPrintPort  then
	    _M.curPrintPort = comPort
		_M.send(nil,_M.CMD_WRFINALHEX, _M.REG_PRINTPORT, comPort, 'noReply')
		_M.send(nil,_M.CMD_EX, _M.REG_SAVESETTING,0)
	end	
    _M.send(nil,_M.CMD_WRFINALHEX, _M.REG_PRINTTOKENSTR, tokenStr, 'noReply')
end


-------------------------------------------------------------------------------
-- Called to request response based on custom transmit token string
-- @param tokenStr  custom token string
function _M.reqCustomTransmit(tokenStr)
	return _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_REPLYTOKENSTR, tokenStr, 1000)
end
-------------------------------------------------------------------------------
-- RTC  Routines
-------------------------------------------------------------------------------
-- 	Time and Date
_M.REG_TIMECUR			= 0x0150
_M.REG_TIMEFORMAT		= 0x0151
_M.REG_TIMEDAY			= 0x0152
_M.REG_TIMEMON			= 0x0153
_M.REG_TIMEYEAR			= 0x0154
_M.REG_TIMEHOUR			= 0x0155
_M.REG_TIMEMIN			= 0x0156
_M.REG_TIMESEC			= 0x0157
_M.TM_DDMMYY			= 0
_M.TM_DDMMYYYY			= 1
_M.TM_MMDDYY			= 2
_M.TM_MMDDYYYY			= 3
_M.TM_YYMMDD			= 4
_M.TM_YYYYMMDD			= 5


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
    
  _M.RTC.sec, err = _M.readRegWait(_M.REG_TIMESEC)
  
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
--  TODO:  Finalise these commands to return proper error messages etc
-------------------------------------------------------------------------------
_M.REG_ADC_ZERO         = 0x0300                  -- Execute registers
_M.REG_ADC_TARE         = 0x0301                  
_M.REG_ADC_PT           = 0x0302                  -- Tare value is parameter 
_M.REG_ADC_GROSS_NET    = 0x0303                 

_M.ADCGN_TOGGLE			= 0
_M.ADCGN_GROSS			= 1
_M.ADCGN_NET			= 2

_M.REG_ADC_HI_RES       = 0x0304                   
_M.ADCHIRES_TOGGLE		= 0
_M.ADCHIRES_ON			= 1
_M.ADCHIRES_OFF			= 2
_M.ADCHIRES_DB			= 3                       -- R420 database setting

-- 	Calibrate
_M.REG_CALIBWGT			= 0x0100
_M.REG_CALIBZERO		= 0x0102
_M.REG_CALIBSPAN		= 0x0103
_M.REG_CALIBLIN			= 0x0104
_M.REG_CLRLIN			= 0x0105
_M.REG_CALIBDIRZERO 	= 0x0106
_M.REG_CALIBDIRSPAN		= 0x0107




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

-------------------------------------------------------------------------------
-- <<COMMENT>>
function _M.zero()
	local msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_ZERO,nil,15000)
 
	msg = tonumber(msg)
	return msg, _M.cmdString[msg]
end

-------------------------------------------------------------------------------
-- <<COMMENT>>
function _M.tare()
 
	local msg, err = _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_TARE,nil,15000)
	if msg then
		msg = tonumber(msg)
		return msg, _M.cmdString[msg]
	else 
		return msg, err
	end  
end

-------------------------------------------------------------------------------
-- <<COMMENT>>
function _M.presetTare(pt)
	local pt = pt or 0
	return _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_PT,pt,5000)
end

-------------------------------------------------------------------------------
-- <<COMMENT>>
function _M.gross()
	return _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_GROSSNET,nil,1000)
end

-------------------------------------------------------------------------------
-- <<COMMENT>>
function _M.net()
	return _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_GROSSNET,_M.ADCGN_NET,1000)
end

-------------------------------------------------------------------------------
-- <<COMMENT>>
function _M.grossNetToggle()
	return _M.sendRegWait(_M.CMD_EX,_M.REG_ADC_GROSSNET,_M.ADCGN_TOGGLE,1000)
end




return _M