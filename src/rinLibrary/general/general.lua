-------------------------------------------------------------------------------
-- Contains general functions necessary for device use
-- @module general
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltdf
-------------------------------------------------------------------------------

local _M = {}

local str = string
local table = table
local assert = assert
local tonum = tonumber
local pairs = pairs
local type = type
local tonumber = tonumber

local bit32 = require "bit"
local register = require "rinLibrary.general.registers"

--_M.socket = nil

_M.sendQ = {head = 0,tail = -1}
_M.queueMessages = true

-------------------------------------------------------------------------------
-- Configure rinConnection
-- @param queue Enqueue messages to be sent (boolean)
function _M.configureRinGeneral(sock, queue)
	_M.socket = sock
	_M.queueMessages = queue
end

-------------------------------------------------------------------------------
-- Receive a message from a socket.
-- Receives one byte at a time, and ends the message based on specified 
-- delimiters
-- @return A string bounded by delimiters (nil if error)
-- @return An error message (nil if no error)
function _M.recMsg()
	local char, prevchar, error,  msg
	local buffer = {}

	while true do
		prevchar = char
		char, error = _M.socket:receive(1)
		
		if error then break end
		
		if char == '\01' then
			buffer = {}
		end

		table.insert(buffer,char)

		-- Check for delimiters.
		if buffer[1] == '\01' then
			if char == '\04' then
				break
			end
		elseif (prevchar == '\r' and char == '\n') or char == ';' then
			break
		end
	end
	
	if error == nil then
	    msg = table.concat(buffer)
		if _M.echo then dbg.printVar(msg,'>>>') end 
    	return msg, nil
	end
    
	if _M.echo then dbg.printVar(error,"Error: ") end
	
  	return nil, error
end

-------------------------------------------------------------------------------
-- Creates a CRC-CCITT (0xFFFF) of the given ASCII data
-- @param message Message to be processed
-- @return CRC-CCITT (0xFFFF) of message
function _M.CCITT(data)
	local poly = 0x1021
	local crc = 0xffff
	
	for c = 1, #data do
		local char = str.byte(data, c)
		local x = bit32.band(bit32.bxor(bit32.arshift(crc, 8), char), 0xFF)
		x = bit32.bxor(x, bit32.arshift(x, 4))
		crc = bit32.band(bit32.bxor(crc*2^8, x*2^12, x*2^5, x), 0xFFFF)
	end
	
	return crc
end

-------------------------------------------------------------------------------
-- Processes the message and feeds back the individual parts
-- @param msg Message to be processed
-- @return address (0x00 to 0x1F)
-- @return command	(CMD_*)
-- @return register	(REG_*)
-- @return data
-- @return error
function _M.processMsg(msg)
	local validDelim = nil
	local newMsg
	local addr, cmd, reg, data
	
	if msg == nil then
		return nil, nil, nil, nil, "msg was nil"
	end
	
	if str.sub(msg,1,1) == '\01' then
		if str.sub(msg,-1,-1) == '\04' then
			validDelim = "CRC"
			newMsg = str.sub(msg, 2, -6)	
		end
	
	elseif str.sub(msg, -2, -1) == '\r\n' then
		validDelim = "NORM"
		newMsg = str.sub(msg, 1, -3)
	
	elseif str.sub(msg,-1,-1) == ';' then
		validDelim = "NORM"
		newMsg = str.sub(msg, 1, -2)
	end
	
	if validDelim == nil then 
		return nil, nil, nil, nil, "bad delimiters" 
		
	elseif validDelim == "CRC" 
			and str.sub(msg,-5,-2) == _M.CCITT(newMsg) then
		return nil, nil, nil, nil, "bad crc"
	end
	
	local semiPos = str.find(msg, ':')
	
	if semiPos == nil then
		return nil, nil, nil, nil, "no separator found"
	end
	
	addr = tonum(str.sub(newMsg, 1, 2), 16)
	cmd = tonum(str.sub(newMsg,3,4), 16)
	reg = tonum(str.sub(newMsg, 5, 8), 16)
	data = str.sub(newMsg, semiPos+1, -1)
	
	if not (addr and cmd and reg and data) then
		return nil, nil, nil, nil, "non-hex msg"
	end

	if bit32.band(addr, register.ADDR_ERR) == _M.ADDR_ERR then
		return nil, nil, nil, data, _M.errStrings[tonumber(data,16)] 
	end
	
	addr = bit32.band(addr, 0x1F)
	
	return addr, cmd, reg, data
	
end

-------------------------------------------------------------------------------
-- Reads a processed message from the R400
-- @return address (0x00 to 0x1F)
-- @return command	(CMD_*)
-- @return register	(REG_*)
-- @return data
-- @return error
function _M.getProcessed()
	return _M.processMsg(_M.recMsg())
end

-------------------------------------------------------------------------------
-- Sends a raw message. If queued, add to the queue to be sent. Otherwise,
-- send directly.
-- @param raw  string to send 
function _M.sendRaw(raw)
	if _M.queueMessages == true then
   		_M.pushQ(raw)   --  queue message to be sent on next timeout
   	else
   		_M.socket:send(raw)
   	end
end

-------------------------------------------------------------------------------
-- Sends a message with delimiters added optionally with CRC
-- @param msg  message string to send 
-- @param crc  if crc = 'crc' then SOH msg CRC EOT sent, msg CRLF otherwise (default)
function _M.sendMsg(msg, crc)
    local crc = crc or ''
	
	if crc == 'crc' then
    	_M.sendRaw(table.concat({'\01', 
	    							msg, 
		    						str.format("%04X", _M.CCITT(msg)), 
			    					'\04'}))
	else
	    _M.sendRaw(table.concat({msg,'\13\10'}))
    end	
end

-------------------------------------------------------------------------------
-- Sends a structured message built up from individual parameters as follows
-- @param addr Indicator address (0x00 to 0x1F) 
-- @param cmd Command (CMD_*)
-- @param reg Register (REG_*)
-- @param data Data to be sent
-- @param reply - 'reply' (default) if reply required, sent with ADDR_NOREPLY otherwise
-- @param crc - 'crc' if message sent with crc, false (default) otherwise
function _M.send(addr, cmd, reg, data, reply, crc)
    local addr = addr or _M.ADDR_BROADCAST
	local cmd = cmd or _M.CMD_RDFINALHEX
	local data = data or ""
    local reply = reply or 'reply'
	if reply == 'reply' then addr = bit32.bor(addr,_M.ADDR_REPLY) end
	
	
	if cmd == _M.CMD_WRFINALHEX then
	    if type(data) == 'number' then
    	   data = str.format("%X",data)
		end   
	 end  
	_M.sendMsg((str.format("%02X%02X%04X:%s", 
					addr, 
					cmd, 
					reg, 
					data)),crc)
end

-------------------------------------------------------------------------------
-- Designed to be registered with rinSystem. Called when new data is received 
-- on the socket. If a message error occurs, pass it to the error handler.
function _M.socketCallback()
	local addr, cmd, reg, data, err = _M.getProcessed()
	
	if err and _M.addErrHandler then
		_M.errHandler(err)
		return
	end
	
	local called = false
	if _M.deviceRegisters[reg] then
		_M.deviceRegisters[reg](data, err)
		called = true
	end
	if not called and _M.deviceRegisters[0] then
	   _M.deviceRegisters[0](data,err)
	end
end

-------------------------------------------------------------------------------
-- Add 1 to the queue and put the message on the end of the queue 
-- @param Message to add to the end of the queue
function _M.pushQ(msg)
   local tail = _M.sendQ.tail + 1
   _M.sendQ.tail = tail
   _M.sendQ[tail] = msg
end

-------------------------------------------------------------------------------
-- Remove the message from the front of the queue, and return the message
-- @return Message removed from the queue
function _M.popQ()
  local head = _M.sendQ.head
  if head > _M.sendQ.tail then return nil end
 
 local msg = _M.sendQ[head]
  _M.sendQ[head] = nil
  _M.sendQ.head = head + 1
  return msg
end

-------------------------------------------------------------------------------
-- Check if the queue is empty
-- @return True if empty, false otherwise
function _M.Qempty()
  return (_M.sendQ.head > _M.sendQ.tail)
end

-------------------------------------------------------------------------------
-- Designed to be registered with rinSystem. If a message error occurs, pass it
-- to the error handler.
function _M.sendQueueCallback()
   if not _M.Qempty() then
      local msg = _M.popQ()
	  if _M.echo then  dbg.printVar(msg,'<<<') end
	  _M.socket:send(msg)
   end
end

-------------------------------------------------------------------------------------------------
-- called to convert hexadecimal return string to a weight reading
-- @param data returned from _CMD_RDFINALHEX
-- @param dp decimal position
-- @return Converted data
function _M.toWeight(data,dp)
   local dp = dp or 0
    
   data = tonumber(data,16)
   if data > 0x7FFFFFFF then
	    data = data - 0xFFFFFFFF - 1
	end
	
   for i = dp,1,-1 do
      data = data / 10
   end
   
   return data
end

return _M