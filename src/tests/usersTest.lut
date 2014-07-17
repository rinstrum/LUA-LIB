-------------------------------------------------------------------------------
-- Users unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local regs = require "tests.registers"

describe("K400Users #users", function()
    local registers = {
        userid1                 = 0x0090,
        userid2                 = 0x0092,
        userid3                 = 0x0093,
        userid4                 = 0x0094,
        userid5                 = 0x0095,
        userid_name1            = 0x0080,
        userid_name2            = 0x0081,
        userid_name3            = 0x0082,
        userid_name4            = 0x0083,
        userid_name5            = 0x0084,
        usernum1                = 0x0310,
        usernum2                = 0x0311,
        usernum3                = 0x0312,
        usernum4                = 0x0313,
        usernum5                = 0x0314,
        usernum_name1           = 0x0316,
        usernum_name2           = 0x0317,
        usernum_name3           = 0x0318,
        usernum_name4           = 0x0319,
        usernum_name5           = 0x031A
    }
    local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.K400Users")(m, p, d)

        regs.populate(p.regPopulate, m, p, d)

        return m, p, d
    end

    describe("registers", function()
        local m, p = makeModule()
        for r, v in pairs(registers) do
            it('test '..r, function()
                assert.equal(v, p.getRegisterNumber(r))
                assert.equal(r, p.getRegisterName(v))
            end)
        end
    end)
end)
