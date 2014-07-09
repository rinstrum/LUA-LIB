-------------------------------------------------------------------------------
-- testINI
-- 
-- Example of how to configure a static table of settings and save/restore 
-- using INI file
-- 
-------------------------------------------------------------------------------

local ini = require "rinLibrary.rinINI"
local dbg = require "rinLibrary.rinDebug"

-------------------------------------------------------------------------------
-- setup a config data table
local config = {
         var1 = 5,         -- global settings
		 var2 = 'Test',
         general = { name = 'Fred'},  -- [general] group settings 
         comms = {baud = '9600',bits = 8, parity = 'N', stop = 1},  -- [comms] group settings
         batching = {target = 1000, freefall = 10} -- [batching] group settings
         }

-------------------------------------------------------------------------------
dbg.info('Default Config = ', config)  	-- log contents of config table to console
local t = ini.loadINI('config.ini',config)  -- load INI file from disk using config table as default 
dbg.info('Loaded Config =', t)         	-- log loaded settings to console
