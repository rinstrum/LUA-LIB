-------------------------------------------------------------------------------
-- Library for K400 passcode support.
-- @module rinLibrary.K400Passcode
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local tonumber = tonumber
local bit32 = require "bit"
local msg = require 'rinLibrary.rinMessage'

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

local REG_FULLPCODEDATA     = 0x00D0
local REG_SAFEPCODEDATA     = 0x00D1
local REG_OPERPCODEDATA     = 0x00D2

local REG_FULLPCODE         = 0x0019
local REG_SAFEPCODE         = 0x001A
local REG_OPERPCODE         = 0x001B

local passcodes = {
    full = { pcode = REG_FULLPCODE, pcodeData = REG_FULLPCODEDATA },
    safe = { pcode = REG_SAFEPCODE, pcodeData = REG_SAFEPCODEDATA },
    oper = { pcode = REG_OPERPCODE, pcodeData = REG_OPERPCODEDATA }
}

-------------------------------------------------------------------------------
-- Command to check to see if passcode entry required and prompt if so
-- @param pc = 'full','safe','oper'
-- @param code = passcode to unlock, nil to prompt user
-- @param tries = number of tries to make before giving up (default 1),
-- more than 3 consecutive incorrect attempts will lock the instrument until it
-- is rebooted
-- @return true if unlocked false otherwise
-- @usage
-- if device.checkPasscode('full', _, 3) then
--     print('you have full access now')
-- end
function _M.checkPasscode(pc, code, tries)
    local pc = pc or 'full'
    local pcode = passcodes[pc].pcode
    local f = msg.removeErrHandler()
    local pass = ''
    local tries = tries or 1
    local count = 1

    _M.startDialog()
    while _M.dialogRunning() and _M.app.isRunning() do
        local m, err = private.readRegHex(pcode, 1.0)
        if not m then
            if count > tries then
                msg.setErrHandler(f)
                _M.abortDialog()
                return false
            end
            if count > 1 and err then
                private.write('bottomLeft', string.upper(err),1.0)
                _M.buzz(1,_M.BUZZ_LONG)
                _M.app.delay(2.0)
            end
            if code then
                pass = code
                code = nil
            else
                local ok = false
                pass, ok = _M.edit('ENTER PCODE','','passcode')
                if not ok or not pass then
                    msg.setErrHandler(f)
                    _M.abortDialog()
                    return false
                end
            end
            m, err = private.writeRegHex(pcode, _M.toPrimary(pass, 0), 1.0)
            count = count + 1
        else
            break
        end
    end
    _M.abortDialog()
    msg.setErrHandler(f)
    return true
end

-------------------------------------------------------------------------------
-- Command to lock instrument
-- @param pc = 'full','safe','oper'
-- Set a timeout of thirty seconds before full access is lost
-- timers = require 'rinSystem.rinTimers.Pack'
-- timers.addTimer(0, 30, function() device.lockPasscode('full') end)
function _M.lockPasscode(pc)
    local pc = pc or 'full'
    local pcode = passcodes[pc].pcode
    local pcodeData = passcodes[pc].pcodeData

    local f = msg.removeErrHandler()
    local m, err = private.readRegHex(pcodeData, 1.0)
    if m then
        m = bit32.bxor(tonumber(m,16),0xFF)
        m, err = private.writeRegHex(pcode, _M.toPrimary(m, 0), 1.0)
    end
    msg.setErrHandler(f)
end

-------------------------------------------------------------------------------
-- Command to change instrument passcode
-- @param pc = 'full','safe','oper'
-- @param oldCode passcode to unlock, nil to prompt user
-- @param newCode passcode to set, nil to prompt user
-- @return true if successful
-- @usage
-- local pc = device.selectOption('ENTER PASSCODE', {'full', 'safe', 'oper'}, 'full', true)
-- if pc then
--     device.changePasscode(pc)
-- end
function _M.changePasscode(pc, oldCode, newCode)
   local pc = pc or 'full'
   local pcodeData = passcodes[pc].pcodeData
   if _M.checkPasscode(pc,oldCode) then
        if not newCode then
            local pass, ok = _M.edit('NEW','','passcode')
            if not ok then
               return false
            end
            newCode = pass
        end
        local m, err = private.writeRegHex(pcodeData, _M.toPrimary(newCode, 0), 1.0)
        if not m then
            return false
        else
            return true
        end
    end
    return false
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_FULLPCODEDATA    = REG_FULLPCODEDATA
deprecated.REG_SAFEPCODEDATA    = REG_SAFEPCODEDATA
deprecated.REG_OPERPCODEDATA    = REG_OPERPCODEDATA
deprecated.REG_FULLPCODE        = REG_FULLPCODE
deprecated.REG_SAFEPCODE        = REG_SAFEPCODE
deprecated.REG_OPERPCODE        = REG_OPERPCODE

end
