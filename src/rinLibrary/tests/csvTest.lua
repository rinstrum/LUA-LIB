#!/usr/local/bin/lua
-------------------------------------------------------------------------------
-- CSV unit tests.
-- @module rinLibrary.tests.csvTest
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local csv = require "rinLibrary.rinCSV"

local path = "rinLibrary/tests/"

-- Utility functions to update the number of tests and fails and to get these values
-- We actually hide the variables inside some closures to ensure that none
-- of the tests directly attempt to alter them.  Can't see how to inline this
-- without the temporary function.
function testresultfunctions()
    local tests, fails = 0, 0

    local function t(failed)
        if failed then
            fails = fails + 1
        end
        tests = tests + 1
    end

    local function r()
        return tests, fails
    end

    return t, r
end

local test, results = testresultfunctions()

-- Utility function to compare two vectors for inequality
local function compareVectors(expected, result, i, test)
    if expected == nil then
        if result ~= nil then
            print(test.." fail for line "..i.." result not nil")
            return true
        end
    else
        if #expected ~= #result then
            print(test.." fail for line "..i.." wrong number of rows")
            return true
        else
            for j = 1, #result do
                if expected[j] ~= result[j] then
                    print(test.." fail for line "..i.." bad value row "..j)
                    return true
                end
            end
        end
    end
    return false
end

-- Utility function to compare a data table against a CSV table for inequality
local function compareResult(expected, t, i, test)
    if expected == nil then
        if t.data ~= nil then
            print(test.." fail for line "..i.." result not nil")
            return true
        end
    elseif t.data ~= nil then
        if #expected ~= #t.data then
            print(test.." fail for line "..i.." wrong number of rows")
            return true
        elseif t.labels ~= nil then
            for j = 1, #expected do
                for k = 1, #t.labels do
                    if t.data[j] == nil then
                        print(test.." fail for line "..i.." no data row "..j)
                        return true
                    elseif #expected[j] ~= #t.data[j] then
                        print(test.." fail for line "..i.." uneven data row "..j)
                        return true
                    elseif expected[j][k] ~= t.data[j][k] then
                        print(test.." fail for line "..i.." bad element ("..j..", "..k..")".." got "..t.data[j][k].." expected "..expected[j][k])
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test escapeCSV
local escapeTests = {
    { val = 'abc',      res = 'abc' },
    { val = 'abc,def',  res = '"abc,def"' },
    { val = "abc'def",  res = "abc'def" },
    { val = 'abc"def',  res = '"abc""def"' },
    { val = '',         res = '' }
}

for i = 1, #escapeTests do
    local r = escapeTests[i]
    local x = csv.escapeCSV(r.val)
    local failed = false

    if x ~= r.res then
        print("escapeCSV fail for @" .. r.val .. "@ giving @"..x.."@ instead of @"..r.res.."@")
        failed = true
    end
    test(failed)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test toCSV
local toCsvTests = {
    { val = { "a", "b", "c" },          res = "a,b,c" },
    { val = { "a ", " b", " c " },      res = "a , b, c " },
    { val = { '"', ',', '"', "xy" },    res = '"""",",","""",xy' },
    { val = { '""""' },                 res = '""""""""""' },
    { val = { },                        res = '' },
    { val = nil,                        res = '' }
}

for i = 1, #toCsvTests do
    local r = toCsvTests[i]
    local x = csv.toCSV(r.val, r.w)
    local failed = false

    if x ~= r.res then
        print("toCSV fail for line "..i.." giving @"..x.."@ instead of @"..r.res.."@")
        failed = true
    end
    test(failed)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test padCSV
local padCsvTests = {
    { val = { "a", "b", "c" },          res = " a, b, c", w=2 },
    { val = { "a", "b", "c" },          res = "a,b,c", w = nil },
    { val = { "a ", " b", " c " },      res = "  a ,   b,  c ", w=4 },
    { val = { '"', ',', '"', "xy" },    res = '"  ""","  ,","  """, xy', w=3 },
    { val = { },                        res = '' },
    { val = nil,                        res = '' }
}

for i = 1, #padCsvTests do
    local r = padCsvTests[i]
    local x = csv.padCSV(r.val, r.w)
    local failed = false

    if x ~= r.res then
        print("padCSV fail for line "..i.." giving @"..x.."@ instead of @"..r.res.."@")
        failed = true
    end
    test(failed)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test fromCSV
local fromCsvTests = {
    { val = "a,b,c",                    res = { "a", "b", "c" } },
    { val = "a , b, c ",                res = { "a ", " b", " c " } },
    { val = '"  ""","  ,","  """, xy',  res = { '  "', '  ,', '  "', " xy" } },
    { val = '""""""""""',               res = { '""""' } },
    { val = "a,b,c\r",                  res = { "a", "b", "c" } },
    { val = '',                         res = nil },
    { val = '\r',                       res = nil },
    { val = nil,                        res = nil }
}

    local function compareCsv(a, b)
        if a == nil then return a == b end
        if #a ~= #b then return false end
        for i = 1, #a do
            if a[i] ~= b[i] then return false end
        end
        return true
    end

for i = 1, #fromCsvTests do
    local r = fromCsvTests[i]
    local x = csv.fromCSV(r.val)

    test(compareVectors(r.res, x, i, "fromCSV"))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test equalCSV
local equalCsvTests = {
    { r=true,   a={ "a", "b", "c" },    b={ 'a', 'b', 'c' } },
    { r=false,  a={ "a", "b", "c" },    b={ 'd', 'e', 'f' } },
    { r=true,   a={ "a", "b", "c" },    b={ 'A', 'B', 'C' } },
    { r=true,   a={ "a ", "b", "c" },   b={ 'a', 'b ', ' c ' } },
    { r=false,  a={ "a", "b", "c" },    b={ 'c', 'b', 'a' } },
    { r=false,  a={ "a", "b", "c" },    b={ 'c', 'b', 'a', 'c' } }
}

for i = 1, #equalCsvTests do
    local r = equalCsvTests[i]
    local failed = false

    if r.r ~= csv.equalCSV(r.a, r.b) then
        print("equalCSV fail for line "..i)
        failed = true
    end
    test(failed)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test loadCSV
local loadCsvTests = {
    { res = "create",       s=true,  t={ fname = "nonexist",            labels = {} } },
    { res = "load",         s=false, t={ fname = path .. "csvData.csv", labels = { "a", "b" } },       v = {{'1', '2'}, {'3', '4'}} },
    { res = "reordered",    s=true,  t={ fname = path .. "csvData.csv", labels = { "b", "a" } },       v = {{'2', '1'}, {'4', '3'}} },
    { res = "partial",      s=true,  t={ fname = path .. "csvData.csv", labels = { "a", "b", "c" } },  v = {{'1', '2', ''}, {'3', '4', ''}} },
    { res = "partial",      s=true,  t={ fname = path .. "csvData.csv", labels = { "a", "c" } },       v = {{'1', ''}, {'3', ''}} },
    { res = "full",         s=true,  t={ fname = path .. "csvData.csv", labels = { "a" } },            v = {{'1'}, {'3'}} },
    { res = "immiscable",   s=true,  t={ fname = path .. "csvData.csv", labels = { "x" } } },
    { res = "load",         s=false, t={ fname = path .. "csvData.csv" },                              v = {{'1', '2'}, {'3', '4'}} },
}

local saveSaveCSV = csv.saveCSV
for i = 1, #loadCsvTests do
    local r = loadCsvTests[i]
    local failed = false
    local saveCalled = false

    csv.saveCSV = function (t)
                      if t.fname ~= r.t.fname then
                         print("loadCSV fail for line "..i.." saveCSV bad file name "..t.fname.." (expected "..r.t.fname..")")
                         failed = true
                      end
                      saveCalled = true
                  end

    local t, res = csv.loadCSV(r.t)

    if r.res ~= res then
        print("loadCSV fail for line "..i.." result is "..res.." expected "..r.res)
        failed = true
    elseif r.v ~= nil then
        failed = compareResult(r.v, r.t, i, "loadCSV")
    elseif t.data ~= nil then
        print("loadCSV fail for line "..i.." table has data when it shouldn't")
        failed = true
    end
    if not failed and saveCalled ~= r.s then
        print("loadCSV fail for line "..i.." save function anomoly")
        failed = true
    end
    test(failed)
end
csv.saveCSV = saveSaveCSV

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test numRowsCSV & numColsCSV
local numCsvTests = {
    { rows = 0, cols = 0, t = {} },
    { rows = 0, cols = 0 },
    { rows = 1, cols = 2, t = { labels = { "a", "b" }, data = { {1, 2} } } },
    { rows = 3, cols = 1, t = { labels = { "a" }, data = { {1}, {3}, {5} } } },
    { rows = 0, cols = 5, t = { labels = { "a", "b", "c", "d", "e" } } },
    { rows = 0, cols = 0, t = { data = { {1, 2}, {4, 3}, {5, 6} } } },
}

for i = 1, #numCsvTests do
    local r = numCsvTests[i]
    local rows = csv.numRowsCSV(r.t)
    local cols = csv.numColsCSV(r.t)
    local failed = false

    if r.rows ~= rows then
        print("numRowsCSV fail for line "..i.." got "..rows.." instead of "..r.rows)
        failed = true
    end
    if r.cols ~= cols then
        print("numColsCSV fail for line "..i.." got "..cols.." instead of "..r.cols)
        failed = true
    end
    test(failed)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test labelColCSV
local labelColTests = {
    { c = "a",  r = 1,      t = { labels = { "a", "b" } } },
    { c = "b",  r = 2,      t = { labels = { "a", "b" } } },
    { c = "c",  r = nil,    t = { labels = { "a", "b" } } },
    { c = "a",  r = nil,    t = { } },
    { c = "a",  r = nil,    t = nil }
}

for i = 1, #labelColTests do
    local r = labelColTests[i]
    local col = csv.labelCol(r.t, r.c)
    local failed = false

    if col ~= r.r then
        print("labelCol fail for line "..i.." got "..col.." instead of "..r.r)
        failed = true
    end
    test(failed)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test getColCSV
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
    local r = getColCsvTests[i]
    local col = csv.getColCSV(r.t, r.c)

    test(compareVectors(r.r, col, i, "getColCSV"))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test addLineCSV
local addLineCsvTests = {
    { l = {8, 9},   n = 4,   r = { {1, 2}, {4, 3}, {5, 6}, {8, 9} }, t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
    { l = nil,      n = nil, r = { {1, 2}, {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
    { l = {1},      n = nil, r = { {1, 2}, {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
    { l = {1,2,3},  n = nil, r = { {1, 2}, {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, data = { {1, 2}, {4, 3}, {5, 6} } } },
    { l = {8, 9},   n = nil, r = { {1, 2}, {4, 3}, {5, 6} },         t = {                        data = { {1, 2}, {4, 3}, {5, 6} } } },
    { l = {8, 9},   n = nil, r = { {1, 2}, {4, 3}, {5, 6} },         t = { labels = { "a", "b" }, } },
}

for i = 1, #addLineCsvTests do
    local r = addLineCsvTests[i]
    csv.addLineCSV(r.t, r.l)

    test(compareResult(r.r, r.t, i, "addLineCSV"))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test remLineCSV
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
    local r = remLineCsvTests[i]
    csv.remLineCSV(r.t, r.l)

    test(compareResult(r.r, r.t, i, "remLineCSV"))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test replaceLineCSV
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
    local r = replaceLineCsvTests[i]
    csv.replaceLineCSV(r.t, r.l, r.d)

    test(compareResult(r.r, r.t, i, "replaceLineCSV"))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test dupLineCSV
local dupLineCsvTests = {
    { r = nil, l = nil },
    { r = {},  l = {} },
    { r = { 1, 2, 3}, l = { 1, 2, 3} }
}

for i = 1, #dupLineCsvTests do
    local r = dupLineCsvTests[i]
    local res = csv.dupLineCSV(r.l)

    test(compareVectors(r.r, res, i, "dupLineCSV"))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test getLineCSV
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test logLineCSV
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test tostringCSV
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test tostringCol
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test tostringLine
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test saveCSV
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test addTableDB
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test loadDB
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test addLineDB
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test remLineDB
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test saveDB
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test tostringDB
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local tests, fails = results()
if fails == 0 then
    print("pass: csvTest "..tests.." tests")
else
    print(string.format("fail: csvTest %d tests failed of %d total", fails, tests))
end
