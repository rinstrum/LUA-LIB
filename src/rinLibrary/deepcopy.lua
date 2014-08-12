-------------------------------------------------------------------------------
--- Deep object copy.
-- A function that deeply copies an object.
-- @module rinLibrary.deepcopy
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Return a full deep copy of an original object.  Doesn't deal with looping
-- and self referntial data structures.
-- @function deepcopy
-- @param o Object to copy
-- @return A copy of o that shares no data but is otherwise identical
-- @usage
-- local deepcopy = require 'rinLibrary.deepcopy'
--
-- local t = { 'a', 3, { 1, 4, 3 } }
-- local u = deepcopy(t)
--
-- assert.not_equal(t, u)
-- assert.same(t, u)
local function deepcopy(o)
    if type(o) == 'table' then
        local c = {}
        for k, v in next, o, nil do
            c[deepcopy(k)] = deepcopy(v)
        end
        return setmetatable(c, deepcopy(getmetatable(o)))
    end
    return o
end

return deepcopy
