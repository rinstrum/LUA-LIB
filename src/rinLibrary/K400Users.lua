-------------------------------------------------------------------------------
--- User realtaed Functions.
-- Functions to read and write user information
-- @module rinLibrary.K400Users
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"
local lpeg = require "rinLibrary.lpeg"
local C, P, R = lpeg.C, lpeg.P, lpeg.R

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--- Instrument User Variables.
--@table usrRegisters
-- @field userid_name1 Names of 5 User ID strings
-- @field userid_name2
-- @field userid_name3
-- @field userid_name4
-- @field userid_name5
-- @field usernum_name1 Names of 5 User ID numbers
-- @field usernum_name2
-- @field usernum_name3
-- @field usernum_name4
-- @field usernum_name5
-- @field userid1 Data for 5 User ID strings
-- @field userid2
-- @field userid3
-- @field userid4
-- @field userid5
-- @field usernum1 Data for 5 User ID numbers
-- @field usernum2 the first 3 are integers
-- @field usernum3
-- @field usernum4 the last 2 are weight values
-- @field usernum5

-- USER VARIABLES
    private.addRegisters{
        userid_name1    = 0x0080,
        userid_name2    = 0x0081,
        userid_name3    = 0x0082,
        userid_name4    = 0x0083,
        userid_name5    = 0x0084,
        usernum_name1   = 0x0316,
        usernum_name2   = 0x0317,
        usernum_name3   = 0x0318,
        usernum_name4   = 0x0319,
        usernum_name5   = 0x031A,
        userid1         = 0x0090,
        userid2         = 0x0092,
        userid3         = 0x0093,
        userid4         = 0x0094,
        userid5         = 0x0095,
        usernum1        = 0x0310,
        usernum2        = 0x0311,
        usernum3        = 0x0312,
        usernum4        = 0x0313,
        usernum5        = 0x0314
    }


-------------------------------------------------------------------------------
-- Check an incoming Id and correcly process it into its proper form
-- @param id User id
-- @param base Base register name
-- @return The canonical refined register name
-- @local
local function checkId(id, base)
    local n = nil

    if type(id) == 'number' then
        local tid = math.floor(id)
        if tid >= 1 and tid <= 5 then
            n = tid
        end
    elseif type(id) == 'string' then
        n = ((C(R"15") + P(base) * C(R"15")) * -1):match(string.lower(id))
    end
    if n ~= nil then
        return base .. tostring(n)
    end

    print('K400Users: ', 'unknown user ID: '..tostring(id))
    return nil
end

-------------------------------------------------------------------------------
-- Set one of the user IDs to the specified string
-- @param id User ID in question (1 .. 5)
-- @param s String to set to
-- @usage
-- device.setUserId(3, 'Brick')
    function _M.setUserId(id, s)
        local u = checkId(id, 'userid')
        if u ~= nil then
            _M.setRegister(u, s)
        end
    end

-------------------------------------------------------------------------------
-- Get one of the user IDs
-- @param id User ID in question (1 .. 5)
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- print('User ID is doing:', device.getUserId(3)
    function _M.getUserId(id)
        local u = checkId(id, 'userid')
        if u ~= nil then
            return _M.getRegister(u)
        end
    end

-------------------------------------------------------------------------------
-- Edit one of the user IDs and return the modified value
-- @param id User ID in question (1 .. 5)
-- @param prompt Prompt to display
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- device.editUserId(3)
    function _M.editUserId(id, prompt)
        local u = checkId(id, 'userid')
        if u ~= nil then
            return _M.editReg(u, prompt)
        end
    end

-------------------------------------------------------------------------------
-- Set one of the user ID numbers to the specified string
-- @param id User ID in question (1 .. 5)
-- @param x Number to set to
-- @usage
-- device.setUserNumber(5, 22)
    function _M.setUserNumber(id, x)
        local u = checkId(id, 'usernum')
        if u ~= nil then
            _M.setRegister(u, x)
        end
    end

-------------------------------------------------------------------------------
-- Get one of the user ID numbers
-- @param id User ID in question (1 .. 5)
-- @return The user ID number
-- @return Error message, nil if none
-- @usage
-- print('User ID has', device.getUserNumber(5)
    function _M.getUserNumber(id)
        local u = checkId(id, 'usernum')
        if u ~= nil then
            return _M.getRegister(u)
        end
    end

-------------------------------------------------------------------------------
-- Edit one of the user ID numbers and return the modified value
-- @param id User ID in question (1 .. 5)
-- @param prompt Prompt to display
-- @return The user ID number
-- @return Error message, nil if none
-- @usage
-- device.editUserId(3)
    function _M.editUserNumber(id, prompt)
        local u = checkId(id, 'usernum')
        if u ~= nil then
            return _M.editReg(u, prompt)
        end
    end

-------------------------------------------------------------------------------
-- Set one of the user ID names to the specified string
-- @param id User ID in question (1 .. 5)
-- @param n Name to set to
-- @usage
-- device.setUserIdName(1, 'Fred')
    function _M.setUserIdName(id, n)
        local u = checkId(id, 'userid_name')
        if u ~= nil then
            _M.setRegister(u, n)
        end
    end

-------------------------------------------------------------------------------
-- Get one of the user ID names
-- @param id User ID in question (1 .. 5)
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- print('User ID is doing:', device.getUserIdName(1)
    function _M.getUserIdName(id)
        local u = checkId(id, 'userid_name')
        if u ~= nil then
            return _M.getRegister(u)
        end
    end

-------------------------------------------------------------------------------
-- Edit one of the user ID names and return the modified value
-- @param id User ID in question (1 .. 5)
-- @param prompt Prompt to display
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- device.editUserId(3)
    function _M.editUserIdName(id, prompt)
        local u = checkId(id, 'userid_name')
        if u ~= nil then
            return _M.editReg(u, prompt)
        end
    end

-------------------------------------------------------------------------------
-- Set one of the user ID number names to the specified string
-- @param id User ID in question (1 .. 5)
-- @param n Name to set to
-- @usage
-- device.setUserIdName(2, 'Johnny')
    function _M.setUserNumberName(id, n)
        local u = checkId(id, 'usernum_name')
        if u ~= nil then
            _M.setRegister(u, n)
        end
    end

-------------------------------------------------------------------------------
-- Get one of the user ID number names
-- @param id User ID in question (1 .. 5)
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- print('User ID is doing:', device.getUserNumberName(2)
    function _M.getUserNumberName(id)
        local u = checkId(id, 'usernum_name')
        if u ~= nil then
            return _M.getRegister(u)
        end
    end

-------------------------------------------------------------------------------
-- Edit one of the user ID number names and return the modified value
-- @param id User ID in question (1 .. 5)
-- @param prompt Prompt to display
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- device.editUserId(3)
    function _M.editUserNumberName(id, prompt)
        local u = checkId(id, 'usernum_name')
        if u ~= nil then
            return _M.editReg(u, prompt)
        end
    end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
private.registerDeprecated{
    'userid1', 'userid2', 'userid3', 'userid4', 'userid5',
    'userid_name1', 'userid_name2', 'userid_name3',
    'userid_name4', 'userid_name5',
    'usernum1', 'usernum2', 'usernum3', 'usernum4', 'usernum5',
    'usernum_name1', 'usernum_name2', 'usernum_name3',
    'usernum_name4', 'usernum_name5',
}

end
