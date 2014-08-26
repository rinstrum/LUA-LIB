-------------------------------------------------------------------------------
-- CSV unit tests.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("CSV tests #csv", function()
    local dbg = require "rinLibrary.rinDebug"
    local csv = require "rinLibrary.rinCSV"
    local path = "tests/unit/"

    -- test canonical form
    describe("canonical form #canonical", function()
        local canTests = {
            { res = "",         val = "" },
            { res = "",         val = " " },
            { res = "",         val = "  " },
            { res = "a",        val = "a" },
            { res = "a",        val = " a" },
            { res = "a",        val = "a " },
            { res = "a",        val = " a " },
            { res = "a",        val = "  a  " },
            { res = "a b",      val = "a  b" },
            { res = "ab cd",    val = "  ab cd  " },
            { res = "ab cd",    val = "  ab   cd  " },
            { res = "ab cd",    val = "ab    cd" },
            { res = "a\000b",   val = " \t\r\n\f\va\000b \r\t\n\f\v" },
            { res = "abc",      val = '  AbC  ' }
        }

        for i = 1, #canTests do
            it("test "..i, function()
                local r = canTests[i]
                assert.equal(r.res, csv.canonical(r.val))
            end)
        end
    end)

    -- test escapeCSV
    describe("escapeCSV #escapecsv", function()
        local escapeTests = {
            { val = 'abc',      res = 'abc' },
            { val = 'abc,def',  res = '"abc,def"' },
            { val = "abc'def",  res = "abc'def" },
            { val = 'abc"def',  res = '"abc""def"' },
            { val = '',         res = '' },
            { val = nil,        res = nil }
        }

        for i = 1, #escapeTests do
            it("test " .. i, function()
                local r = escapeTests[i]
                assert.equal(r.res, csv.escapeCSV(r.val))
            end)
        end
    end)

    -- test toCSV
    describe("toCSV #tocsv", function()
        local toCsvTests = {
            { val = { "a", "b", "c" },          res = "a,b,c" },
            { val = { "a ", " b", " c " },      res = "a , b, c " },
            { val = { '"', ',', '"', "xy" },    res = '"""",",","""",xy' },
            { val = { '""""' },                 res = '""""""""""' },
            { val = { },                        res = '' },
            { val = nil,                        res = '' }
        }

        for i = 1, #toCsvTests do
            it("test "..i, function()
                local r = toCsvTests[i]
                assert.equal(r.res, csv.toCSV(r.val, r.w))
            end)
        end
    end)

    -- test padCSV
    describe("padCSV #padcsv", function()
        local padCsvTests = {
            { val = { "a", "b", "c" },          res = " a, b, c", w=2 },
            { val = { "a", "b", "c" },          res = "a,b,c", w = nil },
            { val = { "a ", " b", " c " },      res = "  a ,   b,  c ", w=4 },
            { val = { '"', ',', '"', "xy" },    res = '"  ""","  ,","  """, xy', w=3 },
            { val = { },                        res = '' },
            { val = nil,                        res = '' }
        }

        for i = 1, #padCsvTests do
            it("test "..i, function()
                local r = padCsvTests[i]
                assert.equal(r.res, csv.padCSV(r.val, r.w))
            end)
        end
    end)

    -- test fromCSV
    describe("fromCSV #fromcsv", function()
        local fromCsvTests = {
            { val = "a,b,c",                    res = { "a", "b", "c" } },
            { val = "a , b, c ",                res = { "a ", " b", " c " } },
            { val = '"  ""","  ,","  """, xy',  res = { '  "', '  ,', '  "', " xy" } },
            { val = '""""""""""',               res = { '""""' } },
            { val = "a,b,c\r",                  res = { "a", "b", "c" } },
            { val = '',                         res = { '' } },
            { val = '\r',                       res = { '' } }
        }

        for i = 1, #fromCsvTests do
            it("test "..i, function()
                local r = fromCsvTests[i]
                assert.same(r.res, csv.fromCSV(r.val))
            end)
        end
    end)

    -- test equalCSV
    describe("equalCSV #equalcsv", function()
        local equalCsvTests = {
            { r=true,   a={ "a", "b", "c" },    b={ 'a', 'b', 'c' } },
            { r=false,  a={ "a", "b", "c" },    b={ 'd', 'e', 'f' } },
            { r=true,   a={ "a", "b", "c" },    b={ 'A', 'B', 'C' } },
            { r=true,   a={ "a ", "b", "c" },   b={ 'a', 'b ', ' c ' } },
            { r=false,  a={ "a", "b", "c" },    b={ 'c', 'b', 'a' } },
            { r=false,  a={ "a", "b", "c" },    b={ 'c', 'b', 'a', 'c' } }
        }

        for i = 1, #equalCsvTests do
            it("test "..i, function()
                local r = equalCsvTests[i]
                assert.equal(r.r, csv.equalCSV(r.a, r.b))
            end)
        end
    end)

    -- test loadCSV
    describe("loadCSV #loadcsv", function()
        local loadCsvTests = {
            { res = "create",       s=true,  t={ fname = "nonexist",            labels = {} } },
            { res = "load",         s=false, t={ fname = path .. "csvData.csv", labels = { "a", "b" } },       v = {{'1', '2'}, {'3', '4'}} },
            { res = "reordered",    s=false, t={ fname = path .. "csvData.csv", labels = { "b", "a" } },       v = {{'2', '1'}, {'4', '3'}} },
            { res = "partial",      s=false, t={ fname = path .. "csvData.csv", labels = { "a", "b", "c" } },  v = {{'1', '2', ''}, {'3', '4', ''}} },
            { res = "partial",      s=false, t={ fname = path .. "csvData.csv", labels = { "a", "c" } },       v = {{'1', ''}, {'3', ''}} },
            { res = "full",         s=false, t={ fname = path .. "csvData.csv", labels = { "a" } },            v = {{'1'}, {'3'}} },
            { res = "immiscable",   s=false, t={ fname = path .. "csvData.csv", labels = { "x" } } },
            { res = "load",         s=false, t={ fname = path .. "csvData.csv" },                              v = {{'1', '2'}, {'3', '4'}} },
        }

        for i = 1, #loadCsvTests do
            it("test "..i, function()
                local r = loadCsvTests[i]

                stub(csv, "saveCSV")
                local t, res = csv.loadCSV(r.t)

                if r.s then
                    assert.stub(csv.saveCSV).was.called()
                else
                    assert.stub(csv.saveCSV).was.not_called()
                end
                assert.equal(r.res, res)
                if r.v ~= nil then
                    assert.same(r.v, r.t.data)
                else
                    assert.is_nil(t.data)
                end
                csv.saveCSV:revert()
            end)
        end
    end)

    -- test numRowsCSV
    describe("numRowsCSV #numrowscsv", function()
        local numCsvTests = {
            { rows = 0, t = {} },
            { rows = 0 },
            { rows = 1, t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { rows = 3, t = { labels = { "a" }, data = { {1}, {3}, {5} } } },
            { rows = 0, t = { labels = { "a", "b", "c", "d", "e" } } },
            { rows = 0, t = { data = { {1, 2}, {4, 3}, {5, 6} } } },
        }

        for i = 1, #numCsvTests do
            it("test "..i, function()
                local r = numCsvTests[i]
                assert.equal(r.rows, csv.numRowsCSV(r.t))
            end)
        end
    end)

    -- test numColsCSV
    describe("numColsCSV #numcolscsv", function()
        local numCsvTests = {
            { cols = 0, t = {} },
            { cols = 0 },
            { cols = 2, t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { cols = 1, t = { labels = { "a" }, data = { {1}, {3}, {5} } } },
            { cols = 5, t = { labels = { "a", "b", "c", "d", "e" } } },
            { cols = 0, t = { data = { {1, 2}, {4, 3}, {5, 6} } } },
        }

        for i = 1, #numCsvTests do
            it("test "..i, function()
                local r = numCsvTests[i]
                assert.equal(r.cols, csv.numColsCSV(r.t))
            end)
        end
    end)

    -- test labelColCSV
    describe("labelColCSV #labelcolcsv", function()
        local labelColTests = {
            { c = "a",  r = 1,      t = { labels = { "a", "b" } } },
            { c = "b",  r = 2,      t = { labels = { "a", "b" } } },
            { c = "c",  r = nil,    t = { labels = { "a", "b" } } },
            { c = "a",  r = nil,    t = { } },
            { c = "a",  r = nil,    t = nil }
        }

        for i = 1, #labelColTests do
            it("test "..i, function()
                local r = labelColTests[i]
                assert.equal(r.r, csv.labelCol(r.t, r.c))
            end)
        end
    end)

    -- test getColCSV
    describe("getColCSV #getcolcsv", function()
        local getColCsvTests = {
            { c = 1,    r = { 1, 4, 5 },    t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { c = "a",  r = { 1, 5 },       t = { labels = { "a", "b" }, data = { {1, 2}, {5, 6} } } },
            { c = 2,    r = { 2 },          t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { c = "b",  r = { 2, 3, 6 },    t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { c = 3,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { c = 0,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { c = 0,    r = nil,            t = { labels = { "a", "b" } } },
            { c = 0,    r = nil,            t = { data = { {1, 2} } } },
            { c = 0,    r = nil },
        }

        for i = 1, #getColCsvTests do
            it("test "..i, function()
                local r = getColCsvTests[i]
                assert.same(r.r, csv.getColCSV(r.t, r.c))
            end)
        end
    end)

    -- test addLineCSV
    describe("addLineCSV #addlinecsv", function()
        local addLineCsvTests = {
            { l = {8, 9},   r = { {1, 2}, {4, 3}, {5, 6}, {8, 9} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = nil,      r = { {1, 2}, {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = {1},      r = { {1, 2}, {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } }, msg = "incorrect number of columns.  Expected 2 have 1" },
            { l = {1,2,3},  r = { {1, 2}, {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } }, msg = "incorrect number of columns.  Expected 2 have 3" },
            { l = {8, 9},   r = { {1, 2}, {4, 3}, {5, 6} },         t = {                        data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = {8, 9},   r = nil,                                t = { labels = { "a", "b" }, } },
        }

        for i = 1, #addLineCsvTests do
            it("test "..i, function()
                local r = addLineCsvTests[i]
                stub(dbg, "warn")
                csv.addLineCSV(r.t, r.l)

                assert.same(r.r, r.t.data)
                if r.msg then
                    assert.stub(dbg.warn).was.called_with("addLineCSV: ", r.msg)
                else
                    assert.stub(dbg.warn).was.not_called()
                end
                dbg.warn:revert()
            end)
        end
    end)

    -- test remLineCSV
    describe("remLineCSV #remlinecsv", function()
        local remLineCsvTests = {
            { l = 2, r = { {1, 2}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 1, r = { {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 3, r = { {1, 2}, {4, 3} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 4, r = { {1, 2}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 0, r = { {1, 2}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 2, r = { {1, 2}, {4, 3}, {5, 6} }, t = {                        data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 2, r = nil,                        t = { labels = { "a", "b" }, } },
        }

        for i = 1, #remLineCsvTests do
            it("test "..i, function()
                local r = remLineCsvTests[i]
                csv.remLineCSV(r.t, r.l)
                assert.same(r.r, r.t.data)
            end)
        end
    end)

    -- test replaceLineCSV
    describe("replaceLineCSV #replacelinecsv", function()
        local replaceLineCsvTests = {
            { l = 2, d = {9, 8},    r = { {1, 2}, {9, 8}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 1, d = {9, 8},    r = { {9, 8}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 6, d = {9, 8},    r = { {1, 2}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 0, d = {9, 8},    r = { {1, 2}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 1, d = {9, 8, 3}, r = { {1, 2}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 2, d = {9 },      r = { {1, 2}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 2, d = {9 },      r = { {1, 2}, {4, 3}, {5, 6} }, t = {                        data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 2, d = {9 },      r = nil,                        t = { labels = { "a", "b" }, } },
            { l = 2, d = nil,       r = { {1, 2}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 1, d = nil,       r = { {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 3, d = nil,       r = { {1, 2}, {4, 3} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 4, d = nil,       r = { {1, 2}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { l = 0, d = nil,       r = { {1, 2}, {4, 3}, {5, 6} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
        }

        for i = 1, #replaceLineCsvTests do
            it("test "..i, function()
                local r = replaceLineCsvTests[i]
                csv.replaceLineCSV(r.t, r.l, r.d)

                assert.same(r.r, r.t.data)
            end)
        end
    end)

    -- test dupLineCSV
    describe("dupLineCSV #duplinecsv", function()
        local dupLineCsvTests = {
            { r = nil, l = nil },
            { r = {},  l = {} },
            { r = { 1, 2, 3}, l = { 1, 2, 3} }
        }

        for i = 1, #dupLineCsvTests do
            it("test "..i, function()
                local r = dupLineCsvTests[i]
                assert.same(r.r, csv.dupLineCSV(r.l))
                assert.same(r.r, r.l)
            end)
        end
    end)

    -- test tostringCol
    describe("tostringCol #tostringcol", function()
        local tostringColTests = {
            { r = nil,                  c = nil         },
            { r = "",                   c = {}          },
            { r = "1\r\n2\r\n3\r\n",    c = { 1, 2, 3}  },
            { r = "1\r\n",              c = { 1 }       }
        }

        for i = 1, #tostringColTests do
            it("test "..i, function()
                local r = tostringColTests[i]
                assert.equal(r.r, csv.tostringCol(r.c))
            end)
        end
    end)

    -- test tostringLine
    describe("tostringLine #tostringline", function()
        local tostringLineTests = {
            { r = nil,                                  c = nil                     },
            { r = "",                                   c = {}                      },
            { r = "         1,         2,         3",   c = { 1, 2, 3}              },
            { r = "         1",                         c = { 1 }                   },
            { r = "  1,  3",                            c = { 1, 3 },       w = 3   },
        }

        for i = 1, #tostringLineTests do
            it("test "..i, function()
                local r = tostringLineTests[i]
                assert.equal(r.r, csv.tostringLine(r.c, r.w))
            end)
        end
    end)

    -- test getLineCSV
    describe("getLineCSV #getlinecsv", function()
        local getLineCsvTests = {
            { v = 1, c = 1,    n = 1,   r = { 1, 2 },    t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { v = 5, c = "a",  n = 2,   r = { 5, 6 },    t = { labels = { "a", "b" }, data = { {1, 2}, {5, 6} } } },
            { v = 2, c = 2,    n = 1,   r = { 1, 2 },    t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { v = 6, c = "b",  n = 3,   r = { 5, 6 },    t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
        }

        for i = 1, #getLineCsvTests do
            it("test "..i, function()
                local r = getLineCsvTests[i]
                local n, row = csv.getLineCSV(r.t, r.v, r.c)
                assert.equal(r.n, n)
                assert.same(r.r, row)
            end)
        end
    end)

    -- test logLineCSV
    describe("logLineCSV #loglinecsv", function()
        pending("unimplemented test case")
    end)

    -- test tostringCSV
    describe("tostringCSV #tostringcsv", function()
        pending("unimplemented test case")
    end)

    -- test saveCSV
    describe("saveCSV #savecsv", function()
        pending("unimplemented test case")
    end)

    -- test addTableDB
    describe("addTableDB #addtabledb", function()
        pending("unimplemented test case")
    end)

    -- test loadDB
    describe("loadDB #loaddb", function()
        pending("unimplemented test case")
    end)

    -- test addLineDB
    describe("addLineDB #addlinedb", function()
        pending("unimplemented test case")
    end)

    -- test remLineDB
    describe("remLineDB #remlinedb", function()
        pending("unimplemented test case")
    end)

    -- test saveDB
    describe("saveDB #savedb", function()
        pending("unimplemented test case")
    end)

    -- test tostringDB
    describe("tostringDB #tostringdb", function()
        pending("unimplemented test case")
    end)
end)
