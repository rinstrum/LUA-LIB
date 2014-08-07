local path = os.getenv('STAGE_DIR') .. '/' .. os.getenv('LUA_MOD_DIR')
package.path = path .. '/?.lua;'..package.path

local sum = require 'rinLibrary.autochecksum'

print('integrity: "'..sum..'"')
