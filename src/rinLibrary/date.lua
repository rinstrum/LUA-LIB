-------------------------------------------------------------------------------
-- Functions for working with dates
-- @module rinLibrary.date
-- @author Pauli
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local ukGregorian = true
local namings = require 'rinLibrary.namings'

local floor = math.floor

local weekDays = {
    { 'Monday',     'MON' },
    { 'Tuesday',    'TUE' },
    { 'Wednesday',  'WED' },
    { 'Thursday',   'THU' },
    { 'Friday',     'FRI' },
    { 'Saturday',   'SAT' },
    { 'Sunday',     'SUN' }
}

local months = {
    { 'January',    'JAN' },
    { 'February',   'FEB' },
    { 'March',      'MAR' },
    { 'April',      'APR' },
    { 'May',        'MAY' },
    { 'June',       'JUN' },
    { 'July',       'JUL' },
    { 'August',     'AUG' },
    { 'September',  'SEP' },
    { 'October',    'OCT' },
    { 'November',   'NOV' },
    { 'December',   'DEC' }
}

local reformationDates = {
    british     = { 1752,  9,  2 },
    european    = { 1582, 10,  4 },

    austria     = { 1583, 10,  5 },
    bulgaria    = { 1916,  3, 31 },
    canada      = { 1752,  9,  2 },
    china       = { 1912, 12, 18 },
    england     = { 1752,  9,  2 },
    estonia     = { 1918,  1, 31 },
    france      = { 1582, 12,  9 },
    germany     = { 1582, 12, 31 },
    greece      = { 1923,  2, 15 },
    hungary     = { 1587, 10, 21 },
    italy       = { 1582, 10,  4 },
    japan       = { 1872, 12, 19 },
    korea       = { 1894, 12, 19 },
    poland      = { 1582, 10,  4 },
    portugal    = { 1582, 10,  4 },
    prussia     = { 1610,  8, 22 },
    russia      = { 1918,  1, 31 },
    spain       = { 1582, 10,  4 },
    turkey      = { 1926, 12, 18 },
    usa         = { 1752,  9,  2 }
}

local gregorianChange, gregorianFirstDay
local date_first, date_second, date_third = 'day', 'month', 'year'

-------------------------------------------------------------------------------
-- Test if a date is from the Gregorian or Julian calendar.
-- @param year Year of interest
-- @param month Month in year
-- @param day Day in month
-- @return True if the date is from the Gregorian calendar
-- @local
local function isGregorian(year, month, day)
    local y, m, d = unpack(gregorianChange)
--    local y = ukGregorian and 1752 or 1582
--    local m = ukGregorian and 9 or 10
--    local d = ukGregorian and 14 or 15

    if year > y then return true
    elseif year < y then return false
    elseif month < m then return false
    elseif month > m then return true
    end
    return day > d
end

-------------------------------------------------------------------------------
-- Convert a date into a Julian day number
-- @param year Year of interest
-- @param month Month in year
-- @param day Day in month
-- @return Julian day number
-- @local
local function ymdToJdn(year, month, day)
    local a = floor((14 - month)/12)
    local y = year + 4800 - a
    local m = month + 12*a - 3

    local jdn = -32083
    if isGregorian(year, month, day) then
        jdn = -floor(y/100) + floor(y/400) - 32045
    end
    return jdn + day + floor((153 * m + 2) / 5) + 365*y + floor(y * 0.25)
end

-------------------------------------------------------------------------------
-- Convert a Julian day number to a date
-- @param Julian day number
-- @return year Year of interest
-- @return month Month in year
-- @return day Day in month
-- @local
local function jdnToYmd(j)
    local threshold = gregorianFirstDay --ukGregorian and 2361222 or 2299161
    local b, c = 0, j + 32082

    if j > gregorianFirstDay then
        local a = j + 32044
        b = floor((4*a+3)/146097)
        c = a - floor(b*146097*0.25)
        b = b * 100
    end

    local d = floor((4*c+3)/1461)
    local e = c - floor(1461*d*0.25)
    local m = floor((5*e+2)/153)

    local day = e - floor((153*m+2)/5) + 1
    local month = m + 3 - 12*floor(m/10)
    local year = b + d - 4800 + floor(m/10)

    return year, month, day
end

-------------------------------------------------------------------------------
-- Specify when the Gregorian calendar was adopted.
-- This determine the change over between the Julian and Gregorian calendars.
-- A number of days were <i>lost</i> during this change over and it occurred at
-- quite a number of different times for various countries.
--
-- There are however, two main change over dates.  The fourth of October 1582
-- marked the final day of the Julian calendar in most Catholic European
-- countries and the second of September 1752 was the final day of the
-- Julian calendar in the British empire countries.  These can be specified
-- via the short names <i>British</i> and <i>European<i>.
--
-- The default is the British change over date in 1752.  
-- @param year The year of the final day of the Julian calendar or the name of the country
-- @param month The month of the final day of the Julian calendar or nil if specified by country
-- @param dat The last day of the Julian calendar or nil if specified by country
-- @usage
-- -- local date = require'rinLibrary.date'
--
-- date.setReformation('russia')
function _M.setReformation(year, month, day)
    if type(year) == 'string' then
        year, month, day = unpack(namings.convertNameToValue(year, reformationDates, reformationDates.british))
    end
    gregorianChange = { year+1, 1, 1 }
    gregorianFirstDay = ymdToJdn(year, month, day)
    gregorianChange = { jdnToYmd(gregorianFirstDay) }
end
_M.setReformation('british')

-------------------------------------------------------------------------------
-- Check is a date is valid and in canonical form
-- @param year Year of interest
-- @param month Month in year
-- @param day Day in month
-- @return True iff the date is legal
-- @local
--local function checkDate(year, month, day)
--	if year < -4799 or year > 9999 then
--		return false
--    end
--    local y, m, d = jdnToYmd(ymdToJdn(year, month, day))
--    return y == year and m == month and d == day
--end

-------------------------------------------------------------------------------
-- Test if a year is a leap year or not
-- @param year Year of interest
-- @return True iff the year is a leap year
-- @usage
-- local date = require'rinLibrary.date'
--
-- print('The year 2000 is a '..(date.isLeapYear(2000) and 'leap' or 'standard')..' year')
function _M.isLeapYear(year)
    if year % 4 == 0 then
        if isGregorian(year, 1, 1)then
            if year % 100 == 0 then
                return year % 400 == 0
            end
        end
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Return the number of days between two dates
-- @param y1 Start year
-- @param m1 Month in starting year
-- @param d1 Day in starting month
-- @param y2 Finish year
-- @param m2 Month in finishing year
-- @param d2 Day in finishing month
-- @return the Number of days between the two dates
-- @usage
-- local date = require'rinLibrary.date'
--
-- local days = date.deltaDays(1900, 1, 1, 2000, 1, 1)
-- print('There were '..days..' days in the 20th Century')
function _M.deltaDays(y1, m1, d1, y2, m2, d2)
    return ymdToJdn(y2, m2, d2) - ymdToJdn(y1, m1, d1)
end


-------------------------------------------------------------------------------
-- Add a number of days to a given date
-- @param year Year of interest
-- @param month Month in year
-- @param day Day in month
-- @param n The number of days to add, can be negative
-- @return Year of final date
-- @return Month of that year
-- @return Day of that month
-- @usage
-- local date = require'rinLibrary.date'
--
-- local y, m, d = date.addDays(2000, 10, 1, -30000)
-- print(string.format('Thiry thousand days before 2000-10-1 is %4-%02d-%d', y, m, d))
function _M.addDays(year, month, day, n)
    return jdnToYmd(ymdToJdn(year, month, day) + n)
end

-------------------------------------------------------------------------------
-- Function to return the day of the week for a given date
-- @param year Year of interest
-- @param month Month in year
-- @param day Day in month
-- @return 1 .. 7, 1 is Monday
-- @return Day name
-- @return Short day name
-- @usage
-- local date = require'rinLibrary.date'
--
-- local _, day, _ = date.dayOfWeek(2000, 1, 1)
-- print('This century began on a '..day)
function _M.dayOfWeek(year, month, day)
    local h = (ymdToJdn(year, month, day) + 1) % 7
    local day = h == 0 and 7 or h
    return day, unpack(weekDays[day])
end


-------------------------------------------------------------------------------
-- Function to return the length of a month in a given year
-- @param year Year of interest
-- @param month Month in year
-- @return Number of days in the month that year
function _M.monthLength(year, month)
    if month == 12 then
        return _M.deltaDays(year, month, 1, year+1, 1, 1)
    end
    return _M.deltaDays(year, month, 1, year, month+1, 1)
end

-------------------------------------------------------------------------------
-- Return the name of the specified month
-- @param month Month in year
-- @return Month name
-- @return Short month name
-- local date = require'rinLibrary.date'
--
-- local month, _ = date.monthName(3)
-- print('The third month is '..month)
function _M.monthName(month)
    return unpack(months[month])
end


-------------------------------------------------------------------------------
-- Sets the order of the date string
-- @param first  = 'day', 'month' or 'year'
-- @param second  = 'day', 'month' or 'year'
-- @param third = 'day','month' or 'year'
-- @see getDateFormat
-- @usage
-- -- Set the current date format to year then day then month
-- -- This isn't written to back to the display and is only
-- -- used for formatting output.
-- local date = require'rinLibrary.date'
--
-- date.setDateFormat('year', 'day', 'month')
function _M.setDateFormat(first, second, third)
    local first = first or 'day'
    local second = second or 'month'
    local third = third or 'year'

    local check = { day = 0, month = 0, year = 0 }
    check[first] = check[first] + 1
    check[second] = check[second] + 1
    check[third] = check[third] + 1

    if check.day == 1 and check.month == 1 and check.year == 1 then
        date_first = first
        date_second = second
        date_third = third
    else
        dbg.warn('date: illegal date format specified:', first, second, third)
    end
end

-------------------------------------------------------------------------------
-- Gets the order of the date string
-- @return first field
-- @return second field
-- @return third field
-- @see setDateFormat
-- @usage
-- local date = require'rinLibrary.date'
--
-- local first, second, third = date.getDateFormat()
-- if first == 'year' and second == 'day' and third == 'month' then
--     print('Someone is being silly with the date formatting')
-- end
function _M.getDateFormat()
    return date_first, date_second, date_third
end

-------------------------------------------------------------------------------
-- Returns formated date string
-- @param year Year of interest
-- @param month Month in year
-- @param day Day in month
-- @return Formatted date string
-- @see getDateFormat
-- @see setDateFormat
-- @usage
-- local date = require'rinLibrary.date'
--
-- print(date.formatDate(2000, 12, 17))
function _M.formatDate(year, month, day)
    local t = { year = year, month = month, day = day }
    return string.format("%02d/%02d/%02d", t[date_first], t[date_second], t[date_third])
end

return _M
