-------------------------------------------------------------------------------
--- General purpose utility functions.
-- Functions for internal library use
-- @module rinLibrary.utilities
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}
local lower = string.lower

-------------------------------------------------------------------------------
-- Convert a named value into a real value but also let real values through
-- unmodified.
-- @param n Name to be converted
-- @param map Mapping from names to numeric values, name should be lower case
-- @param default Default value to return if something is amiss
-- @param l Least value allowed
-- @param u Uppermost value allowed
-- @return The numeric code associted with the specified name
-- @usage
-- local name = require 'rinLibrary.namings'
--
-- local map = {
--     cthulhu = 1,
--     hastur = 2,
--     nyarlathotep = 3,
--     tsathoggua = 4
-- }
--
-- print(name.convertNameToValue('Cthulhu', map))
-- print(name.convertNameToValue('shub-niggurath', map, map['hastur']))
-- print(name.convertNameToValue(16, map, map['tsathoggua'], 1, 4))
function _M.convertNameToValue(n, map, default, l, u)
    local r
    if type(n) == 'string' then
        r = map[lower(n)] or default
    elseif type(n) == 'number' then
        r = n
    else
        r = default
    end

    if l ~= nil and r < l then r = default end
    if u ~= nil and r > u then r = default end
    return r
end

-------------------------------------------------------------------------------
-- Convert a named value into a real value but also let real values through
-- unmodified.
-- @param n Number to be converted
-- @param map Mapping from numeric values to names, name should be lower case
-- @param default Default value to return if something is amiss
-- @return The name associted with the specified code
-- @usage
-- local name = require 'rinLibrary.namings'
--
-- local map = {
--     [1] = 'cthulhu',
--     [2] = 'hastur',
--     [3] = 'nyarlathotep',
--     [4] = 'tsathoggua'
-- }
--
-- print(name.convertNameToValue(2, map))
-- print(name.convertNameToValue(12, map, 'nyarlathotep'))
function _M.convertValueToName(n, map, default)
    if type(n) == 'string' then
        return lower(n)
    elseif type(n) == 'number' then
        return map[n] or default
    end
    return default
end

return _M

