-------------------------------------------------------------------------------
--- Real Time Clock.
-- Functions to control Real Time Clock
-- @module rinLibrary.Device.RTC
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local date = require 'rinLibrary.date'

local string = string
local tonumber = tonumber
local pairs = pairs
local table = table
local ipairs = ipairs
local unpack = unpack

local monthLength = date.monthLength

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

-------------------------------------------------------------------------------

-- @section clock
-------------------------------------------------------------------------------

--  Time and Date
local REG_TIMECUR           = 0x0150
local REG_TIMEFORMAT        = 0x0151
local REG_TIMEDAY           = 0x0152
local REG_TIMEMON           = 0x0153
local REG_TIMEYEAR          = 0x0154
local REG_TIMEHOUR          = 0x0155
local REG_TIMEMIN           = 0x0156
local REG_TIMESEC           = 0x0157

local REG_MSEC1000          = 0x015C
local REG_MSEC              = 0x015D
local REG_MSECLAST          = 0x015F

--- Registers.
--@table Registers that can be read using @{rinLibrary.Device.Reg.getRegister}.
-- @field msec Millisecond timer from the display
-- @field mseclast Millisecond time when the last ADC reading was taken.
-- @field msec1000 Millisecond timer modulo 1000

--- Date Formats.
--@table DateFormats
-- @field dmy Date formated like 22/02/43
-- @field dmyy Date formated like 22/02/2043
-- @field mdy Date formated like 02/22/43
-- @field mdyy Date formated like 02/22/2043
-- @field ymd Date formated like 43/02/22
-- @field yymd Date formated like 2043/02/22
-- @field ddmmyy Date formated like 22/02/43
-- @field ddmmyyyy Date formated like 22/02/2043
-- @field mmddyy Date formated like 02/22/43
-- @field mmddyyyy Date formated like 02/22/2043
-- @field yymmdd Date formated like 43/02/22
-- @field yyyymmdd Date formated like 2043/02/22

local TM_DDMMYY             = 0
local TM_DDMMYYYY           = 1
local TM_MMDDYY             = 2
local TM_MMDDYYYY           = 3
local TM_YYMMDD             = 4
local TM_YYYYMMDD           = 5

local stringDateMap = {
    ddmmyy      = 0,    dmy     = 0,
    ddmmyyyy    = 1,    dmyy    = 1,
    mmddyy      = 2,    mdy     = 2,
    mmddyyyy    = 3,    mdyy    = 3,
    yymmdd      = 4,    ymd     = 4,
    yyyymmdd    = 5,    yymd    = 6
}

local stringDateMap, stringDateUnmap = {}, {
    [TM_DDMMYY] = 'dmy',
    [TM_DDMMYYYY] = 'dmyy',
    [TM_MMDDYY] = 'mdy',
    [TM_MMDDYYYY] = 'mdyy',
    [TM_YYMMDD] = 'ymd',
    [TM_YYYYMMDD] = 'yymd'
}

local RTC = {
    hour = 0, min = 0, sec = 0,
    day = 1, month = 1, year = 2010,
    load_date = false, load_time = false,
    first = 'day', second = 'month', third = 'year', yearlen = 4
}

for k,v in pairs(stringDateUnmap) do
    local d = { v:sub(1, 1) }
    for i = 2, #v do
        table.insert(d, v:sub(i-1, i))
    end
    table.insert(d, v:sub(-1, -1))

    stringDateMap[v] = k
    stringDateMap[table.concat(d)] = k
end

-------------------------------------------------------------------------------
-- Convert a string or numeric format into a numeric code
-- @param f Date format
-- @return Numeric date format code
-- @local
local function convertStringToFormat(f)
    return naming.convertNameToValue(f, stringDateMap, TM_DDMMYYYY, TM_DDMMYY, TM_YYYYMMDD)
end

-------------------------------------------------------------------------------
-- Convert a string or numeric format into a numeric code
-- @param f Date format
-- @return Numeric date format code
-- @local
local function convertFormatToString(f)
    return naming.convertValueToName(f, stringDateUnmap, 'dmy')
end

-------------------------------------------------------------------------------
-- Decode the numeric format field and set the appropriate ordering
-- @tparam DateFormats fmt Date format (numeric)
-- @local
local function setDateFormat(fmt)
    local _, count = string.gsub(fmt, "Y", "")
    if count > 2 then
      RTC.yearlen = 4
    else
      RTC.yearlen = 2
    end

    if fmt == TM_DDMMYYYY or fmt == TM_DDMMYY then
        date.setDateFormat('day', 'month', 'year', RTC.yearlen)
    elseif fmt == TM_MMDDYYYY or fmt == TM_MMDDYY then
        date.setDateFormat('month', 'day', 'year', RTC.yearlen)
    else
        date.setDateFormat('year', 'month', 'day', RTC.yearlen)
    end
end

-------------------------------------------------------------------------------
-- Read the instrument date format
-- @treturn DateFormats Date format
-- @usage
-- if device.readDateFormat() == 'mdy' then
--     -- American date format
-- end
function _M.readDateFormat()
    local fmt, err = private.readRegDec(REG_TIMEFORMAT)
    local r = err and TM_DDMMYY or tonumber(fmt)
    setDateFormat(r)
    return convertFormatToString(r)
end

-------------------------------------------------------------------------------
-- Set the instrument date format
-- @tparam DateFormats  f Date format
-- @usage
-- -- Set to international date format
-- device.sendDateFormat("ymd")
function _M.sendDateFormat(f)
    local fmt = convertStringToFormat(f)

    private.writeReg(REG_TIMEFORMAT, fmt)
    setDateFormat(fmt)
end

-------------------------------------------------------------------------------
-- Convert RTC fields to numerics
-- @param ... Fields that might need conversion
-- @local
local function RTCtoNumbers(...)
    for _, v in ipairs{...} do
        RTC[v] = tonumber(RTC[v])
    end
end

-------------------------------------------------------------------------------
-- Read Real Time Clock data from instrument into local RTC table
-- @param d 'date' or 'time' to read these fields only, or 'all' for both
-- @local
function private.RTCread(d)
    local d = d or 'all'

    _M.readDateFormat()

    local timestr, err = private.readRegLiteral(REG_TIMECUR)

    if err then
    timestr = '01/01/2000 00-00'
    end
    --dbg.printVar(timestr)

    if d == 'date' or d == 'all' then
        RTC.day, RTC.month, RTC.year =
        string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
        RTC.load_date = true
        RTCtoNumbers('day', 'month', 'year')
    end

    if d == 'time' or d == 'all' then
        _,_,_, RTC.hour, RTC.min =
        string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
        RTC.load_time = true
        RTCtoNumbers('hour', 'min')
    end

    RTC.sec, err = private.readReg(REG_TIMESEC)
    if err then
        RTC.sec = 0
    end
    RTCtoNumbers('sec')
end

-------------------------------------------------------------------------------
-- Force read the RTC but only allow it once and only load the sections that
-- haven't yet been loaded.
-- @local
local function readRTC()
    local d, t = RTC.load_date, RTC.load_time

    if not d and not t then
        private.RTCread('all')
    elseif d and not t then
        private.RTCread('time')
    elseif not d and t then
        private.RTCread('date')
    end
end

-------------------------------------------------------------------------------
-- Write a single RTC register and update the local copy
-- @param r Register to update
-- @param f Value to update it with
-- @param n Name of the field
-- @param l Lowest legal value
-- @param u Highest legal value
-- @local
local function writeRTC(r, f, n, l, u)
    local x = tonumber(f)
    if x ~= nil and x >= l and x <= u then
        private.writeReg(r, x)
        RTC[n] = x
    end
end

-------------------------------------------------------------------------------
-- Write Real Time Clock date to instrument
-- @int[opt] year The year to write or nil to leave unchanged
-- @int[opt] month The month to write or nil to leave unchanged
-- @int[opt] day The day to write or nil to leave unchanged
-- @see RTCwrite
-- @see RTCwriteTime
-- @usage
-- -- Set the date to the reburial of Copernicus.
-- device.RTCwriteDate(2010, 5, 22)
function _M.RTCwriteDate(year, month, day)
    writeRTC(REG_TIMEYEAR,  year,       "year",  2010,   2100)
    writeRTC(REG_TIMEMON,   month,      "month", 1,      12)
    writeRTC(REG_TIMEDAY,   day,        "day",   1,      monthLength(RTC.year, RTC.month))
    RTC.load_date = true
end

-------------------------------------------------------------------------------
-- Write Real Time Clock time to instrument
-- @int[opt] hour The hour to write or nil to leave unchanged
-- @int[opt] minute The minute to write or nil to leave unchanged
-- @int[opt] second The second to write or nil to leave unchanged
-- @see RTCwrite
-- @see RTCwriteDate
-- @usage
-- -- Advance time to 5pm knock off
-- device.RTCwriteTime(17, 0, 0)
function _M.RTCwriteTime(hour, minute, second)
    writeRTC(REG_TIMESEC,   second,     "sec",   0,      59)
    writeRTC(REG_TIMEMIN,   minute,     "min",   0,      59)
    writeRTC(REG_TIMEHOUR,  hour,       "hour",  0,      23)
    _M.flush()
    RTC.load_time = true
end

-------------------------------------------------------------------------------
-- Write Real Time Clock date and time to instrument
-- @int[opt] year The year to write or nil to leave unchanged
-- @int[opt] month The month to write or nil to leave unchanged
-- @int[opt] day The day to write or nil to leave unchanged
-- @int[opt] hour The hour to write or nil to leave unchanged
-- @int[opt] minute The minute to write or nil to leave unchanged
-- @int[opt] second The second to write or nil to leave unchanged
-- @see RTCwriteTime
-- @see RTCwriteDate
-- @usage
-- -- Set the date and time to 11:59:59 pm on the 29th of February 2012
-- device.RTCwrite(2012, 2, 29, 23, 59, 59)
function _M.RTCwrite(year, month, day, hour, minute, second)
    _M.RTCwriteTime(hour, minute, second)
    _M.RTCwriteDate(year, month, day)
end

-------------------------------------------------------------------------------
-- Return the current date
-- @treturn int year
-- @treturn int month
-- @treturn int day
-- @see RTCreadTime
-- @see RTCwriteDate
-- @usage
-- local year, month, day = device.RTCreadDate()
function _M.RTCreadDate()
    readRTC()
    return RTC.year, RTC.month, RTC.day
end

-------------------------------------------------------------------------------
-- Return the current time
-- @treturn int hours
-- @treturn int minutes
-- @treturn int seconds
-- @see RTCreadDate
-- @see RTCwriteTime
-- @usage
-- local hours, minutes, seconds = device.RTCreadTime()
function _M.RTCreadTime()
    readRTC()
    return RTC.hour, RTC.min, RTC.sec
end

-------------------------------------------------------------------------------
-- Called every second to update local RTC
-- @local
function private.RTCtick()
    RTC.sec = RTC.sec + 1
    if RTC.sec > 59 then
        RTC.sec = 0
        RTC.min = RTC.min + 1
        if RTC.min > 59 then
            RTC.min = 0
            RTC.hour = RTC.hour + 1
            if RTC.hour > 23 then
                RTC.hour = 0
                private.RTCread()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Returns formated date string
-- @treturn string Formatted date string
-- @see RTCtime
-- @see RTCtostring
-- @usage
-- print(device.RTCdate())
function _M.RTCdate()
    return date.formatDate(RTC.year, RTC.month, RTC.day)
end

-------------------------------------------------------------------------------
-- Returns formated time string
-- @int[opt] timeFormat Either '12' or '24' to set the time format, default 24.
-- @treturn string Formatted time string
-- @see RTCdate
-- @see RTCtostring
-- @usage
-- print(device.RTCtime(12))
function _M.RTCtime(timeFormat)
    local h, suffix = RTC.hour, ''
    local f = tonumber(timeFormat or 24) or 24

    if f == 12 then
        suffix = (h < 12) and ' AM' or ' PM'
        h = (h == 0) and 12 or ((h > 12) and (h-12) or h)
    end
    return string.format("%02d:%02d:%02d%s", h, RTC.min, RTC.sec, suffix)
end

-------------------------------------------------------------------------------
-- Returns formated date/time string
-- @int[opt] timeFormat Either '12' or '24' to set the time format, default 24.
-- @treturn string Formatted date and time string
-- @see RTCtime
-- @see RTCdate
-- @usage
-- print(device.RTCtostring(24))
function _M.RTCtostring(timeFormat)
    return _M.RTCdate() .. ' ' .. _M.RTCtime(timeFormat)
end

-------------------------------------------------------------------------------
-- Save the bottom of the display, clear the bottom and return the
-- restoration function
-- @local
local function editSave()
    local restore = _M.saveBottom()
    _M.write('bottomLeft', '')
    _M.write('bottomRight', '')
    return restore
end

-------------------------------------------------------------------------------
-- Edit time and date settings returning the new values.
-- @param flds The fields to be edited with default values
-- @return values for the fields
-- @see addTimeFields
-- @see addDateFields
-- @local
local function editTimeOrDate(flds)
    local restore, args = editSave(), {}

    for _, v in ipairs(flds) do
        local x, ok = _M.edit(v[1], v[2], 'integer')
        if not ok then
            restore()
            return
        end
        table.insert(args, x)
    end
    restore()
    return unpack(args)
end

-------------------------------------------------------------------------------
-- Add the time fields to the argument list for editTimeOrDate
-- @param args Existing argument list
-- @param seconds Boolean indicating if seconds should be prompted for
-- @return args
-- @see editTimeOrDate
-- @local
local function addTimeFields(args, seconds)
    local hr, mi, se = _M.RTCreadTime()
    table.insert(args, { 'HOUR?',  hr })
    table.insert(args, { 'MIN?',   mi })
    if seconds then
        table.insert(args, { 'SEC?', se })
    end
    return args
end

-------------------------------------------------------------------------------
-- Add the date fields to the argument list for editTimeOrDate
-- @param args Existing argument list
-- @return args
-- @see editTimeOrDate
-- @local
local function addDateFields(args)
    local yr, mo, da = _M.RTCreadDate()
    table.insert(args, { 'DAY?',   da })
    table.insert(args, { 'MONTH?', mo })
    table.insert(args, { 'YEAR?',  yr })
    return args
end

-------------------------------------------------------------------------------
-- Present the user a wizard that lets them set the time on the device
-- @bool[opt] seconds True if seconds should be prompted for or false if
-- seconds should just be left alone.  By default, seconds are not edited.
-- @treturn bool true
-- @usage
-- device.editTime()
function _M.editTime(seconds)
    local args = addTimeFields({}, seconds)
    _M.RTCwriteTime(editTimeOrDate(args))
    return true
end

-------------------------------------------------------------------------------
-- Present the user a wizard that lets them set the date on the device
-- @treturn bool true
-- @usage
-- device.editDate()
function _M.editDate()
    local args = addDateFields{}
    _M.RTCwriteDate(editTimeOrDate(args))
    return true
end

-------------------------------------------------------------------------------
-- Present the user a wizard that lets them set the time and date on the device
-- @bool[opt] seconds True if seconds should be prompted for or false if
-- seconds should just be left alone.  By default, seconds are not edited.
-- @treturn bool true
-- @usage
-- -- Set up a call back to map a long press of 1 to the set date functionality
-- device.setKeyCallback(1, function() return device.editTimeDate() end, 'long')
function _M.editTimeDate(seconds)
    local args = addTimeFields(addDateFields{}, seconds)
    local da, mo, yr, hr, mi, se = editTimeOrDate(args)
    _M.RTCwrite(yr, mo, da, hr, mi, se or 0)
    return true
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Expose some internals for testing purposes
if _TEST then
    _M.monthLength = monthLength
    _M.setDateFormat = setDateFormat
    _M.rtc = RTC
    deprecated.TM_DDMMYY = TM_DDMMYY
    deprecated.TM_DDMMYYYY = TM_DDMMYYYY
    deprecated.TM_MMDDYY = TM_MMDDYY
    deprecated.TM_MMDDYYYY = TM_MMDDYYYY
    deprecated.TM_YYMMDD = TM_YYMMDD
    deprecated.TM_YYYYMMDD = TM_YYYYMMDD
end

end
