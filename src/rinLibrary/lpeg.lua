-------------------------------------------------------------------------------
--- LPEG extra function.
-- Additional functions to assist with common things when using lpeg
-- @module rinLibrary.lpeg
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local lpeg = require 'lpeg'
local P, S = lpeg.P, lpeg.S

-- Load the locale definitons into the lpeg table itself
lpeg.locale(lpeg)

-------------------------------------------------------------------------------
-- Define a pattern to match a floating point number
-- @function lpeg.float
-- @usage
-- local lpeg = require 'rinLibrary.lpeg'
-- (lpeg.float / tonumber):match('+1.234E-21')
local digits, pm = lpeg.digit^1, S'+-'^-1
lpeg.float = pm * (digits * (P'.'*lpeg.digit^0)^-1 + P'.'*digits) * (S'eE'*pm*digits)^-1

-------------------------------------------------------------------------------
-- Define a lpeg pattern to match a string case insensitively
-- @param str String to match
-- @return pattern
-- @usage
-- local lpeg = require 'rinLibrary.lpeg'
-- local pattern = lpeg.Pi 'hello'
function lpeg.Pi(str)
    if type(str) == 'string' then
        local patt = P(true)
        for c in str:gmatch(".") do
            patt = patt * (P(c:lower()) + P(c:upper()))
        end
        return patt
    end
    error('argument to lpeg.Pi is not a string')
end

return lpeg
