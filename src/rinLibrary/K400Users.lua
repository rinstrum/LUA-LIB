-------------------------------------------------------------------------------
--- User realtaed Functions.
-- Functions to read and write user information
-- @module rinLibrary.K400Users
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

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
    private.addRegister('userid_name1',     0x0080)
    private.addRegister('userid_name2',     0x0081)
    private.addRegister('userid_name3',     0x0082)
    private.addRegister('userid_name4',     0x0083)
    private.addRegister('userid_name5',     0x0084)
    private.addRegister('usernum_name1',    0x0316)
    private.addRegister('usernum_name2',    0x0317)
    private.addRegister('usernum_name3',    0x0318)
    private.addRegister('usernum_name4',    0x0319)
    private.addRegister('usernum_name5',    0x031A)

    private.addRegister('userid1',          0x0090)
    private.addRegister('userid2',          0x0092)
    private.addRegister('userid3',          0x0093)
    private.addRegister('userid4',          0x0094)
    private.addRegister('userid5',          0x0095)
    private.addRegister('usernum1',         0x0310)
    private.addRegister('usernum2',         0x0311)
    private.addRegister('usernum3',         0x0312)
    private.addRegister('usernum4',         0x0313)
    private.addRegister('usernum5',         0x0314)


-------------------------------------------------------------------------------
-- Set one of the user IDs to the specified string
-- @param id User ID in question (1 .. 5)
-- @param s String to set to
-- @usage
-- device.setUserId(3, 'Brick')
    function _M.setUserId(id, s)
        private.writeReg('userid'..id, s)
    end

-------------------------------------------------------------------------------
-- Get one of the user IDs
-- @param id User ID in question (1 .. 5)
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- print('User ID is doing:', device.getUserId(3)
    function _M.getUserId(id)
        return private.readReg('userid'..id)
    end

-------------------------------------------------------------------------------
-- Set one of the user ID numbers to the specified string
-- @param id User ID in question (1 .. 5)
-- @param x Number to set to
-- @usage
-- device.setUserNumber(5, 22)
    function _M.setUserNumber(id, x)
        private.writeReg('usernum'..id, x)
    end

-------------------------------------------------------------------------------
-- Get one of the user ID numbers
-- @param id User ID in question (1 .. 5)
-- @return The user ID number
-- @return Error message, nil if none
-- @usage
-- print('User ID has', device.getUserNumber(5)
    function _M.getUserNumber(id)
        return private.readReg('usernum'..id)
    end

-------------------------------------------------------------------------------
-- Set one of the user ID names to the specified string
-- @param id User ID in question (1 .. 5)
-- @param n Name to set to
-- @usage
-- device.setUserIdName(1, 'Fred')
    function _M.setUserIdName(id, n)
        private.writeReg('userid_name'..id, n)
    end

-------------------------------------------------------------------------------
-- Get one of the user ID names
-- @param id User ID in question (1 .. 5)
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- print('User ID is doing:', device.getUserIdName(1)
    function _M.getUserIdName(id)
        return private.readReg('userid_name'..id)
    end

-------------------------------------------------------------------------------
-- Set one of the user ID number names to the specified string
-- @param id User ID in question (1 .. 5)
-- @param n Name to set to
-- @usage
-- device.setUserIdName(2, 'Johnny')
    function _M.setUserNumberName(id, n)
        private.writeReg('usernum_name'..id, n)
    end

-------------------------------------------------------------------------------
-- Get one of the user ID number names
-- @param id User ID in question (1 .. 5)
-- @return The user ID string
-- @return Error message, nil if none
-- @usage
-- print('User ID is doing:', device.getUserNumberName(2)
    function _M.getUserNumberName(id)
        return private.readReg('usernum_name'..id)
    end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
for _, v in ipairs({
            'userid1', 'userid2', 'userid3', 'userid4', 'userid5',
            'userid_name1', 'userid_name2', 'userid_name3',
            'userid_name4', 'userid_name5',
            'usernum1', 'usernum2', 'usernum3', 'usernum4', 'usernum5',
            'usernum_name1', 'usernum_name2', 'usernum_name3',
            'usernum_name4', 'usernum_name5',
        }) do
    private.registerDeprecated(v)
end

end
