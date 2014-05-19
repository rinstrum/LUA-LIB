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
local type = type
local tostring = tostring

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Return the length of a month in a given year
-- @param y Year
-- @param m Month
-- @return The number of days in the month
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
return function (_M)

-------------------------------------------------------------------------------

-- @section clock
-------------------------------------------------------------------------------

--  Time and Date
_M.REG_TIMECUR          = 0x0150
_M.REG_TIMEFORMAT       = 0x0151
_M.REG_TIMEDAY          = 0x0152
_M.REG_TIMEMON          = 0x0153
_M.REG_TIMEYEAR         = 0x0154
_M.REG_TIMEHOUR         = 0x0155
_M.REG_TIMEMIN          = 0x0156
_M.REG_TIMESEC          = 0x0157

_M.REG_MSEC1000         = 0x015C
_M.REG_MSEC             = 0x015D
_M.REG_MSECLAST         = 0x015F
_M.TM_DDMMYY            = 0
_M.TM_DDMMYYYY          = 1
_M.TM_MMDDYY            = 2
_M.TM_MMDDYYYY          = 3
_M.TM_YYMMDD            = 4
_M.TM_YYYYMMDD          = 5

-------------------------------------------------------------------------------
-- sets the instrument date format
-- @param fmt TM_MMDDYYYY or TM_DDMMYYYY
function _M.sendDateFormat(fmt)
     if fmt < _M.TM_DDMMYY or fmt > _M.TM_YYYYMMDD then
        fmt = _M.TM_DDMMYYYY
     end
  _M.sendRegWait(_M.CMD_WRFINALDEC,_M.REG_TIMEFORMAT,fmt)
end

_M.RTC = {hour = 0, min = 0, sec = 0, day = 1, month = 1, year = 2010}
_M.RTC['first'] = 'day'
_M.RTC['second'] = 'month'
_M.RTC['third'] = 'year'

-------------------------------------------------------------------------------
-- Read Real Time Clock data from instrument into local RTC table
-- @param d 'date' or 'time' to read these fields only, or 'all' for both
function _M.RTCread(d)
  local d = d or 'all'

  local fmt , err = _M.sendRegWait(_M.CMD_RDFINALDEC,_M.REG_TIMEFORMAT)
  
  if err then
    fmt = 0
  else
    fmt = tonumber(fmt)
  end
  
  if fmt == _M.TM_DDMMYYYY or fmt == _M.TM_DDMMYY then
     _M.RTCdateFormat('day','month','year')
  elseif fmt == _M.TM_MMDDYYYY or fmt == _M.TM_MMDDYY then
     _M.RTCdateFormat('month','day','year')
  else
     _M.RTCdateFormat('year','month','day')
  end
    
  local timestr, err = _M.sendRegWait(_M.CMD_RDLIT,_M.REG_TIMECUR)
  
  if err then
    timestr = '01/01/2000 00-00'
  end
  --dbg.printVar(timestr)
  
  if d == 'date' or d == 'all' then
    _M.RTC.day, _M.RTC.month, _M.RTC.year =
      string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
  end
  
  if d == 'time' or d == 'all' then
    _,_,_, _M.RTC.hour, _M.RTC.min =
      string.match(timestr,"(%d+)/(%d+)/(%d+) (%d+)-(%d+)")
  end
    
  _M.RTC.sec, err = _M.readReg(_M.REG_TIMESEC)
  
  if err then
    _M.RTC.sec = 0
  end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Write a single RTC register and update the local copy
-- @param r Register to update
-- @param f Value to update it with
-- @param n Name of the field
-- @param l Lowest legal value
-- @param u Highest leval value
local function writeRTC(r, f, n, l, u)
    local x = tonumber(f)
    if x ~= nil and x >= l and x <= u then
        _M.writeReg(r, x)
        _M.RTC[n] = x
    end
end

-------------------------------------------------------------------------------
-- Write Real Time Clock date to instrument
-- @param year The year to write or nil to leave unchanged
-- @param month The month to write or nil to leave unchanged
-- @param day The day to write or nil to leave unchanged
function _M.RTCwriteDate(year, month, day)
    writeRTC(_M.REG_TIMEYEAR,  year,       "year",  2010,   2100)
    writeRTC(_M.REG_TIMEMON,   month,      "month", 1,      12)
    writeRTC(_M.REG_TIMEDAY,   day,        "day",   1,      monthLength(_M.RTC.year, _M.RTC.month))
end

-------------------------------------------------------------------------------
-- Write Real Time Clock time to instrument
-- @param hour The hour to write or nil to leave unchanged
-- @param minute The minute to write or nil to leave unchanged
-- @param second The second to write or nil to leave unchanged
function _M.RTCwriteTime(hour, minute, second)
    writeRTC(_M.REG_TIMESEC,   second,     "sec",   0,      59)
    writeRTC(_M.REG_TIMEMIN,   minute,     "min",   0,      59)
    writeRTC(_M.REG_TIMEHOUR,  hour,       "hour",  0,      23)
end

-------------------------------------------------------------------------------
-- Write Real Time Clock date and time to instrument
-- @param year The year to write or nil to leave unchanged
-- @param month The month to write or nil to leave unchanged
-- @param day The day to write or nil to leave unchanged
-- @param hour The hour to write or nil to leave unchanged
-- @param minute The minute to write or nil to leave unchanged
-- @param second The second to write or nil to leave unchanged
function _M.RTCwrite(year, month, day, hour, minute, second)
    _M.RTCwriteTime(hour, minute, second)
    _M.RTCwriteDate(year, month, day)
end

-------------------------------------------------------------------------------
-- Called every second to update local RTC 
function _M.RTCtick()
    _M.RTC.sec = _M.RTC.sec + 1
    if _M.RTC.sec > 59 then
        _M.RTC.sec = 0
        _M.RTC.min = _M.RTC.min + 1
        if _M.RTC.min > 59 then  
            _M.RTC.min = 0
            _M.RTC.hour = _M.RTC.hour + 1
            if _M.RTC.hour > 23 then    
                _M.RTC.hour = 0
                _M.RTCread()
            end                 
        end
    end
end

-------------------------------------------------------------------------------
-- Returns formated date/time string
-- Private function
function _M.RTCtostring()
    return string.format("%02d/%02d/%02d %02d:%02d:%02d",
                        _M.RTC[_M.RTC.first],
                        _M.RTC[_M.RTC.second],
                        _M.RTC[_M.RTC.third],
                        _M.RTC.hour,
                        _M.RTC.min,
                        _M.RTC.sec)
end

-------------------------------------------------------------------------------
-- Sets the order of the date string.byte
-- @param first  = 'day', 'month' or 'year'
-- @param second  = 'day', 'monht','year'
-- @param third = 'day','month','year'
function _M.RTCdateFormat(first,second,third)
    local first = first or 'day'
    local second = second or 'month'
    local third = third or 'year'
  
    _M.RTC.first = first
    _M.RTC.second = second
    _M.RTC.third = third
end  

end
