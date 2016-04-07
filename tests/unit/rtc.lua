-------------------------------------------------------------------------------
-- RTC unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local date = require 'rinLibrary.date'

describe("RTC #rtc", function ()
    local dmy, dmyy, mdy, mdyy, ymd, yymd = 0, 1, 2, 3, 4, 5
    local dregs = {
        timecur          = 0x0150,
        timeformat       = 0x0151,
        timeday          = 0x0152,
        timemon          = 0x0153,
        timeyear         = 0x0154,
        timehour         = 0x0155,
        timemin          = 0x0156,
        timesec          = 0x0157,
        msec1000         = 0x015C,
        msec             = 0x015D,
        mseclast         = 0x015F
    }

    local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.K400RTC")(m, p, d)
        m.flushed = 0
        m.flush = function() m.flushed = m.flushed + 1 end
        return m, p, d
    end

    it("enumerations", function()
        local _, _, d = makeModule()
        assert.equal(dmy,   d.TM_DDMMYY)
        assert.equal(dmyy,  d.TM_DDMMYYYY)
        assert.equal(mdy,   d.TM_MMDDYY)
        assert.equal(mdyy,  d.TM_MMDDYYYY)
        assert.equal(ymd,   d.TM_YYMMDD)
        assert.equal(yymd,  d.TM_YYYYMMDD)
    end)

    local function makeResults(yr, mo, da, ho, mi, se)
        local results = {}
        if yr ~= nil then table.insert(results, { r=dregs.timeyear, yr }) end
        if mo ~= nil then table.insert(results, { r=dregs.timemon,  mo }) end
        if da ~= nil then table.insert(results, { r=dregs.timeday,  da }) end
        if ho ~= nil then table.insert(results, { r=dregs.timehour, ho }) end
        if mi ~= nil then table.insert(results, { r=dregs.timemin,  mi }) end
        if se ~= nil then table.insert(results, { r=dregs.timesec,  se }) end
        return results
    end

    describe("set date #setdate", function()
        local z = require "tests.messages"
        for k, v in pairs({
                        { 2000, 12, 5,  nil, 12, 5 },   { 2020, 2, 29,  2020, 2, 29 },
                        { 2200, 15, 1,  nil, nil, 1 },  { 2015, 2, 28,  2015, 2, 28 }
                    }) do
            it("test "..k, function()
                local sy, sm, sd = v[1], v[2], v[3]
                local ey, em, ed = v[4], v[5], v[6]
                local results = makeResults(ey, em, ed)
                local m = makeModule()

                z.checkWriteReg(m, results, m.RTCwriteDate, sy, sm, sd)
            end)
        end
    end)

    describe("set time #settime", function()
        local z = require "tests.messages"
        for k, v in pairs({
                        { 3, 30, 2,     3, 30, 2},  { 25, 66, 23,   nil, nil, 23 },
                        { 7, 23, 66,    7, 23, nil }
                    }) do
            it("test "..k, function()
                local sh, sm, ss = v[1], v[2], v[3]
                local eh, em, es = v[4], v[5], v[6]
                local results = makeResults(nil, nil, nil, eh, em, es)
                local m = makeModule()

                z.checkWriteReg(m, results, m.RTCwriteTime, sh, sm, ss)
                assert.is_equal(1, m.flushed)
            end)
        end
    end)

    describe("set all #settimedate", function()
        local z = require "tests.messages"
        for k, v in pairs({
                    { 2038, 1, 19, 3, 14, 8 },
                    { 2020, 5, 22, 12, 6, 14 }
                }) do
            it("test "..k, function()
                local yr, mo, da, ho, mi, se = v[1], v[2], v[3], v[4], v[5], v[6]
                local results = makeResults(unpack(v))
                local m = makeModule()

                z.checkWriteReg(m, results, m.RTCwrite, unpack(v))
                assert.is_same({ yr, mo, da, n=3 }, table.pack(m.RTCreadDate()))
                assert.is_same({ ho, mi, se, n=3 }, table.pack(m.RTCreadTime()))
                assert.is_equal(1, m.flushed)
            end)
        end
    end)

    it("tick", function()
        local z = require "tests.messages"
        local m, p = makeModule()
        local yr, mo, da, ho, mi, se = 2050, 3, 6, 22, 59, 59
        local results = makeResults(yr, mo, da, ho, mi, se)

        z.checkWriteReg(m, results, m.RTCwrite, yr, mo, da, ho, mi, se)
        p.RTCtick()
        assert.is_same({ yr, mo, da, n=3 }, table.pack(m.RTCreadDate()))
        assert.is_same({ 23, 0, 0, n=3 }, table.pack(m.RTCreadTime()))
        assert.is_equal(1, m.flushed)
    end)

    it("format", function()
        local z = require "tests.messages"
        local m, _, d = makeModule()
        local yr, mo, da, ho, mi, se = 2022, 1, 2, 3, 4, 5
        local results = makeResults(yr, mo, da, ho, mi, se)
  
        date.setDateFormat('day', 'month', 'year', 4)
        z.checkWriteReg(m, results, m.RTCwrite, yr, mo, da, ho, mi, se)
        assert.is_equal(1, m.flushed)
        assert.is_same({ yr, mo, da, n=3 }, table.pack(m.RTCreadDate()))
        assert.is_same({ ho, mi, se, n=3 }, table.pack(m.RTCreadTime()))
        assert.is_same({ "day", "month", "year", 4}, {date.getDateFormat()})
        assert.is_equal("02/01/2022 03:04:05", m.RTCtostring())

        date.setDateFormat('month', 'day', 'year', 4)
        assert.is_same({ yr, mo, da, n=3 }, table.pack(m.RTCreadDate()))
        assert.is_same({ ho, mi, se, n=3 }, table.pack(m.RTCreadTime()))
        assert.is_equal("01/02/2022 03:04:05", m.RTCtostring())
        assert.is_same({ "month", "day", "year", 4 }, {date.getDateFormat()})

        date.setDateFormat('year', 'month', 'day', 4)
        assert.is_equal("2022/01/02 03:04:05", m.RTCtostring())
        assert.is_same({ "year", "month", "day", 4 }, {date.getDateFormat()})

        date.setDateFormat('day', 'month', 'year', 4)
        assert.is_equal("02/01/2022 03:04:05", m.RTCtostring())
        assert.is_same({ "day", "month", "year", 4 }, {date.getDateFormat()})
    end)

    describe("time format #time12", function()
        local z = require "tests.messages"
        for k, v in pairs{
            { t = {  3, 30, 2}, f = 12,     r = '03:30:02 AM' },
            { t = {  3, 30, 2}, f = 24,     r = '03:30:02'    },
            { t = {  3, 30, 2},             r = '03:30:02'    },
            { t = { 23, 30, 2}, f = 12,     r = '11:30:02 PM' },
            { t = { 23, 30, 2},             r = '23:30:02'    },
            { t = {  0, 30, 2}, f = 12,     r = '12:30:02 AM' },
            { t = {  0, 30, 2}, f = 24,     r = '00:30:02'    },
            { t = { 13, 30, 2}, f = 12,     r = '01:30:02 PM' },
            { t = { 13, 30, 2},             r = '13:30:02'    }
        } do
            it("test "..k, function()
                local h, m, s = unpack(v.t)
                local results = makeResults(nil, nil, nil, h, m, s)
                local md = makeModule()

                z.checkWriteReg(md, results, md.RTCwriteTime, h, m, s)
                assert.is_equal(1, md.flushed)
                assert.is_same(v.r, md.RTCtime(v.f))
            end)
        end
    end)

    it("rtc read", function()
        pending("unimplemented test case")
    end)

    it("rtc read date format", function()
        pending("unimplemented test case")
    end)

    it("rtc send date format", function()
        pending("unimplemented test case")
    end)
end)
