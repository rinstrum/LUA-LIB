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
-- of the tests directly attempt to alter them.  Return true if the test passes.
local test, results = (
    function ()
        local tests, fails = 0, 0
        local prevName, prevLine, prevFail = nil, nil, false

        local function t(passed, name, line, msg)
            if name ~= prevName or line ~= prevLine then
                prevFail = false
                prevName, prevLine = name, line
                tests = tests + 1
            end

            if not passed then
                local t = { name }
                if line ~= nil then
                    table.insert(t, " fail for line ")
                    table.insert(t, line)
                end
                if msg ~= nil then
                    table.insert(t, " ")
                    table.insert(t, msg)
                end
                print(table.concat(t))
                if not prevFail then
                    fails = fails + 1
                    prevFail = true
                end
            end
            return passed
        end

        local function r()
            return tests, fails
        end

        return t, r
    end
) ()

--local test, results = testresultfunctions()

-- Utility function to compare two vectors for inequality
local function compareVectors(expected, result, i, name)
    if expected == nil then
        return test(result == nil, name, i, "result not nil")
    else
        if test(#expected == #result, name, i, "wrong number of rows") then
            return false
        end
        for j = 1, #result do
            if test(expected[j] == result[j], name, i, "bad value row "..j) then
                return false
            end
        end
    end
    return true
end

-- Utility function to compare a data table against a CSV table for inequality
local function compareResult(expected, t, i, name)
    if expected == nil then
        return test(t.data == nil, name, i, "result not nil")
    end
    if t.data ~= nil then
        if test(#expected == #t.data, name, i, "wrong number of rows") then
            return false
        elseif t.labels ~= nil then
            for j = 1, #expected do
                if      test(t.data[j] ~= nil, name, i, "no data row "..j) or
                        test(#expected[j] == #t.data[j], name, i, "uneven data row "..j) then
                    return false
                end
                for k = 1, #t.labels do
                    if test(expected[j][k] == t.data[j][k], name, i, "bad element ("..j..", "..k..")".." got "..t.data[j][k].." expected "..expected[j][k]) then
                        return false
                    end
                end
            end
        end
    end
    return true
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test escapeCSV
local escapeTests = {
    { val = 'abc',      res = 'abc' },
    { val = 'abc,def',  res = '"abc,def"' },
    { val = "abc'def",  res = "abc'def" },
    { val = 'abc"def',  res = '"abc""def"' },
    { val = '',         res = '' },
    { val = nil,        res = nil }
}

for i = 1, #escapeTests do
    local r = escapeTests[i]
    local x = csv.escapeCSV(r.val)

    test(x == r.res, "escapeCSV", i, "giving "..tostring(x).." instead of "..tostring(r.res))
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

    test(x == r.res, "toCSV", i, "giving @"..x.."@ instead of @"..r.res.."@")
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

    test(x == r.res, "padCSV", i, "giving @"..x.."@ instead of @"..r.res.."@")
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

for i = 1, #fromCsvTests do
    local r = fromCsvTests[i]
    local x = csv.fromCSV(r.val)

    compareVectors(r.res, x, i, "fromCSV")
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

    test(r.r == csv.equalCSV(r.a, r.b), "equalCSV", i, "")
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test loadCSV
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

local saveSaveCSV = csv.saveCSV
for i = 1, #loadCsvTests do
    local r = loadCsvTests[i]
    local failed = false
    local saveCalled = false

    csv.saveCSV = function (t)
                      test(t.fname == r.t.fname, "loadCSV", i, "saveCSV bad file name "..t.fname.." (expected "..r.t.fname..")")
                      saveCalled = true
                  end

    local t, res = csv.loadCSV(r.t)

    test(saveCalled == r.s, "loadCSV", i, "save function anomoly")
    if test(r.res == res, "loadCSV", i, "result is "..res.." expected "..r.res) then
        if r.v ~= nil then
            compareResult(r.v, r.t, i, "loadCSV")
        else
            test(t.data == nil, "loadCSV", i, " table has data when it shouldn't")
        end
    end
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

    if  test(r.rows == rows, "numRowsCSV", i, "got "..rows.." instead of "..r.rows) then
        test(r.cols == cols, "numColsCSV", i, "got "..cols.." instead of "..r.cols)
    end
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

    test(col == r.r, "labelCol", i, "got "..tostring(col).." instead of "..tostring(r.r))
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

    compareVectors(r.r, col, i, "getColCSV")
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

    compareResult(r.r, r.t, i, "addLineCSV")
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

    compareResult(r.r, r.t, i, "remLineCSV")
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

    compareResult(r.r, r.t, i, "replaceLineCSV")
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

    compareVectors(r.r, res, i, "dupLineCSV")
    compareVectors(r.r, r.l, i, "dupLineCSV_unchanged")
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test tostringCol
local tostringColTests = {
    { r = nil,                  c = nil         },
    { r = "",                   c = {}          },
    { r = "1\r\n2\r\n3\r\n",    c = { 1, 2, 3}  },
    { r = "1\r\n",              c = { 1 }       }
}

for i = 1, #tostringColTests do
    local r = tostringColTests[i]
    local res = csv.tostringCol(r.c)

    test(r.r == res, "tostringCol", i, "giving "..tostring(res).." instead of "..tostring(r.r))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test tostringLine
local tostringLineTests = {
    { r = nil,                                  c = nil                     },
    { r = "",                                   c = {}                      },
    { r = "         1,         2,         3",   c = { 1, 2, 3}              },
    { r = "         1",                         c = { 1 }                   },
    { r = "  1,  3",                            c = { 1, 3 },       w = 3   },
}

for i = 1, #tostringLineTests do
    local r = tostringLineTests[i]
    local res = csv.tostringLine(r.c, r.w)

    test(r.r == res, "tostringLine", i, "giving "..tostring(res).." instead of "..tostring(r.r))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test getLineCSV
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test logLineCSV
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test tostringCSV
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
