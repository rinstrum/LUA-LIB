-------------------------------------------------------------------------------
--- Real Time Clock.
-- Functions to control Real Time Clock
-- @module rinLibrary.K400RTC
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local tonumber = tonumber
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'

-------------------------------------------------------------------------------
-- Return the length of a month in a given year
-- @param y Year
-- @param m Month
-- @return The number of days in the month
-- @local
local function monthLength(y, m)
    if m ~= 2 then
        return ({ 31, nil, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[m]
    end

    if y%4 == 0 and (y%100 ~= 0 or y%400 == 0) then
        return 29
    end
    return 28
end

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
--@table Registers
-- @field msec Millisecond timer from the display
-- @field mseclast Millisecond time when the last ADC reading was taken.
-- @field msec1000 Millisecond timer modulo 1000

--- Date Formats.
--@table Date Formats
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

local RTC = {
    hour = 0, min = 0, sec = 0,
    day = 1, month = 1, year = 2010,
    load_date = false, load_time = false,
    first = 'day', second = 'month', third = 'year'
}

local stringDateMap, stringDateUnmap = {}, {
    [TM_DDMMYY] = 'dmy',
    [TM_DDMMYYYY] = 'dmyy',
    [TM_MMDDYY] = 'mdy',
    [TM_MMDDYYYY] = 'mdyy',
    [TM_YYMMDD] = 'ymd',
    [TM_YYYYMMDD] = 'yymd'
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
-- @param fmt Date format (numeric)
-- @local
local function setDateFormat(fmt)
    if fmt == TM_DDMMYYYY or fmt == TM_DDMMYY then
        _M.RTCdateFormat('day', 'month', 'year')
    elseif fmt == TM_MMDDYYYY or fmt == TM_MMDDYY then
        _M.RTCdateFormat('month', 'day', 'year')
    else
        _M.RTCdateFormat('year', 'month', 'day')
    end
end

-------------------------------------------------------------------------------
-- Read the instrument date format
-- @return Date format ('dmy', 'ymd', 'mdy', 'dmyy', 'yymd' or 'mdyy')
-- @see sendDateFormat
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
-- @param f Date format ('dmy', 'ymd', 'mdy', 'dmyy', 'yymd' or 'mdyy')
-- @see readDateFormat
-- @usage
-- -- Set to international date format
-- device.sendDateFormat("ymd")
function _M.sendDateFormat(f)
    local fmt = convertStringToFormat(f)

    private.writeReg(REG_TIMEFORMAT, fmt)
    setDateFormat(fmt)
end

-------------------------------------------------------------------------------
-- Read Real Time Clock data from instrument into local RTC table
-- @param d 'date' or 'time' to read these fields only, or 'all' for both
-- @usage
-- -- Load the RTC time settings from the display device
-- device.RTCread('time')
--
-- -- Load the RTC settings from the display device
-- device.RTCread('all')
function _M.RTCread(d)
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
  end

  if d == 'time' or d == 'all' then
    _,_,_, RTC.hour, RTC.min =
      string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
    RTC.load_time = true
  end

  RTC.sec, err = private.readReg(REG_TIMESEC)

  if err then
    RTC.sec = 0
  end
end

-------------------------------------------------------------------------------
-- Force read the RTC but only allow it once and only load the sections that
-- haven't yet been loaded.
-- @local
local function readRTC()
    local d, t = RTC.load_date, RTC.load_time

    if not d and not t then
        _M.RTCread('all')
    elseif d and not t then
        _M.RTCread('time')
    elseif not d and t then
        _M.RTCread('date')
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
-- @param year The year to write or nil to leave unchanged
-- @param month The month to write or nil to leave unchanged
-- @param day The day to write or nil to leave unchanged
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
-- @param hour The hour to write or nil to leave unchanged
-- @param minute The minute to write or nil to leave unchanged
-- @param second The second to write or nil to leave unchanged
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
-- @param year The year to write or nil to leave unchanged
-- @param month The month to write or nil to leave unchanged
-- @param day The day to write or nil to leave unchanged
-- @param hour The hour to write or nil to leave unchanged
-- @param minute The minute to write or nil to leave unchanged
-- @param second The second to write or nil to leave unchanged
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
-- @return year
-- @return month
-- @return day
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
-- @return hours
-- @return minutes
-- @return seconds
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
                _M.RTCread()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Returns formated date/time string
-- @see RTCdateFormat
-- @usage
-- print(device.RTCtostring())
function _M.RTCtostring()
    return string.format("%02d/%02d/%02d %02d:%02d:%02d",
                        RTC[RTC.first],
                        RTC[RTC.second],
                        RTC[RTC.third],
                        RTC.hour,
                        RTC.min,
                        RTC.sec)
end

-------------------------------------------------------------------------------
-- Sets the order of the date string
-- @param first  = 'day', 'month' or 'year'
-- @param second  = 'day', 'month' or 'year'
-- @param third = 'day','month' or 'year'
-- @see RTCgetDateFormat
-- @usage
-- -- Set the current date format to year then day then month
-- -- This isn't written to back to the display and is only
-- -- used for formatting output.
-- device.RTCdateFormat('year', 'day', 'month')
function _M.RTCdateFormat(first,second,third)
    local first = first or 'day'
    local second = second or 'month'
    local third = third or 'year'

    local check = { day = 0, month = 0, year = 0 }
    check[first] = check[first] + 1
    check[second] = check[second] + 1
    check[third] = check[third] + 1

    if check.day == 1 and check.month == 1 and check.year == 1 then
        RTC.first = first
        RTC.second = second
        RTC.third = third
    else
        dbg.warn('K400: illegal date format specified:', first, second, third)
    end
end

-------------------------------------------------------------------------------
-- Gets the order of the date string
-- @return first field
-- @return second field
-- @return third field
-- @see RTCdateFormat
-- @usage
-- local first, second, third = device.RTCgetDateFormat()
-- if first == 'year' and second == 'day' and third == 'month' then
--     print('Someone is being silly with the date formatting')
-- end
function _M.RTCgetDateFormat()
    return RTC.first, RTC.second, RTC.third
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_TIMECUR      = REG_TIMECUR
deprecated.REG_TIMEFORMAT   = REG_TIMEFORMAT
deprecated.REG_TIMEDAY      = REG_TIMEDAY
deprecated.REG_TIMEMON      = REG_TIMEMON
deprecated.REG_TIMEYEAR     = REG_TIMEYEAR
deprecated.REG_TIMEHOUR     = REG_TIMEHOUR
deprecated.REG_TIMEMIN      = REG_TIMEMIN
deprecated.REG_TIMESEC      = REG_TIMESEC
deprecated.REG_MSEC1000     = REG_MSEC1000 
deprecated.REG_MSEC         = REG_MSEC   
deprecated.REG_MSECLAST     = REG_MSECLAST
deprecated.TM_DDMMYY        = TM_DDMMYY
deprecated.TM_DDMMYYYY      = TM_DDMMYYYY
deprecated.TM_MMDDYY        = TM_MMDDYY
deprecated.TM_MMDDYYYY      = TM_MMDDYYYY
deprecated.TM_YYMMDD        = TM_YYMMDD
deprecated.TM_YYYYMMDD      = TM_YYYYMMDD

deprecated.RTC = RTC


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Expose some internals for testing purposes
if _TEST then
    _M.monthLength = monthLength
    _M.setDateFormat = setDateFormat
    _M.rtc = RTC
    _M.RTCtick = private.RTCtick
end

end
