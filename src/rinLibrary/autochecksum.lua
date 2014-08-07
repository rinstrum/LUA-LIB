-------------------------------------------------------------------------------
-- Routine to provide an integrity checksum.
-- @module rinLibrary.autochecksum
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local allfiles = require 'rinLibrary.checksum-file-list'
local stat = require('posix').stat
local gsub = string.gsub
local insert = table.insert
local lpeg = require 'lpeg'
local C, Ct, P = lpeg.C, lpeg.Ct, lpeg.P

local dirs = Ct(((C((1-P';')^1) * P';')^0) * C((1-P';')^1)):match(package.path)
local files = { 'cat ' }

for _, file in pairs(allfiles) do
    for _, d in ipairs(dirs) do
        local try = gsub(d, '?', file)
        if stat(try) ~= nil then
            insert(files, try)
            insert(files, ' ')
        end
    end
end
insert(files, '| md5sum | cut -f1 -d" "')
local p = io.popen(table.concat(files), 'r')
local res = p:read('*all')
p:close()
return gsub(res, '\10', '')
