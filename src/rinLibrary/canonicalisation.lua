-------------------------------------------------------------------------------
--- Utility function for reducing a name to a canonical form.
-- This means lower case and without leading and trailing space and only single
-- internal spaces.
-- @module rinLibrary.canonicalisation
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local lpeg = require 'lpeg'
local Cs, spc = lpeg.Cs, lpeg.locale().space
local nspc = 1 - spc

local canonicalisation = spc^0 * Cs(nspc^0 * (spc^1 / ' ' * nspc^1)^0) * spc^0

-------------------------------------------------------------------------------
-- @param s String to convert
-- @return Canonical form for string
-- @local
return function(s)
    return string.lower(canonicalisation:match(tostring(s)))
end
