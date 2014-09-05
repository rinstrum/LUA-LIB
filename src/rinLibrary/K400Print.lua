-------------------------------------------------------------------------------
--- Printing Functions.
-- Functions to control instrument printing
-- @module rinLibrary.K400Print
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local bit32 = require "bit"
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local can = require 'rinLibrary.canonicalisation'

local lpeg = require 'rinLibrary.lpeg'
local C, Cs, Ct = lpeg.C, lpeg.Cs, lpeg.Ct
local P, Pi, V, S, spc = lpeg.P, lpeg.Pi, lpeg.V, lpeg.S, lpeg.space

local REG_PRINTPORT         = 0xA317
local REG_PRINTTOKENSTR     = 0x004C
local REG_REPLYTOKENSTR     = 0x004D

local PRINT_SER1A           = 0
local PRINT_SER1B           = 1
local PRINT_SER2A           = 2
local PRINT_SER2B           = 3

local portMap = setmetatable({
    ser1a = PRINT_SER1A,    ['1a'] = PRINT_SER1A,
    ser1b = PRINT_SER1B,    ['1b'] = PRINT_SER1B,
    ser2a = PRINT_SER2A,    ['2a'] = PRINT_SER2A,
    ser2b = PRINT_SER2B,    ['2b'] = PRINT_SER2B
}, { __index = function(t, k) return PRINT_SER1A end })

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Print string formatting setup
local formatAttributes = {
    width = 9,
    align = left
}
local formatFailed = false
local formatPosition, formatSubstitutions

local function substitute(x)
    local p = formatSubstitutions
    for _, k in ipairs(x) do
        local cank = can(k)
        local z = tonumber(k) or cank
        if type(p) ~= 'table' or (p[z] == nil and p[cank] == nil) then
            formatFailed = true
            return ''
        end
        p = p[z] or p[cank]
    end
    -- TODO: format this based on current format attribute settings
    return tostring(p)
end

local name, num, value, s = C(lpeg.alpha * lpeg.alnum^0), C(lpeg.digit^1), C(lpeg.alnum^1), spc^0
local POS = P(function(t, p) formatPosition = p return p end)
local eql = s * P'=' * s

local printFormatter = P{
            Cs((P'{'*s/'' * POS * V'cmd' * (s*P'}'/'') + (1-P'{')^1)^0) * P(-1),
    cmd =   Cs(V'attr' + V'sub' + V'hex'),
    hex =   P'$' * lpeg.xdigit * lpeg.xdigit / function(x) return '\\\\' .. string.upper(x:sub(2)) end,
    sub =   Ct(name * ((S':.'+spc^1) * (name + num))^0) / substitute,
-- This version accepts any name = value pairing, the later lines accept only legal ones
--  attr =  Ct(name * eql * value) / function(x) formatAttributes[string.lower(x[1])] = x[2] return '' end
    attr =  Ct(V'align' + V'width') / function(x) formatAttributes[string.lower(x[1])] = x[2] return '' end,
    align = C(Pi'align') * eql * C(Pi'left' + Pi'right'),
    width = C(Pi'width') * eql * C(num)
}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

local curPrintPort = nil

-------------------------------------------------------------------------------
-- Takes a string s and returns a formatted CustomTransmit string with all
-- non-printable characters escaped in \xx format
-- @param s string to convert
-- @return string with all non-printable characters escaped in \xx format
-- @local
local function expandCustomTransmit(s)

  return string.format('%s', string.gsub(s,"[^\32-\126]",
                        function(x)
                            return string.format("\\%02X", string.byte(x))
                        end))
end

-------------------------------------------------------------------------------
-- Send custom print token string to instrument comms port
-- If the port is unspecified, the previous port will be used or 'ser1a' if
-- no previous port has been used.
-- @param tokenStr string containing custom print tokens
-- @param comPortName port to use: 'ser1a', 'ser1b', 'ser2a' or 'ser2b'
-- @see reqCustomTransmit
-- @usage
-- -- A usage application can be found in the printCopy example.
--
-- device.printCustomTransmit([[--------------------------\C1]], 'ser1a')
-- for k,v in ipairs(printCopy) do
--     device.printCustomTransmit(v, 'ser1a')
-- end
-- device.printCustomTransmit([[<<Copy>>\C1]], 'ser1a')
function _M.printCustomTransmit(tokenStr, comPortName)
    local comPort = naming.convertNameToValue(comPortName, portMap, curPrintPort or PRINT_SER1A)

    if comPort ~= curPrintPort  then
        curPrintPort = comPort
        private.writeRegHex(REG_PRINTPORT, comPort)
    end
    tokenStr = expandCustomTransmit(tokenStr)
    private.writeRegHex(REG_PRINTTOKENSTR, tokenStr)
end

-------------------------------------------------------------------------------
-- Called to request response based on custom transmit token string
-- @param tokenStr custom token string
-- @see printCustomTransmit
-- @usage
-- -- get the current weight as a string
-- local weightString = device.reqCustomTransmit([[\D7]])
function _M.reqCustomTransmit(tokenStr)
    s = private.writeRegHex(REG_REPLYTOKENSTR, '8112004D:'..tokenStr, 1000)
    dbg.printVar(s)
    return s
end


-------------------------------------------------------------------------------
-- Format a passed in string using the print format escapes.
-- This function can either format a single string or a table of strings.
-- A failed substitution will cause a nil return for a single string or
-- no entry for a table of strings.
-- @param subs Table of substitution values
-- @param s String to format or table of strings
-- @return Formatted string(s).
-- @usage
-- local params = { gross = 1.234 }
-- print(device.formatPrintString(params, 'Gross is {gross}'))
function _M.formatPrintString(subs, s)
    formatSubstitutions = subs
    local r = nil
    if type(s) == 'string' then
        formatFailed = false
        local z = printFormatter:match(s)
        if z == nil then
            dbg.error('Error:', ' '..s)
            dbg.error('   at ', string.rep('_', formatPosition)..'|')
        elseif not formatFailed then
            r = z
        end
    else
        r = {}
        for line, v in ipairs(s) do
            local q = _M.formatPrintString(subs, v)
            if q ~= nil then
                table.insert(r, q)
            end
        end
    end
    return r
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.PRINT_SER1A = PRINT_SER1A
deprecated.PRINT_SER1B = PRINT_SER1B
deprecated.PRINT_SER2A = PRINT_SER2A
deprecated.PRINT_SER2B = PRINT_SER2B

deprecated.expandCustomTransmit = expandCustomTransmit

end

