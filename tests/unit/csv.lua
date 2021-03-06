-------------------------------------------------------------------------------
-- CSV unit tests.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("CSV tests #csv", function()
    local dbg = require "rinLibrary.rinDebug"
    local csv = require "rinLibrary.rinCSV"
    local path = "tests/unit/"

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
            { c = 0,    r = nil }
        }

        for i = 1, #getColCsvTests do
            it("test "..i, function()
                local r = getColCsvTests[i]
                assert.same(r.r, csv.getColCSV(r.t, r.c))
            end)
        end
    end)

    -- test getRowCSV
    describe("getRowCSV #getrowcsv", function()
        local getRowCsvTests = {
            { n = 1,    r = { 1, 2 },       t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { n = 2,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { n = 3,    r = { 5, 6 },       t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { n = 3,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { n = 0,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { n = 0,    r = nil,            t = { labels = { "a", "b" } } },
            { n = 0,    r = nil,            t = { data = { {1, 2} } } },
            { n = 0,    r = nil }
        }

        for i = 1, #getRowCsvTests do
            it("test "..i, function()
                local r = getRowCsvTests[i]
                assert.same(r.r, csv.getRowCSV(r.t, r.n))
            end)
        end
    end)

    -- test getRowByNumber
    describe("getRowRecord #getrowrecord", function()
        local getRowRecordTests = {
            { n = 1,    r = { a=1, b=2 },   t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { n = 2,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { n = 3,    r = { a=5, b=6 },   t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { n = 3,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { n = 0,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { n = 0,    r = nil,            t = { labels = { "a", "b" } } },
            { n = 0,    r = nil,            t = { data = { {1, 2} } } },
            { n = 0,    r = nil }
        }

        for i = 1, #getRowRecordTests do
            it("test "..i, function()
                local r = getRowRecordTests[i]
                assert.same(r.r, csv.getRowRecord(r.t, r.n))
            end)
        end
    end)

    -- test getColCSV
    describe("getUniqueColCSV #getuniquecolcsv", function()
        local getUniqueColCsvTests = {
            { c = "a",  r = { 1, 4, 5 },    t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { c = "a",  r = { 1, 4 },       t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {1, 6} } } },
            { c = "a",  r = {'A', 'b' },    t = { labels = { "a", "b" }, data = { {'A', 3}, {'b', 6 }, { 'a', 2 }, {'  a  ', 19 } } } },
            { c = 'c',  r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { c = 0,    r = nil,            t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { c = 'a',  r = nil,            t = { labels = { "a", "b" } } },
            { c = 0,    r = nil },
        }

        for i = 1, #getUniqueColCsvTests do
            it("test "..i, function()
                local r = getUniqueColCsvTests[i]
                assert.same(r.r, csv.getUniqueColCSV(r.t, r.c))
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
            { l = {8, 9},   r = { {8, 9} },                         t = { labels = { "a", "b" }, } },
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

    -- test getRecordCSV
    describe("getRecordCSV #getrecordcsv", function()
        local getRecordCsvTests = {
            { v = 1, c = 1,    r = { a=1, b=2 },    t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
            { v = 5, c = "a",  r = { a=5, b=6 },    t = { labels = { "a", "b" }, data = { {1, 2}, {5, 6} } } },
            { v = 2, c = 2,    r = { a=1, b=2 },    t = { labels = { "a", "b" }, data = { {1, 2} } } },
            { v = 6, c = "b",  r = { a=5, b=6 },    t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
        }

        for i = 1, #getRecordCsvTests do
            it("test "..i, function()
                local r = getRecordCsvTests[i]
                local row = csv.getRecordCSV(r.t, r.v, r.c)
                assert.same(r.r, row)
            end)
        end
    end)

    -- test setRecordCSV
    describe("setRecordCSV #setrecordcsv", function()
        local setRecordCsvTests = {
            { v = 1, c = 'a', f={a=9, b=8}, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } },
                                            r = { {9, 8}, {4, 3}, {5, 6} } },
            { v = 6, c = "b", f={a=0, c=9}, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } },
                                            r = { {1, 2}, {4, 3}, {0, 6} } },
            { v = 1, c = 1,   f={ b=8},     t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } },
                                            r = { {1, 8}, {4, 3}, {5, 6} } },
        }

        for i = 1, #setRecordCsvTests do
            it("test "..i, function()
                local r = setRecordCsvTests[i]
                csv.setRecordCSV(r.t, r.v, r.c, r.f)
                assert.same(r.r, r.t.data)
            end)
        end
    end)

    -- test selectCSV
    describe("selectCSV #selectcsv", function()
        local selectCsvTests = {
            { v = 1, c = "a",   t = { }, r = nil },
            { v = 1, c = "a",   t = { labels = { "a", "b" } },
                                r = { labels = { "a", "b" } } },
            { v = 1, c = "a",   t = { labels = { "a", "b" }, data = { {1, 2}, {5, 6}, {1, 3} } },
                                r = { labels = { "a", "b" }, data = { {1, 2}, {1, 3} } } },
            { v = 2, c = "a",   t = { labels = { "a", "b" }, data = { {1, 2}, {5, 6}, {1, 3} } },
                                r = { labels = { "a", "b" }, data = { } } },
            { v = 6, c = "b",   t = { labels = { "a", "b" }, data = { {1, 2}, {5, 6}, {1, 3} } },
                                r = { labels = { "a", "b" }, data = { {5, 6} } } }
        }

        for i = 1, #selectCsvTests do
            it("test "..i, function()
                local r = selectCsvTests[i]
                local row = csv.selectCSV(r.t, r.v, r.c)
                assert.same(r.r, row)
            end)
        end
    end)

    -- test cleanCSV
    describe("cleanCSV #cleancsv", function()
        local cleanCsvTests = {
            {   t = { labels = { 'a', ' AA ', ' B  B  C ' }, data = { { ' fNoRd ', 'aBC  def  GHi', 32 } } },
                r = { labels = { 'a', 'aa', 'b b c' }, data = { { 'fnord', 'abc def ghi', 32 } } }
            }
        }

        for i = 1, #cleanCsvTests do
            it("test "..i, function()
                local r = cleanCsvTests[i]
                csv.cleanCSV(r.t)
                assert.same(r.r, r.t)
            end)
        end
    end)

    -- test toTableCSV
    describe("toTableCSV #totablecsv", function()
        local toTableCSVTests = {
            {   t = {}, r = nil },
            {   t = { labels = { 'a', 'b' }, data = {} }, r = {} },
            {   t = { labels = { 'a', 'b' }, data = { { 'd', 'e' }, { 'f', 'g' }, { 'x', 'y' } } },
                r = { d = { a='d', b='e' }, f = { a='f', b='g' }, x = { a='x', b='y' } }
            },
            {   t = { labels = { 'b', 'a' }, data = { { 'd', 'e' }, { 'f', 'g' }, { 'x', 'y' } } },
                r = { e = { b='d', a='e' }, g = { b='f', a='g' }, y = { b='x', a='y' } }
            }
        }

        for i = 1, #toTableCSVTests do
            it("test "..i, function()
                local r = toTableCSVTests[i]
                local z = csv.toTableCSV(r.t, 'a')
                assert.same(r.r, z)
            end)
        end
    end)

    -- test rows iterator
    describe("rows #rows", function()
        local rowsTests = {
            { t = { labels = { 'a', 'b' }, data = {} }, r = nil },
            { t = { labels = { 'x', 'y' }, data = { { 1, 2 }, { 'a', 3 }, { 2, 'c' } } },
              r = { { 1, { 1, 2 } }, { 2, { 'a', 3 } }, { 3, { 2, 'c' } } } }
        }
        for i = 1, #rowsTests do
            local r, q = rowsTests[i], nil
            it("test "..i, function()
                for n, r in csv.rows(r.t) do
                    if q == nil then q = {} end
                    table.insert(q, { n, r })
                end
                assert.same(r.r, q)
            end)
        end
    end)

    -- test record iterator
    describe("records #records", function()
        local recordsTests = {
            { t = { labels = { 'a', 'b' }, data = {} }, r = nil },
            { t = { labels = { 'x', 'y' }, data = { { 1, 2 }, { 'a', 3 }, { 2, 'c' } } },
              r = { { 1, { x=1, y=2 } }, { 2, { x='a', y=3 } }, { 3, { x=2, y='c' } } } }
        }
        for i = 1, #recordsTests do
            local r, q = recordsTests[i], nil
            it("test "..i, function()
                for n, r in csv.records(r.t) do
                    if q == nil then q = {} end
                    table.insert(q, { n, r })
                end
                assert.same(r.r, q)
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
