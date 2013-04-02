-------------------------------------------------------------------------------
-- Handles buzzer output
-- @module buzzer
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

_M.REG_BUZZ_LEN =  0x0327        -- the lengths of beeps, takes 0 (short), 1(med) or 2(long). There are no gaps between long beeps
_M.REG_BUZZ_NUM =  0x0328        -- takes 1 � 4, will clear to 0 once beeps have been executed

_M.BUZZ_SHORT = 0
_M.BUZZ_MEDIUM = 1
_M.BUZZ_LONG = 2

--------------------------------------------------------------------------------------------------------------
-- called to set the length of the buzzer sound
-- @param len - length of buzzer sound (BUZZ_SHORT, BUZZ_MEDIUM, BUZZ_LONG)
function _M.setBuzzLen(len)

   local len = len or _M.BUZZ_SHORT
   if len > _M.BUZZ_LONG then len = _M.BUZZ_LONG end
   
   _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_BUZZ_LEN, len, "noReply")

end

--------------------------------------------------------------------------------------------------------------
-- called to trigger instrument buzzer
-- @param times  - number of times to buzz, 1..4
function _M.buzz(times)
    local times = times or 1
	if times > 4 then times = 4 end

    _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_BUZZ_NUM, times, "noReply")

end

return _M
