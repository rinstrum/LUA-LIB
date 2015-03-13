-------------------------------------------------------------------------------
-- Utility unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("utlitity #utilitiy", function()
    local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        return p
    end

    describe("addmod1", function()
        local p = makeModule()
        local cases = {
            { a={3, 3, 6, false },  r=6 },
            { a={3, 4, 6, false },  r=6 },
            { a={3,-2, 6, false },  r=1 },
            { a={3,-3, 6, false },  r=1 },
            { a={1,-1, 4, false },  r=1 },
            { a={4, 1, 4, false },  r=4 },

            { a={3, 3, 6, true  },  r=6 },
            { a={3, 4, 6, true  },  r=1 },
            { a={3,-2, 6, true  },  r=1 },
            { a={3,-3, 6, true  },  r=6 },
            { a={3,-5, 6, true  },  r=4 },
            { a={1,-1, 4, true  },  r=4 },
            { a={4, 1, 4, true  },  r=1 },
            { a={1, 1, 1, true  },  r=1 }
        }
        for i = 1, #cases do
            it('test '..i, function()
                assert.equal(cases[i].r, p.addModBase1(unpack(cases[i].a)))
            end)
        end
    end)
end)
