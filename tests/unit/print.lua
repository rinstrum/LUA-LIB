-------------------------------------------------------------------------------
-- printing unit tests.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local params = {
    axle = {
        'a1', 'a2', 'a3', 'a4'
    },
    truck = 'TrUcK',
    farm = {
        name = 'FarM',
        location = 'lANd'
    },
    previous = {
        axle = {
            'p1', 'p2', 'p3', 'p4'
        }
    }
}

describe("K400Print #print", function()
    local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.rinCon")(m, p, d)
        require("rinLibrary.K400Reg")(m, p, d)
        require("rinLibrary.K400Print")(m, p, d)
        return m, p, d
    end

    describe('formatPrintString', function()
        local m = makeModule()
        local cases = {
            { i = 'hello world', o = 'hello world' },
            { i = 'QQ{width=12}A{align = right}BBCEE', o = "QQABBCEE" },
            { i = 'QQ{ width = 1 }A{ align =left}BBCEE', o = "QQABBCEE" },
            { i = 'QQ{ bad = 1 }ABBCEE', o = nil },
            { i = '{ align = middle }', o = nil },
            { i = '{width = abc}', o = nil },
            { i = 'HEX{$Ac}{$01}', o = 'HEX\\\\AC\\\\01' },
            { i = 'T{truck}T', o = 'TTrUcKT' },
            { i = '{truck}T', o = 'TrUcKT' },
            { i = 'T{truck}', o = 'TTrUcK' },
            { i = 'T{  truck  }', o = 'TTrUcK' },
            { i = 'QQ{axle:1}EE', o = "QQa1EE" },
            { i = 'A{farm name}b{farm.location}c', o = 'AFarMblANdc' },
            { i = 'T{bucket}', o = nil },
        }

        for i = 1, #cases do
            it("test "..i, function()
                local r = cases[i]
                assert.equal(r.o, m.formatPrintString(params, r.i))
            end)
        end
    end)

    it('formatPrintTable', function()
        local m = makeModule()
        assert.same({
            "hello",
            "ad",
            'TrUcK',
            "\\\\FF",
            "fin"
        }, m.formatPrintString(params, {
            "hello",
            "a{width=13}d",
            "{truck}",
            "{$ff}",
            "{missing}",
            "fin"
        }))
    end)
end)
