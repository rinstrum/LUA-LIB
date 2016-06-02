-------------------------------------------------------------------------------
--- LPEG extra function.
-- Additional functions to assist with common things when using lpeg
-- @module rinLibrary.lpeg
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local lpeg = require 'lpeg'
local P, S = lpeg.P, lpeg.S

local type = type
local error = error

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
-- @string str String to match
-- @treturn LpegPattern pattern
-- @usage
-- local lpeg = require 'rinLibrary.lpeg'
-- local pattern = lpeg.Pi 'hello'
function lpeg.Pi(str)
    if type(str) == 'string' then
        local patt = P(true)
        for c in str:gmatch(".") do
            local l, u = c:lower(), c:upper()
            if l == u then
                patt = patt * P(c)
            else
                patt = patt * S(l..u)
            end
        end
        return patt
    end
    error('argument to lpeg.Pi is not a string')
end

return lpeg
