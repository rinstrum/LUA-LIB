-------------------------------------------------------------------------------
-- Handles status streaming
-- @module status
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local pairs = pairs
local string = string
local tonumber = tonumber

local bit32 = require "bit"

_M.REG_LUA_STATUS   = 0x0329
_M.REG_LUA_STAT_RTC = 0x032A
_M.REG_LUA_STAT_RDG = 0x032B
_M.REG_LUA_STAT_IO  = 0x032A
_M.REG_IOSTATUS		= 0x0051

_M.lastIOStatus 	= 0

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
	local callback = nil
	local data = tonumber(data, 16)
    
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

----------------------------------------------------------------------------------
-- Control the use of RTC status bit
-- @param s true to enable RTC change monitoring, false to disable
function _M.setRTCStatus(s)
   local s = s or true
   if s then s = 1 else s = 0 end
   _M.send(nil,_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_RTC,s, "noReply") 
end

----------------------------------------------------------------------------------
-- Control the use of reading count status bit.  This is usedful if weight readings are not collected via an onchagne stream register directly
-- @param num sets the number of readings to trigger a reading count status change
function _M.setRDGStatus(num)
    local num = num or 0
	if num > 255 then num = 255 end
	_M.send(nil,_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_RDG,num, "noReply")
end

----------------------------------------------------------------------------------
-- Control the use of reading count status bit.  This is usedful if weight readings are not collected via an onchagne stream register directly
-- @param num sets the number of readings to trigger a reading count status change
function _M.setIOStatus(mask)
    local mask = mask or 0
	_M.send(nil,_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_IO, mask, "noReply")
end

-------------------------------------------------------------------------------
-- sets IO status IO bit to recognise this IO 
-- @param IO is output 1..32
function _M.enableIOStatus(IO)
   local curIOStatus =  bit32.bor(_M.lastIOStatus, bit32.lshift(0x0001,(IO-1)))
   if (curIOStatus ~= _M.lastIOStatus) then
      _M.setIOStatus(curIOStatus)
      _M.lastIOStatus = curIOStatus
    end  
    
end

-------------------------------------------------------------------------------
-- sets IO status IO bit to ignore this IO 
-- @param IO is output 1..32
function _M.releaseIOStatus(IO)
local curIOStatus =  bit32.band(_M.lastIOStatus,bit32.bnot(bit32.lshift(0x0001,(IO-1))))
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

return _M