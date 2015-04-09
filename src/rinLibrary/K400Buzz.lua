-------------------------------------------------------------------------------
--- Buzzer Handling.
-- Functions associated with the making of noise
-- @module rinLibrary.K400Buzz
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local min, max = math.min, math.max
local naming = require 'rinLibrary.namings'

-------------------------------------------------------------------------------
--- Buzzer Control.
-- Functions to control instrument buzzer
-- @section buzzer

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)
    local REG_BUZZ_LEN =  0x0327
    local REG_BUZZ_NUM =  0x0328

    local lastBuzzLen = nil
    local lengths = {
        short   = 0,
        medium  = 1,
        long    = 2
    }

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Called to set the length of the buzzer sound
-- @see buzz
-- @param len - length of buzzer sound ('short', 'medium' or 'long'), default is short
-- @local
    local function setBuzzLen(len)
        local l = naming.convertNameToValue(len, lengths, lengths.short, lengths.short, lengths.long)
        if l ~= lastBuzzLen then
            private.writeRegHexAsync(REG_BUZZ_LEN, l)
            lastBuzzLen = l
        end
    end

-------------------------------------------------------------------------------
-- Called to trigger instrument buzzer.
-- There are no gaps between long beeps.
-- @param times - number of times to buzz, 1..4, default is one
-- @param len - length of buzzer sound ('short', 'medium' or 'long'), default is short
-- @usage
-- -- Emit an SOS sequence
-- -- The delays are required since execution continues
-- -- before the buzzer is finished.
-- device.buzz(3, 'short')
-- rinApp.delay(1.4)
-- device.buzz(3, 'medium')
-- rinApp.delay(2.2)
-- device.buzz(3, 'short')
    function _M.buzz(times, len)
        local n = max(1, min(4, tonumber(times or 1)))
        setBuzzLen(len)
        private.writeRegHexAsync(REG_BUZZ_NUM, n)
    end

    -- Allow the unit tests to dig deeper into our internals
    if _TEST then
        function _M.getLastBuzzLen()
            return lastBuzzLen
        end
        _M.setBuzzLen = setBuzzLen
        _M.REG_BUZZ_LEN = REG_BUZZ_LEN
        _M.REG_BUZZ_NUM = REG_BUZZ_NUM
        _M.lengths = lengths
    end
end
