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
        local dbg = require 'rinLibrary.rinDebug'
        local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.rinCon")(m, p, d)
        require("rinLibrary.K400Reg")(m, p, d)
        require("rinLibrary.K400Print")(m, p, d)
        return m, p, d
    end

    describe('format string', function()
        local m = makeModule()
        local cases = {
            { i = 'hello world', o = 'hello world' },
            { i = 'QQ{width=12}A{align = right}BBCEE', o = "QQABBCEE" },
            { i = 'QQ{ width = 1 }A{ align =left}BBCEE', o = "QQABBCEE" },
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

    describe('format errors', function()
        local m = makeModule()
        local cases = {
            { i = 'QQ{ bad = 1 }ABBCEE',    e = { {'Error:', ' QQ{ bad = 1 }ABBCEE'},
                                                  {'   at ', '_____|' } } },
            { i = '{ align = middle }',     e = { {'Error:', ' { align = middle }'},
                                                  {'   at ', '___|' } } },
            { i = '{width = abc}',          e = { {'Error:', ' {width = abc}'},
                                                  {'   at ', '__|' } } },
        }

        for i = 1, #cases do
            it("test "..i, function()
                stub(dbg, "error")

                local r = cases[i]
                assert.is_nil(m.formatPrintString(params, r.i))
                for k, v in pairs(r.e) do
                    assert.stub(dbg.error).was.called_with(unpack(v))
                end
                dbg.error:revert()
            end)
        end
    end)

    it('format table', function()
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
