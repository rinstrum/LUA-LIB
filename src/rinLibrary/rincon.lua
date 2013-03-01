-------------------------------------------------------------------------------
-- Creates a connection to the M4223 using rinlib
-- @module rincon
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local socket = require "socket"
local bit32 = require "bit"

local str = string
local table = table
local assert = assert
local tonum = tonumber
local pairs = pairs
local type = type

local rinlib = require "rinLibrary.rinlib"

local _M = rinlib	--rincon is built on rinlib
_M.socket = nil

-------------------------------------------------------------------------------
-- Connects to the R400
-- @param ip String containing IP address
-- @param port Port the device is listening on
-- @param timeout Timeout for blocking coomands
-- @return the connection (not necessary for use)
function _M.connectDevice(ip, port, timeout)
	if _M.socket then 
		return _M.socket
	end
	
	_M.socket = assert(socket.tcp())
	assert(_M.socket:connect(ip, port))
	_M.socket = _M.socket
	
	if timeout then
		_M.socket:settimeout(timeout/1000)
	end
	
	return _M.socket
end

-------------------------------------------------------------------------------
-- Disconnect from the R400
function _M.disconnect()
	_M.socket:close()
	_M.socket = nil
end


-------------------------------------------------------------------------------
-- Sends a raw message
function _M.sendRaw(raw)
	_M.socket:send(raw)
end

-------------------------------------------------------------------------------
-- Sends a custom message with CRC
function _M.sendCustom(msg)
	_M.socket:send(table.concat({'', 
								msg, 
								str.format("%04X", rinlib.CCITT(msg)), 
								''}))
end

-------------------------------------------------------------------------------
-- Sends a structured message with CRC
-- @param ind Indicator address (0x00 to 0x1F)
-- @param addr addr name (ADDR_*)
-- @param cmd Command (CMD_*)
-- @param reg Register (REG_*)
-- @param data Data to be sent
function _M.sendStructured(ind, addr, cmd, reg, data)
	_M.sendCustom((str.format("%02X%02X%04X:%s", 
					bit32.bor(ind, addr), 
					cmd, 
					reg, 
					data)))
end

-------------------------------------------------------------------------------
-- Reads a single message from the R400
-- @return message (nil if error)
-- @return error (nil if no error)
function _M.getRaw()
	return rinlib.recMsg(_M.socket)
end

-------------------------------------------------------------------------------
-- Reads a processed message from the R400
-- @return Indicator address (0x00 to 0x1F)
-- @return addr name (ADDR_*)
-- @return command	(CMD_*)
-- @return register	(REG_*)
-- @return data
-- @return error
function _M.getProcessed()
	return rinlib.processMsg(rinlib.recMsg(_M.socket))
end

-------------------------------------------------------------------------------
-- Send a structured message and wait for a reply
-- @param ind Indicator address (0x00 to 0x1F)
-- @param addr addr name (ADDR_*)
-- @param cmd command	(CMD_*)
-- @param reg register	(REG_*)
-- @param data data
function _M.sendRecieve(ind, addr, cmd, reg, data)
	local ind = ind or _M.ADDR_BROADCAST
	local addr = addr or _M.ADDR_REPLY
	local cmd = cmd or _M.CMD_RDFINALHEX
	local data = data or ""
	
	_M.sendStructured(ind, addr, cmd, reg, data)
	local repInd, repAddr, repCmd, repReg, repData, err = _M.getProcessed()
	
	if err or repCmd ~= cmd and repReg ~= reg then	
		return nil, err
	end
	
	return repData
end

-------------------------------------------------------------------------------
-- Send a structured message
-- @param ind Indicator address (0x00 to 0x1F)
-- @param addr addr name (ADDR_*)
-- @param cmd command	(CMD_*)
-- @param reg register	(REG_*)
-- @param data data
function _M.send(ind, addr, cmd, reg, data)
	local ind = ind or _M.ADDR_BROADCAST
	local addr = addr or _M.ADDR_REPLY
	local cmd = cmd or _M.CMD_RDFINALHEX
	local data = data or ""

	_M.sendStructured(ind, addr, cmd, reg, data)
end

-------------------------------------------------------------------------------
-- Return a function allowing for repeatable commands
-- @param reg register	(REG_*)
-- @param cmd command	(CMD_*)
-- @return error
function _M.preconfigureMsg(reg, cmd)
	return function (data) _M.send(nil, nil, cmd, reg, data) end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- This section is for functions associated with binding registers    
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

_M.deviceRegisters = {}
_M.errHandler = nil

-------------------------------------------------------------------------------
-- Set up a callback for when data on a specific register is received
-- @param reg Register to give callback, (_M.REG_*)
-- @param callback Function to be run when data is received
function _M.bindRegister(reg, callback)
	_M.deviceRegisters[reg] = callback
end

-------------------------------------------------------------------------------
-- Unbind a register
-- @param reg Register to remove callback, (_M.REG_*)
function _M.unbindRegister(reg)
	_M.deviceRegisters[reg] = nil
end

-------------------------------------------------------------------------------
-- Handles errors that are not register related (e.g. bad CRC, bad delimiters)
-- @param errHandler Function for handling errors, should take one argument.
function _M.setErrHandler(errHandler)
	_M.errHandler = errHandler
end

-------------------------------------------------------------------------------
-- Removes the error handler
function _M.removeErrHandler()
	_M.errHandler = nil
end

-------------------------------------------------------------------------------
-- Designed to be called from rinFramework. If a message error occurs, pass it
-- to the error handler.
-- @param devCon socket connection to the Rinstrum device
function _M.frameworkCallback(socket)
	local ind, addr, cmd, reg, data, err = _M.getProcessed()
	
	if err and err ~= "device returned error" and _M.addErrHandler then
		_M.errHandler(err)
		return
	end
	
	if _M.deviceRegisters[reg] then
		_M.deviceRegisters[reg](data, err)
	end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- This section is for functions associated with streaming registers   
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

_M.availRegisters = {	[_M.REG_STREAMREG1]=false, 
						[_M.REG_STREAMREG2]=false, 
						[_M.REG_STREAMREG3]=false, 
						[_M.REG_STREAMREG4]=false, 
						[_M.REG_STREAMREG5]=false}
_M.streamRegisters = {}

-------------------------------------------------------------------------------
-- Divide the data stream up and run the relevant callbacks
-- @param data Data received from register
-- @param err Potential error message
function _M.streamCallback(data, err)
	for k,v in pairs(_M.availRegisters) do
		if v ~= false then
			local ind = (k - _M.REG_STREAMREG1) * 8
			local substr = str.sub(data,ind+1,ind+8)
			
			if substr and substr ~= "" then			
				v[2](substr, err)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Add a stream to the device (must be connected)
-- @param streamReg Register to stream from (_M.REG_*)
-- @param frequency Frequency of streaming (_M.STM_FREQ_*)
-- @param callback Function to bind to streaming register
-- return An identifier for the stream used to cancel it
function _M.addStream(streamReg, frequency, callback)
	local availReg = nil
	
	_M.bindRegister(bit32.bor(_M.REG_LUA, _M.REG_STREAMDATA), _M.streamCallback)
	
	for k,v in pairs(_M.availRegisters) do
		if v == false and (availReg == nil or k < availReg) then
			availReg = k
		end
	end

	if availReg == nil then
		return nil, "no more registers available"
	end
	
	_M.availRegisters[availReg] = {streamReg, callback}
	_M.streamRegisters[streamReg] = availReg

	_M.send(nil, _M.ADDR_NOREPLY, _M.CMD_WRFINALHEX, 
				bit32.bor(_M.REG_LUA,_M.REG_STREAMMODE), frequency)
	_M.send(nil, _M.ADDR_NOREPLY, _M.CMD_WRFINALDEC, 
				bit32.bor(_M.REG_LUA, availReg), streamReg)
	_M.send(nil, _M.ADDR_NOREPLY, _M.CMD_EX, 
				bit32.bor(_M.REG_LUA, _M.REG_STREAMDATA), _M.STM_START)
	
	return streamReg
end

function _M.removeStream(streamReg)
	local availReg = _M.streamRegisters[streamReg]

	_M.send(nil, nil, _M.CMD_WRFINALDEC, 
				bit32.bor(_M.REG_LUA, availReg), 0)
	
	_M.unbindRegister(bit32.bor(_M.REG_LUA, availReg))
	
	_M.streamRegisters[streamReg] = nil
	_M.availRegisters[availReg] = false
end

function _M.streamCleanup()
	for k,v in pairs(_M.availRegisters) do 
		_M.send(nil, _M.ADDR_NOREPLY, _M.CMD_WRFINALDEC, 
			bit32.bor(_M.REG_LUA, k), 0)
	end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- From here onwards all functions are associated with the key presses      
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

-- Key groups should have a priority greater than one

-- NO SUPPORT HAS YET BEEN ADDED FOR ADDING, REMOVING, OR CREATING NEW GROUPS
-- WILL BE ADDED 'SOON'.
-- When support is added and the bindGroup function is called, ensure it 
-- presorts the table using table.sort and a compare function

-- Note: doing stuff with the number keys may not be a good idea, as this open
-- an editor on the r400. Better to catch the keys, then write to the LCD 
-- directly.

function _M.handleGroupAllKeys(key, state)
	if state == "up" then	
		key = bit32.bor(key, 0x40)
	elseif state == "long" then
		key = bit32.bor(key, 0x80)
	end

	_M.send(nil, _M.ADDR_NOREPLY, _M.CMD_WRFINALHEX, 
				_M.REG_APP_DO_KEYS, str.format("%X", key))
	
	return true
end

_M.keyID = nil

_M.keyGroup = {}

_M.keyGroup.all			= {priority = 1, callback = _M.handleGroupAllKeys}

_M.keyGroup.IO 			= {priority = 10, callback = nil}
_M.keyGroup.functions	= {priority = 10, callback = nil}
_M.keyGroup.keypad 		= {priority = 10, callback = nil}

_M.keyGroup.m4301		= {priority = 20, callback = nil}
_M.keyGroup.m4311		= {priority = 20, callback = nil}
_M.keyGroup.m4321		= {priority = 20, callback = nil}
_M.keyGroup.m4331		= {priority = 20, callback = nil}
_M.keyGroup.numpad		= {priority = 20, callback = nil}

_M.keyBinds = {
	[_M.KEY_0]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_1]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_2]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_3]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_4]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_5]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_6]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_7]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_8]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_9]			= {_M.keyGroup.numpad, _M.keyGroup.keypad},
	[_M.KEY_POWER]		= {_M.keyGroup.all},
	[_M.KEY_ZERO]		= {_M.keyGroup.all},
	[_M.KEY_TARE]		= {_M.keyGroup.all},
	[_M.KEY_GN]			= {_M.keyGroup.all},
	[_M.KEY_F1]			= {_M.keyGroup.functions},
	[_M.KEY_F2]			= {_M.keyGroup.functions},
	[_M.KEY_F3]			= {_M.keyGroup.functions},
	[_M.KEY_PLUSMINUS]	= {_M.keyGroup.keypad},
	[_M.KEY_DP]			= {_M.keyGroup.keypad},
	[_M.KEY_CANCEL]		= {_M.keyGroup.keypad},
	[_M.KEY_UP]			= {_M.keyGroup.keypad},
	[_M.KEY_DOWN]		= {_M.keyGroup.keypad},
	[_M.KEY_OK]			= {_M.keyGroup.keypad},
	[_M.KEY_SETUP]		= {_M.keyGroup.keypad},
	[_M.KEY_IO1]		= {_M.keyGroup.m4301, _M.keyGroup.IO},
	[_M.KEY_IO2]		= {_M.keyGroup.m4301, _M.keyGroup.IO},
	[_M.KEY_IO3]		= {_M.keyGroup.m4301, _M.keyGroup.IO},
	[_M.KEY_IO4]		= {_M.keyGroup.m4301, _M.keyGroup.IO},
	[_M.KEY_IO5]		= {_M.keyGroup.m4301, _M.keyGroup.IO},
	[_M.KEY_IO6]		= {_M.keyGroup.m4301, _M.keyGroup.IO},
	[_M.KEY_IO7]		= {_M.keyGroup.m4301, _M.keyGroup.IO},
	[_M.KEY_IO8]		= {_M.keyGroup.m4301, _M.keyGroup.IO},
	[_M.KEY_IO9]		= {_M.keyGroup.m4311, _M.keyGroup.IO},
	[_M.KEY_IO10]		= {_M.keyGroup.m4311, _M.keyGroup.IO},
	[_M.KEY_IO11]		= {_M.keyGroup.m4311, _M.keyGroup.IO},
	[_M.KEY_IO12]		= {_M.keyGroup.m4311, _M.keyGroup.IO},
	[_M.KEY_IO13]		= {_M.keyGroup.m4311, _M.keyGroup.IO},
	[_M.KEY_IO14]		= {_M.keyGroup.m4311, _M.keyGroup.IO},
	[_M.KEY_IO15]		= {_M.keyGroup.m4311, _M.keyGroup.IO},
	[_M.KEY_IO16]		= {_M.keyGroup.m4311, _M.keyGroup.IO},
	[_M.KEY_IO17]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO18]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO19]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO20]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO21]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO22]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO23]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO24]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO25]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO26]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO27]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO28]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO29]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO30]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO31]		= {_M.keyGroup.m4321, _M.keyGroup.IO},
	[_M.KEY_IO32]		= {_M.keyGroup.m4321, _M.keyGroup.IO}
}

-------------------------------------------------------------------------------
-- Called when keys are streamed, send the keys to each group it is bound to 
-- in order of priority, until one of them returns true.
-- Note: keybind tables should be sorted by priority
-- @param data Data on key streamed
-- @param err Potential error message
function _M.keyCallback(data, err)
	local callback = nil
	local curPriority = 0
	local maxPriority = 101
	local data = tonum(data, 16)
	local state = "down"
	local key = bit32.band(data, 0x3F)

	if bit32.band(data, 0x80) > 0 then
		state = "long"
	end
	
	local up = false
	if bit32.band(data, 0x40) > 0 then
		state = "up"
	end
	
	local groups = _M.keyBinds[key]
	
	if groups == nil then
		return
	end

	if groups.callback and groups.callback(key, state) == true then
		return
	end
	
	for i=1,#groups do
		if groups[i].callback and groups[i].callback(key, state) == true then
			break
		end		
	end
	
end

-------------------------------------------------------------------------------
-- Set the callback function for an existing key
-- @param key A key given in _M.keyBinds
-- @param callback Function to run when there is an event on the keygroup
function _M.setKeyCallback(key, callback)
	_M.keyBinds[key].callback = callback
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
	_M.send(nil, nil, _M.CMD_EX, _M.REG_FLUSH_KEYS)
	_M.send(nil, nil, _M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 1)
	_M.keyID = _M.addStream(_M.REG_GET_KEY, _M.STM_FREQ_ONCHANGE, _M.keyCallback)
end

-------------------------------------------------------------------------------
-- Cancel keypress handling
-- @param data Data on key streamed
-- @param err Potential error message
function _M.endKeys(flush)
	if flush then
		_M.send(nil, nil, _M.CMD_EX, _M.REG_FLUSH_KEYS)
	end

	_M.send(nil, nil, _M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 0)
	
	_M.removeStream(_M.keyID)
end

return _M