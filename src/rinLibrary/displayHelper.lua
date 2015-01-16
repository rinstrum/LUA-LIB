-------------------------------------------------------------------------------
-- Display Helper
-- Functions to assist writing to the LCD
-- @module rinLibrary.displayHelper
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local string = string
local tostring = tostring

local lpeg = require 'rinLibrary.lpeg'
local C, Cg, Cs, Ct = lpeg.C, lpeg.Cg, lpeg.Cs, lpeg.Ct
local P, Pi, R, S, V, spc = lpeg.P, lpeg.Pi, lpeg.R, lpeg.S, lpeg.V, lpeg.space
local sdot = P'.'
local scdot = (1 - sdot) * sdot^-1
local equals, formatPosition = spc^0 * P'=' * spc^0

-------------------------------------------------------------------------------
-- Return the number of LCD characters a string will consume.
-- @function strLenLCD
-- @param s The string to assess
-- @return The number of display characters
-- @see padDots
-- @see strSubLCD
-- @local
local strLenPat = Cs((scdot / ' ' + sdot)^0)
function _M.strLenLCD(s)
    return #strLenPat:match(s)
end

-------------------------------------------------------------------------------
-- Takes a string and pads ... with . . . for R420 to handle.
-- @function padDots
-- @param s String
-- @return Padded string
-- @see strSubLCD
-- @see strLenLCD
-- @local
local padDotsPat = Cs((scdot + sdot / ' .')^0)
function _M.padDots(s)
    return padDotsPat:match(s)
end

-------------------------------------------------------------------------------
-- Extract a substring based on the LCD width.
-- @param s String to substring
-- @param stPos Starting position
-- @param endPos Ending position, nil for end of string
-- @return The substring between display positions stPos and endPos
-- @see padDots
-- @see strLenLCD
-- @local
function _M.strSubLCD(s, stPos, endPos)
    if endPos == nil then
        endPos = #s
    end

    local n = 0
    local function process(s)
        n = n + 1
        return n >= stPos and n <= endPos and s or ''
    end
    return Cs(((scdot + sdot) / process)^0):match(s)
end

-------------------------------------------------------------------------------
-- Right justify a string in a given field
-- @param s string to justify
-- @param w width to justify to
-- @return justified string
-- @usage
-- if device.rightJustify('hello', 6) == ' hello' then
--     print('yes')
-- end
-- @local
function _M.rightJustify(s, w)
    s = tostring(s)
    local l = _M.strLenLCD(s)
    if l >= w then
        return s
    end
    if s:sub(1, 1) == '.' then l = l - 1 end
    return string.rep(" ", w-l) .. s
end

return _M