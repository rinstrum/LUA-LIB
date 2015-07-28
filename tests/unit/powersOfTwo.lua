-------------------------------------------------------------------------------
-- Powers of Two unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("power of two test #pow2", function ()
    package.loaded['rinLibrary.powersOfTwo'] = nil
    local p2 = require "rinLibrary.powersOfTwo"

    it("logarithmic population", function()
        local a = p2[-11]
        local r = {}
        for k,v in pairs(p2) do
            r[k] = v
        end
        assert.same({[-11] = 0.00048828125,     [11] = 2048,    [10] = 1024,    [5] = 32,
                     [4] = 16,       [2] = 4,   [1] = 2,        [0] = 1
                    }, r)
    end)

    it("numerical", function()
        -- Load some mysterious values up
        local a = p2[111]
        a = p2[39]
        a = p2[128]
        a = p2[-122]
        for i = -10, 12 do
            a = p2[i]
        end

        -- Compare these values against what they sohuld be
        for k, v in pairs(p2) do
            local s = math.pow(2, k)
            assert.are_equal(v, s)
        end
    end)
end)

