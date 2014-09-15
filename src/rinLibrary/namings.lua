-------------------------------------------------------------------------------
--- Name encoding and decoding functions.
-- Functions intended for internal library use but they might be useful
-- to applications. These functions deal with converting names into values
-- and the inverse.
-- @module rinLibrary.namings
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local lpeg = require 'rinLibrary.lpeg'
local Cs, spc = lpeg.Cs, lpeg.space
local nspc = 1 - spc

local canonPat = spc^0 * Cs(nspc^0 * (spc^1 / ' ' * nspc^1)^0) * spc^0

-------------------------------------------------------------------------------
-- @param s String to convert
-- @return Canonical form for string
-- @local
local function canonical(s)
    return string.lower(canonPat:match(tostring(s)))
end

-------------------------------------------------------------------------------
-- @function canonicalisation
-- @param s String to convert
-- @return Canonical form for string
-- @usage
-- print(namings.canonicalisation('  hello  WoRlD  '))

local _M = { canonicalisation = canonical }

-------------------------------------------------------------------------------
-- Convert a named value into a real value but also let real values through
-- unmodified.
-- @param n Name to be converted
-- @param map Mapping from names to numeric values, names should be lower case canonical form
-- @param default Default value to return if something is amiss
-- @param l Least value allowed
-- @param u Uppermost value allowed
-- @return The numeric code associted with the specified name
-- @usage
-- local name = require 'rinLibrary.namings'
--
-- local map = {
--     cthulhu      = 1,
--     hastur       = 2,
--     nyarlathotep = 3,
--     tsathoggua   = 4
-- }
--
-- print(name.convertNameToValue('Cthulhu', map))
-- print(name.convertNameToValue('shub-niggurath', map, map['hastur']))
-- print(name.convertNameToValue(16, map, map['tsathoggua'], 1, 4))
function _M.convertNameToValue(n, map, default, l, u)
    local r
    if type(n) == 'string' then
        r = map[canonical(n)] or default
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
-- @param map Mapping from numeric values to names, names should be lower case canonical form
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
        return canonical(n)
    elseif type(n) == 'number' then
        return map[n] or default
    end
    return default
end

return _M

