-------------------------------------------------------------------------------
-- printing unit tests.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local params = {
    axle = {
        'a1', 'a2', 'a3', 'a4',
        ["7"] = 'bogus'
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
            { i = 'HEX{$Ac}{$01}', o = 'HEX\\AC\\01' },
            { i = 'T{truck}T', o = 'TTrUcKT' },
            { i = '{truck}T', o = 'TrUcKT' },
            { i = 'T{truck}', o = 'TTrUcK' },
            { i = 'T{  truck  }', o = 'TTrUcK' },
            { i = 'QQ{axle:1}EE', o = "QQa1EE" },
            { i = 'A{farm name}b{farm.location}c', o = 'AFarMblANdc' },
            { i = '{tRuCk}', o = 'TrUcK' },
            { i = '{axle 7}', o = 'bogus' }
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
                                                  {'   at ', '_________|' } } },
            { i = '{ align = middle }',     e = { {'Error:', ' { align = middle }'},
                                                  {'   at ', '_________|' } } },
            { i = '{width = abc}',          e = { {'Error:', ' {width = abc}'},
                                                  {'   at ', '________|' } } },
            { i = '{4}',                    e = { {'Error:', ' {4}'},
                                                  {'   at ', '__|' } } },
            { i = '{supress=never}',        e = { {'Error:', ' {supress=never}'},
                                                  {'   at ', '__|' } } }
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

    describe('format directives', function()
        local cases = {
            { i = '{align=right}ab{truck}c', o = 'abTrUcKc' },
            { i = '{align=right}a{width=7}b{truck}c', o = 'ab  TrUcKc' },
            { i = '{align=left}a{width=7}b{truck}c', o = 'abTrUcK  c' },
            { i = 'a{width=7}b{truck}c{width=-}', o = 'abTrUcK  c' },
            { i = 'ab{truck}c{width=7}d', o = 'abTrUcKcd' },
            { i = 'a{align=right}{width=7}b{truck}c{align=left}{truck}d{width=-}{truck}e', o = 'ab  TrUcKcTrUcK  dTrUcKe' },
        }

        for i = 1, #cases do
            local m = makeModule()
            it("test "..i, function()
                local r = cases[i]

                assert.equal(r.o, m.formatPrintString(params, r.i))
            end)
        end
    end)

    describe('format suppression', function()
        local cases = {
            { i = 'T{bucket}', o = 'T?' },
            { i = 'T{supress=field}{bucket}', o = 'T ' },
            { i = 'T{supress=line}{bucket}', o = nil },
            { i = 'T{supress=no}{bucket}', o = 'T?' },
            { i = 'T{width=8}{supress=no}{bucket}', o = 'T????????' },
            { i = 'T{width=8}{supress=field}{bucket}', o = 'T        ' },
            { i = '{supress=no}', o = '' }  -- reset to default at end
        }

        for i = 1, #cases do
            local m = makeModule()
            it("test "..i, function()
                local r = cases[i]

                assert.equal(r.o, m.formatPrintString(params, r.i))
            end)
        end
    end)

    it('format table', function()
        local m = makeModule()
        assert.same({
            "hello",
            "ad",
            'TrUcK        ',
            "\\FF",
            "fin"
        }, m.formatPrintString(params, {
            "{supress=line}hello",
            "a{width=13}d",
            "{truck}",
            "{$ff}",
            "{missing}",
            "fin"
        }))
    end)

    it('nested table', function()
        local m = makeModule()
        assert.same({
            { { { "hello",
                    "ad" } },
                'TrUcK        ' },
            { "\\FF",
                { { "fin" } } },
            { { { { { { }, { } } } }, { { }, { }, { { } } } } }
        }, m.formatPrintString(params, {
            { { {   "hello",
                    "a{width=13}d" } },
                "{truck}{supress=line}" },
            { "{$ff}",
                { "{missing}",
                    { "fin" } } },
            { { { { { { }, { } } } }, { { }, { }, { { } } } } }
        }))
    end)

    describe('local formatting', function()
        local m = makeModule()
        local cases = {
            { i = 'T{width=8}{supress=no}{align=left}{bucket width=3}', o = 'T???' },
            { i = '{align=left}{farm align=right name width=6}', o = '  FarM' },
            { i = '{align=right}{width=9}{farm align=right name width=6}', o = '  FarM' },
            { i = '{width=7}{farm name width=6}{truck}', o = '  FarM  TrUcK' },
            { i = '{align=right}{width=9}{farm align=right name width=6}{truck}', o = '  FarM    TrUcK' },
            { i = '{width=6}{truck}{bucket supress=field width=2}{truck}', o = ' TrUcK   TrUcK' },
            { i = 'T{width=8}{supress=no}{align=right}{truck width=6}', o = 'T TrUcK' },
        }

        for i = 1, #cases do
            it("test "..i, function()
                local r = cases[i]
                assert.equal(r.o, m.formatPrintString(params, r.i))
            end)
        end
    end)
end)

