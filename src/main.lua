local L401 = require "rinLibrary.rincon"
local userio = require "IOSocket.Pack"

local system = require "rinFramework.Pack"

-- Set up with timers to request the serial every 3 seconds
local getSerial = L401.preconfigureMsg(L401.REG_SERIALNO)	-- Example of how to get a function for getting the serial.
local writeBottomLeft = L401.preconfigureMsg(L401.REG_DISP_BOTTOM_LEFT, L401.CMD_WRFINALHEX)
local writeBottomRight = L401.preconfigureMsg(L401.REG_DISP_BOTTOM_RIGHT, L401.CMD_WRFINALHEX)

-- Function for testing timers
local function test(arg)
	print("timer", arg)
end

local function L401ErrorHandler(err)
	print(err)
end

local function spamtest()
	getSerial()
end

local function handleSerial(data, err)
	if err then
		print(err)
		return
	end

	print("serial", tonumber(data, 16))
end

local function handleWeightStream(data, err)
	print("weight", data)
end

local function handleTimeStream(data, err)
	print("time", data)
end

local function handleMinStream(data, err)
	print("mins", data)
end

-- Handle keypresses
local function keyboardCall(sock)
	local data = sock:receive("*l")
	
	print("keyboard: " .. data)
end

local function remover(key)
	print("removed timer", key)
	system.timers.removeTimer(key)
end

local function printTrue(key, state)
	print("printTrue", key, state)
	return true
end

local function numHandler(key, state)
	if state == "down" then
		writeBottomLeft(key)
	end
	
	return true
end

local function numHandlerLies(key, state)
	if state == "down" then
		writeBottomLeft(math.random(0,9))
	end
	
	return true
end

local function changeState(key, state)
	L401.setKeyGroupCallback(L401.keyGroup.numpad, numHandlerLies)
	
	return true
end

-- Timers. args: time, delay, callback, callback args. If time>0, it is assumed to be repeating.
-- Timers return their key, and can be cancelled with the same key.
local key1 = system.timers.addTimer(2000, 0, test, "1")
local key2 = system.timers.addTimer(2000, 1000, test, "0.5")
local key3 = system.timers.addTimer(3000, 0, spamtest)
local key4 = system.timers.addTimer(0, 5000, remover, key2)

system.timers.addTimer(2000, 0, writeBottomRight, "1")
system.timers.addTimer(2000, 1000, writeBottomRight, "0")

-- Remember, timers aren't a part of the L401 system, they are handled by the framework.

L401.connectDevice("172.17.1.148", 2222, 100)
L401.streamCleanup()	-- Clean up any existing streams on connect
L401.setupKeys()		-- Set up keys for keyhandling via the library

L401.setKeyCallback(L401.KEY_0, printTrue)					-- Set up a callback for the 0 key.
L401.setKeyGroupCallback(L401.keyGroup.numpad, numHandler)	-- Set up a callback for the numpad group
L401.setKeyCallback(L401.KEY_F1, changeState)				-- Set up a callback so when F1 is pressed
															-- the numpad is random (note: this is not a proper state machine)													

-- bind a register to a callback
L401.bindRegister(L401.REG_SERIALNO, handleSerial)	-- Function is called when data on the register is received

-- Add some streams, and bind the streamed data to a callback
local weightStream = L401.addStream(L401.REG_GROSSNET, L401.STM_FREQ_ONCHANGE, handleWeightStream)
system.timers.addTimer(0, 10e3, L401.removeStream, weightStream)

local timeStream = L401.addStream(L401.REG_TIMESEC, L401.STM_FREQ_ONCHANGE, handleTimeStream)
system.timers.addTimer(0, 5e3, L401.removeStream, timeStream)

local minStream = L401.addStream(L401.REG_TIMEMIN, L401.STM_FREQ_ONCHANGE, handleMinStream)
system.timers.addTimer(0, 10e3, L401.removeStream, minStream)

-- After 30 seconds, we're done with keys
--system.timers.addTimer(0, 30e3, L401.endKeys)


L401.setErrHandler(L401ErrorHandler)	-- Set the error handle for message errors (not device errors)
system.sockets.addSocket(L401.socket, L401.frameworkCallback) --Connect, with 100ms timeouts
system.sockets.addSocket(userio.connectDevice(), keyboardCall)

while true do
	system.handleEvents()
end