-------------------------------------------------------------------------------
--- General purpose utility functions.
-- Functions for internal library use
-- @module rinLibrary.K400Buzz
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local lower = string.lower
local min, max = math.min, math.max

return function (private)
-------------------------------------------------------------------------------
-- Convert a named value into a real value but also let real values through
-- unmodified.
-- @function convertNameToValue
-- @param n Name to be converted
-- @param map Mapping from names to numeric values
-- @param default Default value to return if something is amiss
-- @param l Least value allowed
-- @param u Uppermost value allowed
-- @return The numeric code associted with the specified name
-- @local
    function private.convertNameToValue(n, map, default, l, u)
        local r
        if type(n) == 'string' then
            r = map[lower(n)] or default
        elseif type(n) == 'number' then
            r = n
        else
            r = default
        end
        if l ~= nil and r < l then  r = default end
        if u ~= nil and r > u then  r = default end
        return r
    end

-------------------------------------------------------------------------------
-- Convert a named value into a real value but also let real values through
-- unmodified.
-- @function convertValueToName
-- @param n Number to be converted
-- @param map Mapping from numeric values to names
-- @param default Default value to return if something is amiss
-- @return The name associted with the specified code
-- @local
    function private.convertValueToName(n, map, default)
        if type(n) == 'string' then
            return lower(n)
        elseif type(n) == 'number' then
            return map[n] or default
        end
        return default
    end

end
