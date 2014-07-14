-------------------------------------------------------------------------------
--- Buzzer Handling.
-- Functions associated with the making of noise
-- @module rinLibrary.K400Buzz
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local min, max = math.min, math.max

-------------------------------------------------------------------------------
--- Buzzer Control.
-- Functions to control instrument buzzer
-- @section buzzer

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)
    local REG_BUZZ_LEN =  0x0327
    local REG_BUZZ_NUM =  0x0328

    local BUZZ_SHORT = 0
    local BUZZ_MEDIUM = 1
    local BUZZ_LONG = 2

    local lastBuzzLen = nil

    local lengthMap = {
        short = BUZZ_SHORT,
        medium = BUZZ_MEDIUM,
        long = BUZZ_LONG
    }

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Called to set the length of the buzzer sound
-- @see buzz
-- @param len - length of buzzer sound ('short', 'medium' or 'long')
-- @local
    local function setBuzzLen(len)
        local l = private.convertNameToValue(len, lengthMap, BUZZ_SHORT, BUZZ_SHORT, BUZZ_LONG)
        if l ~= lastBuzzLen then
            _M.sendReg('wrfinalhex', REG_BUZZ_LEN, l)
            lastBuzzLen = l
        end
    end

-------------------------------------------------------------------------------
-- Called to trigger instrument buzzer.
-- There are no gaps between long beeps.
-- @param times - number of times to buzz, 1..4
-- @param len - length of buzzer sound ('short', 'medium' or 'long')
-- @usage
-- -- Emit an SOS sequence
-- -- The delays are required since execution continues
-- -- before the buzzer is finished.
-- device.buzz(3, 'short')
-- device.delay(1.4)
-- device.buzz(3, 'medium')
-- device.delay(2.2)
-- device.buzz(3, 'short')
    function _M.buzz(times, len)
        
        local n = max(1, min(4, tonumber(times or 1)))
        setBuzzLen(len)
        _M.sendReg('wrfinalhex', REG_BUZZ_NUM, n)
    end

    -- Allow the unit tests to dig deeper into our internals
    if _TEST then
        function _M.getLastBuzzLen()
            return lastBuzzLen
        end
        _M.setBuzzLen = setBuzzLen
    end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
    deprecated.REG_BUZZ_LEN = REG_BUZZ_LEN
    deprecated.REG_BUZZ_NUM = REG_BUZZ_NUM
    deprecated.BUZZ_SHORT = BUZZ_SHORT
    deprecated.BUZZ_MEDIUM = BUZZ_MEDIUM
    deprecated.BUZZ_LONG = BUZZ_LONG
end
