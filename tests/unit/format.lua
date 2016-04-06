-------------------------------------------------------------------------------
-- Format unit test.
-- @author Merrick Heley
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("format #format", function()
    local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.GenericUtil")(m, p, d)
        return m, p, d
    end

    describe("formatcheck", function()
        local m, p, d = makeModule()
        local cases = {
            { a={ 'primary', 15, 0, 1, false },  r="15" },
            { a={ 'primary', 15, 1, 1, false },  r="15.0" },
            { a={ 'primary', 15.1, 1, 1, false },  r="15.1" },
            { a={ 'primary', 15.11111111111111, 1, 1, false },  r="15.1" },
            { a={ 'primary', 15.499999999999, 1, 1, false },  r="15.5" },
            
            { a={ 'primary', 15, 2, 1, false },  r="15.00" },
            { a={ 'primary', 15.1, 2, 1, false },  r="15.10" },
            { a={ 'primary', 15.11111111111111, 2, 1, false },  r="15.11" },
            { a={ 'primary', 15.499999999999, 2, 1, false },  r="15.50" },
            
            { a={ 'primary', 15, 2, 2, false },  r="15.00" },
            { a={ 'primary', 15.1, 2, 1, false },  r="15.10" },
            { a={ 'primary', 15.11111111111111, 2, 2, false },  r="15.12" },
            { a={ 'primary', 15.499999999999, 2, 2, false },  r="15.50" },

            { a={ 'primary', 15, 2, 5, false },  r="15.00" },
            { a={ 'primary', 15.1, 2, 5, false },  r="15.10" },
            { a={ 'primary', 15.11111111111111, 2, 5, false },  r="15.10" },
            { a={ 'primary', 15.499999999999, 2, 5, false },  r="15.50" },
            { a={ 'primary', 15.555555555555, 2, 5, false },  r="15.55" },

            { a={ 'primary', 15, 2, 10, false },  r="15.00" },
            { a={ 'primary', 15.1, 2, 10, false },  r="15.10" },
            { a={ 'primary', 15.11111111111111, 2, 10, false },  r="15.10" },
            { a={ 'primary', 15.499999999999, 2, 10, false },  r="15.50" },
            
            { a={ nil, 15.9532, 3, 2, false }, r="15.954" },
            
            { a={ 'primary', 15, 2, 10, 'kg' },  r="15.00 kg" },
            { a={ 'primary', 15.1, 2, 10, ' lb' },  r="15.10  lb" },
            { a={ 'primary', 15.11111111111111, 2, 10, '' },  r="15.10 " },
            { a={ 'primary', 15.499999999999, 2, 10, 'kglb' },  r="15.50 kgl" },
            
            { a={ 'primary', 1.1, 24, 1, false },  r="1.100000000000000008388608" },
        }
        
        for i = 1, #cases do
            it('test '..i, function()
                assert.equal(cases[i].r, m.formatValue(unpack(cases[i].a)))
            end)
        end
    end)
end)
