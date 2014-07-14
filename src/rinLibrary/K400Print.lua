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
    local comPort = private.convertNameToValue(comPortName, portMap, curPrintPort or PRINT_SER1A)

    if comPort ~= curPrintPort  then
        curPrintPort = comPort
        _M.sendRegWait('wrfinalhex', REG_PRINTPORT, comPort)
    end
    tokenStr = expandCustomTransmit(tokenStr)
    _M.sendRegWait('wrfinalhex', REG_PRINTTOKENSTR, tokenStr)
end

-------------------------------------------------------------------------------
-- Called to request response based on custom transmit token string
-- @param tokenStr custom token string
-- @see printCustomTransmit
-- @usage
-- -- get the current weight as a string
-- local weightString = device.reqCustomTransmit([[\D7]])
function _M.reqCustomTransmit(tokenStr)
    s = _M.sendRegWait('wrfinalhex', REG_REPLYTOKENSTR, '8112004D:'..tokenStr, 1000)
    dbg.printVar(s)
    return s
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.PRINT_SER1A = PRINT_SER1A
deprecated.PRINT_SER1B = PRINT_SER1B
deprecated.PRINT_SER2A = PRINT_SER2A
deprecated.PRINT_SER2B = PRINT_SER2B

deprecated.expandCustomTransmit = expandCustomTransmit

end

