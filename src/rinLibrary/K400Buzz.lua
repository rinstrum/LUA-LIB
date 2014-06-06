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
return function (_M)
    -- The lengths of beeps, takes 0 (short), 1(med) or 2(long).
    -- There are no gaps between long beeps
    _M.REG_BUZZ_LEN =  0x0327
    -- takes 1 – 4, will clear to 0 once beeps have been executed
    _M.REG_BUZZ_NUM =  0x0328

    _M.BUZZ_SHORT = 0
    _M.BUZZ_MEDIUM = 1
    _M.BUZZ_LONG = 2

    local lastBuzzLen = nil

    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
    -- Called to set the length of the buzzer sound
    -- @param len - length of buzzer sound (BUZZ_SHORT, BUZZ_MEDIUM, BUZZ_LONG)
    local function setBuzzLen(len)
        local l = max(_M.BUZZ_SHORT, min(_M.BUZZ_LONG, len or _M.BUZZ_SHORT))
        if l ~= lastBuzzLen then
            _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_BUZZ_LEN, l)
            lastBuzzLen = l
        end
    end

    -------------------------------------------------------------------------------
    -- Called to trigger instrument buzzer
    -- @param times  - number of times to buzz, 1..4
    -- @param len - length of buzzer sound (BUZZ_SHORT, BUZZ_MEDIUM, BUZZ_LONG)
    function _M.buzz(times, len)
        local n = min(4, tonumber(times or 1))
        setBuzzLen(len)
        _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_BUZZ_NUM, n)
    end

    -- Allow the unit tests to dig deeper into our internals
    if _TEST then
        function _M.getLastBuzzLen()
            return lastBuzzLen
        end
        _M.setBuzzLen = setBuzzLen
    end
end
