-------------------------------------------------------------------------------
-- Creates the L401 Library
-- @module L401
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local require = require
local pairs = pairs
local print = print


local function mergeModule(modstr)
	local mod = require(modstr)
	for k,v in pairs(mod) do
		if _M[k] then
			print("Error encountered when merging " .. modstr .. ": " .. k .. " already exists in device")
		else
			_M[k] = v
		end

	end
end

function _M.configure(ip, port, timeout, queue)
	-- Get all modules and merge them into our library
	mergeModule("rinLibrary.general.rinRegisters")
	mergeModule("rinLibrary.general.rinConnection")
	mergeModule("rinLibrary.general.rinGeneral")
	mergeModule("rinLibrary.general.rinBinding")
	
	-- Create a connection to the device
	local sock = _M.connect(ip, port, timeout)
	
	-- Configure libraries
	_M.configureRinConnection(sock, false)
	_M.configureRinGeneral(sock, queue)
	
	return _M	
end

return _M