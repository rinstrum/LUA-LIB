#!/usr/local/bin/lua
-------------------------------------------------------------------------------
-- CSV unit tests.
-- @module rinLibrary.tests.csvTest
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local csv = require "rinLibrary.rinCSV"

local tests, fails = 0, 0
local path = "rinLibrary/tests/"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
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
    if x ~= r.res then
        print("escapeCSV fail for @" .. r.val .. "@ giving @"..x.."@ instead of @"..r.res.."@")
        fails = fails + 1
    end
    tests = tests + 1
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
local toCsvTests = {
    { val = { "a", "b", "c" },          res = "a,b,c" },
    { val = { "a ", " b", " c " },      res = "a , b, c " },
    { val = { '"', ',', '"', "xy" },    res = '"""",",","""",xy' }
}

for i = 1, #toCsvTests do
    local r = toCsvTests[i]
    local x = csv.toCSV(r.val, r.w)
    if x ~= r.res then
        print("toCSV fail for line "..i.." giving @"..x.."@ instead of @"..r.res.."@")
        fails = fails + 1
    end
    tests = tests + 1
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
local padCsvTests = {
    { val = { "a", "b", "c" },          res = " a, b, c", w=2 },
    { val = { "a", "b", "c" },          res = "a,b,c", w = nil },
    { val = { "a ", " b", " c " },      res = "  a ,   b,  c ", w=4 },
    { val = { '"', ',', '"', "xy" },    res = '"  ""","  ,","  """, xy', w=3 }
}

for i = 1, #padCsvTests do
    local r = padCsvTests[i]
    local x = csv.padCSV(r.val, r.w)
    if x ~= r.res then
        print("padCSV fail for line "..i.." giving @"..x.."@ instead of @"..r.res.."@")
        fails = fails + 1
    end
    tests = tests + 1
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
local fromCsvTests = {
    { val = "a,b,c",                    res = { "a", "b", "c" } },
    { val = "a , b, c ",                res = { "a ", " b", " c " } },
    { val = '"  ""","  ,","  """, xy',  res = { '  "', '  ,', '  "', " xy" } },
    { val = '""""""""""',               res = { '""""' } }
}

local function compareCsv(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

for i = 1, #fromCsvTests do
    local r = fromCsvTests[i]
    local x = csv.fromCSV(r.val)
    if not compareCsv(r.res, x) then
        print("fromCSV fail for line "..i)
        fails = fails + 1
    end
    tests = tests + 1
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
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
    if r.r ~= csv.equalCSV(r.a, r.b) then
        print("equalCSV fail for line "..i)
        fails = fails + 1
    end
    tests = tests + 1
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
local loadCsvTests = {
    { res = "create",       t={ fname = "nonexist",            labels = {} } },
    { res = "load",         t={ fname = path .. "csvData.csv", labels = { "a", "b" } },       v = {{'1', '2'}, {'3', '4'}} },
    { res = "reordered",    t={ fname = path .. "csvData.csv", labels = { "b", "a" } },       v = {{'2', '1'}, {'4', '3'}} },
    { res = "partial",      t={ fname = path .. "csvData.csv", labels = { "a", "b", "c" } },  v = {{'1', '2', ''}, {'3', '4', ''}} },
    { res = "partial",      t={ fname = path .. "csvData.csv", labels = { "a", "c" } },       v = {{'1', ''}, {'3', ''}} },
    { res = "full",         t={ fname = path .. "csvData.csv", labels = { "a" } },            v = {{'1'}, {'3'}} },
    { res = "immiscable",   t={ fname = path .. "csvData.csv", labels = { "x" } } },
}

local saveSaveCSV = csv.saveCSV
for i = 1, #loadCsvTests do
    local r = loadCsvTests[i]
    local failed = false

    csv.saveCSV = function (t)
                      if t.fname ~= r.t.fname then
                         print("fail: saveCSV bad file name "..t.fname.." (expected "..r.t.fname..")")
                         failed = true
                      end
                  end

    local t, res = csv.loadCSV(r.t)
    if r.res ~= res then
        print("loadCSV fail for line "..i.." result is "..res.." expected "..r.res)
        failed = true
    elseif r.v ~= nil then
        if t.data == nil then
            print("loadCSV fail for line "..i.." table doesn't have data and should")
            failed = true
        elseif #r.v ~= #t.data then
            print("loadCSV fail for line "..i.." mismatch in data rows")
            failed = true
        else
            for j = 1, #t.data do
                if #t.data[j] ~= #r.v[j] then
                    print("loadCSV fail for line "..i.." mismatch in data row length for row "..j)
                    failed = true
                    break
                else
                    for k = 1, #t.data[j] do
                        if t.data[j][k] ~= r.v[j][k] then
                            print("loadCSV fail for line "..i.." in data for ("..j..", "..k.."): "
                                        .. t.data[j][k] .. " expected " .. r.v[j][k])
                            failed = true
                            break
                        end
                    end
                end
            end
        end
    elseif t.data ~= nil then
        print("loadCSV fail for line "..i.." table has data when it shouldn't")
        failed = true
    end
    tests = tests + 1
    if failed then
        fails = fails + 1
    end
end
csv.saveCSV = saveSaveCSV

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
if fails == 0 then
    print("pass: "..tests.." tests")
else
    print(string.format("fail: %d tests failed of %d total", fails, tests))
end
