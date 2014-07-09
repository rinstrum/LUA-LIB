-------------------------------------------------------------------------------
-- Powers of Ten unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("power of ten test #pow10", function ()
    package.loaded['rinLibrary.powersOfTen'] = nil
    local p10 = require "rinLibrary.powersOfTen"

    it("logarithmic population", function()
        local a = p10[-11]
        local r = {}
        for k,v in pairs(p10) do
            r[k] = v
        end
        assert.same({[-11] = 1e-11,  [11] = 1e11,    [10] = 1e10,    [5] = 1e5,
                     [4] = 1e4,      [2] = 1e2,      [1] = 1e1,      [0] = 1
                    }, r)
    end)

    it("numerical", function()
        -- Load some mysterious values up
        local a = p10[111]
        a = p10[39]
        a = p10[128]
        a = p10[-122]
        for i= -10, 12 do
            a = p10[i]
        end

        -- Compare these values against what they sohuld be
        for k,v in pairs(p10) do
            local s = tonumber(string.format("%.0e", v):sub(3), 10)
            assert.are_equal(s, k)
        end
    end)
end)

