-------------------------------------------------------------------------------
-- Handles the functions for streaming keypresses
-- @module keypresses
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

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
_M.KEY_GN				= 0x000D
_M.KEY_F1				= 0x000E
_M.KEY_F2				= 0x000F
_M.KEY_F3				= 0x0010
_M.KEY_PLUSMINUS		= 0x0011
_M.KEY_DP				= 0x0012
_M.KEY_CANCEL			= 0x0013
_M.KEY_UP				= 0x0014
_M.KEY_DOWN				= 0x0015
_M.KEY_OK				= 0x0016
_M.KEY_SETUP			= 0x0017

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
	[_M.KEY_GN]			= {_M.keyGroup.primary, _M.keyGroup.all},
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
	local callback = nil
	local data = tonumber(data, 16)
	local state = "short"
	local key = bit32.band(data, 0x3F)


	
	if bit32.band(data, 0x80) > 0 then
		state = "long"
	end
	
	if bit32.band(data, 0x40) > 0 then
		state = "up"
	end

	-- Debug  - throw away up and idle events 
	if state == "up" or data == 30 then
	  return
	end  

	
	local groups = _M.keyBinds[key]
	local handled = false
	if groups ~= nil then
   	    if groups.directCallback and groups.directCallback(key, state) == true then
		    handled = true
		end
		if not handled then 	
	      for i=1,#groups do
		   if groups[i].callback and groups[i].callback(key, state) == true then
		       handled = true
			   break
		   end		
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
-- Setup keypresses
-- @param data Data on key streamed
-- @param err Potential error message
function _M.setupKeys()
	_M.send(nil, _M.CMD_EX, _M.REG_FLUSH_KEYS, 0,"noReply")
	_M.send(nil, _M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 1, "noReply")
	_M.keyID = _M.addStream(_M.REG_GET_KEY, _M.keyCallback, 'change')
end

-------------------------------------------------------------------------------
-- Cancel keypress handling
-- @param data Data on key streamed
-- @param err Potential error message
function _M.endKeys(flush)
	if flush then
		_M.send(nil, _M.CMD_EX, _M.REG_FLUSH_KEYS, 0, "noReply")
	end

	_M.send(nil, _M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 0, "noReply")
	
	_M.removeStream(_M.keyID)
end

return _M
