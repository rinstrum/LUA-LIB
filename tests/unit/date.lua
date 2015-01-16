-------------------------------------------------------------------------------
-- Date unit tests.
-- @author Pauli
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe('Date tests #date', function()
    local dbg = require "rinLibrary.rinDebug"
    local date = require 'rinLibrary.date'

    -- test day of week
    describe('day of week #dow', function()
        local dowtests = {
            { res = { 5, 'Friday', 'FRI'}, date = { 2015, 1, 16 } },
            { res = { 5, 'Friday', 'FRI'}, date = { 1752, 9, 15 } },
            { res = { 2, 'Tuesday', 'TUE'}, date = { 1752, 9, 1 } },
        }

        for i = 1, #dowtests do
            it('test '..i, function()
                local r = dowtests[i]
                assert.same(r.res, { date.dayOfWeek(unpack(r.date)) })
            end)
        end
    end)

    -- test lengths of months
    describe('length of month #monlen', function()
        local monlengths = {
            { res = 31, date = { 2015, 1 } },
            { res = 28, date = { 1900, 2 } },
            { res = 29, date = { 2000, 2 } },
            { res = 19, date = { 1752, 9 } },
            { res = 29, date = { 1300, 2 } },
            { res = 29, date = { 2000, 2 } },
            { res = 28, date = { 1900, 2 } },
            { res = 28, date = { 1800, 2 } },
            { res = 29, date = { 1700, 2 } },   -- Julian Calendar here
            { res = 29, date = { 1600, 2 } },
            { res = 29, date = { 1004, 2 } },
            { res = 31, date = {  999, 1 } },
            { res = 31, date = { 2000, 3 } },
            { res = 30, date = { 1003, 4 } },
            { res = 31, date = { 2654, 5 } },
            { res = 30, date = { 9999, 6 } },
            { res = 31, date = {    1, 7 } },
            { res = 31, date = { 1999, 8 } },
            { res = 30, date = { 2014, 9 } },
            { res = 31, date = { 2015, 10 } },
            { res = 30, date = { 2016, 11 } },
            { res = 31, date = { 2016, 12 } }
        }

        for i = 1, #monlengths do
            it('test '..i, function()
                local r = monlengths[i]
                assert.equal(r.res, date.monthLength(unpack(r.date)))
            end)
        end
    end)

    describe("month lengths #monlen", function()
        local tc = {
        }

        for k,t in ipairs(tc) do
            it("test "..k, function()
                assert.equal(t.r, makeModule().monthLength(t.y, t.m))
            end)
        end
    end)


    -- test names of months
    describe('names of month #monlen', function()
        local monnames = {
            { res = { 'April', 'APR' }, m = 4 },
            { res = { 'February', 'FEB' }, m = 2 },
            { res = { 'December', 'DEC' }, m = 12 },
        }

        for i = 1, #monnames do
            it('test '..i, function()
                local r = monnames[i]
                assert.same(r.res, { date.monthName(r.m) })
            end)
        end
    end)

    -- test for leap years
    describe('leap years #leap', function()
        local leapyears = {
            { res = true,  y = 2000 },
            { res = false, y = 1900 },
            { res = true,  y = 2016 },
            { res = false, y = 1800 },
            { res = true,  y = 1700 },
        }

        for i = 1, #leapyears do
            it('test '..i, function()
                local r = leapyears[i]
                assert.same(r.res, date.isLeapYear(r.y))
            end)
        end
    end)

    -- test for delay days
    describe('days between dates #days', function()
        local ddays = {
            { res = 31,     dates = { 1900,  1,  1,     1900,  2,  1 } },
            { res = 0,      dates = { 1960,  6, 13,     1960,  6, 13 } },
            { res = -31,    dates = { 1900,  2,  1,     1900,  1,  1 } },
            { res = 366,    dates = { 2000,  1,  1,     2001,  1,  1 } },
            { res = 36524,  dates = { 1900,  1,  1,     2000,  1,  1 } },
            { res = 36525,  dates = { 2000,  1,  1,     2100,  1,  1 } },
            { res = 355,    dates = { 1752,  1,  1,     1753,  1,  1 } },
            { res = 365,    dates = { 1582,  1,  1,     1583,  1,  1 } },
        }

        for i = 1, #ddays do
            it('test '..i, function()
                local r = ddays[i]
                assert.same(r.res, date.deltaDays(unpack(r.dates)))
            end)
        end
    end)

    -- test for addition and subtraction of days
    describe('add days #add', function()
        local adays = {
            { res = { 1950, 3, 7 },     a = { 1950, 3, 1,    6  } },
            { res = { 1950, 3, 7 },     a = { 1950, 3, 9,   -2  } },
            { res = { 2001, 2, 9 },     a = { 2000, 2, 10,  365 } },
            { res = { 1901, 2, 9 },     a = { 1900, 2, 9,   365 } },
        }

        for i = 1, #adays do
            it('test '..i, function()
                local r = adays[i]
                assert.same(r.res, { date.addDays(unpack(r.a))})
            end)
        end
    end)

    -- test for reformation settings
    describe('reformation changes #reformation', function()
        local function yr(n)
            return { n, 1, 1, n+1, 1, 1 }
        end
        local ref = {
            { res = 355,    change = {'british'},       dates = yr(1752) },
            { res = 365,    change = {'british'},       dates = yr(1582) },
            { res = 366,    change = {'european'},      dates = yr(1752) },
            { res = 355,    change = {'european'},      dates = yr(1582) },
            { res = 354,    change = {'japan'},         dates = yr(1872) },
            { res = 354,    change = { 1750,  2,  2 },  dates = yr(1750) },
            { res = 366,    change = {'julian'},        dates = yr(9900) },
            { res = 365,    change = {'china'},         dates = yr(9900) },
            { res = 365,    change = {'british'},       dates = yr(2100) },
       }

        for i = 1, #ref do
            it('test '..i, function()
                local r = ref[i]
                date.setReformation(unpack(r.change))
                assert.same(r.res, date.deltaDays(unpack(r.dates)))
            end)
        end
    end)

    it("format", function()
        local yr, mo, da = 2022, 1, 2
        date.setDateFormat('month', 'day', 'year')
        assert.is_equal("01/02/2022", date.formatDate(yr, mo, da))
        assert.is_same({ "month", "day", "year" }, {date.getDateFormat()})

        date.setDateFormat('year', 'month', 'day')
        assert.is_equal("2022/01/02", date.formatDate(yr, mo, da))
        assert.is_same({ "year", "month", "day" },  {date.getDateFormat()})

        date.setDateFormat('day', 'month', 'year')
        assert.is_equal("02/01/2022", date.formatDate(yr, mo, da))
        assert.is_same({ "day", "month", "year" }, {date.getDateFormat()})
    end)
end)
