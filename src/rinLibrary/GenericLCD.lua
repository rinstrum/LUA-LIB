-------------------------------------------------------------------------------
--- LCD Services.
-- Functions to configure the LCD
-- @module rinLibrary.Device.LCD
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local tonumber = tonumber
local math = math
local string = string
local table = table
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local pcall = pcall

local timers = require 'rinSystem.rinTimers'
local naming = require 'rinLibrary.namings'
local canonical = naming.canonicalisation
local dbg = require "rinLibrary.rinDebug"
local system = require "rinSystem"
local utils = require 'rinSystem.utilities'
local deepcopy = utils.deepcopy
local dispHelp = require 'rinLibrary.displayHelper'

local lpeg = require 'rinLibrary.lpeg'
local C, Cg, Cs, Ct, Cmt, Cc = lpeg.C, lpeg.Cg, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cc
local P, Pi, R, S, V = lpeg.P, lpeg.Pi, lpeg.R, lpeg.S, lpeg.V
local digit, spc = lpeg.digit, lpeg.space
local num, dot = C(digit^1), C(P'.')
local sdot = P'.'
local scdot = (1 - sdot) * sdot^-1
local equals, formatPosition = spc^0 * P'=' * spc^0

local function isUint8(n)
    n = tonumber(n)
    return type(n) == 'number' and n >= 0 and n<256
end

local function isUint16(n)
    n = tonumber(n)
    return type(n) == 'number' and n >= 0 and n<65536
end

local function checkIP(s, i, a, b, c, d)
    return isUint8(a) and isUint8(b) and isUint8(c) and isUint8(d)
end

local function checkPort(s, i, a)
    return isUint16(a)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Define a pattern to match the display options and produce an option table.
local function boolArg(s) return Cg(Pi(s), s) end
local function nameArg(s) return Pi(s) / s end
local writeArgPat = P{
            spc^0 * Ct((V'opt' * ((spc + P',')^1 * V'opt')^0)^-1) * spc^0 * P(-1),
    opt =   V'time' + boolArg'clear' + boolArg'wait' + boolArg'once' +
                boolArg'sync' + boolArg'restore' + V'align' + boolArg'marquee',
    time =  (Pi'time' * equals)^-1 * Cg(lpeg.float / tonumber, 'time'),
    align = Pi'align' * equals * Cg(nameArg'left' + nameArg'right', 'align')
}

-------------------------------------------------------------------------------
-- Helper function to apply a callback to every element of the specified array
-- @param t Array to modify
-- @param f Callback function to execute
-- @return Modified table
-- @local
local function xform(t, f)
    if utils.callable(f) then
        for i = 1, #t do
            t[i] = f(t[i])
        end
    end
    return t

end
-------------------------------------------------------------------------------
-- Split a long string into shorter strings of multiple words
-- that fit into length len.
-- @param f field description table
-- @param s String
-- @param align Alignment of result
-- @return list of fragments of the string formatted to fit the field width
-- @local
local function splitWords(f, s, align)
    local t, p = {}, ''
    local len, strlen, strsub = f.length, f.strlen, f.strsub
    s = tostring(s)

    if strlen(s) <= len then
        table.insert(t, s)
    else
        for w in string.gmatch(s, "%S+") do
            if strlen(p) + strlen(w) < len then
                if p == '' then
                    p = w
                else
                    p = p .. ' '..w
                end
            elseif strlen(p) > len then
                table.insert(t, strsub(p, 1, len))
                p = strsub(p, len+1)
                if strlen(p) + strlen(w) < len then
                    p = p .. ' ' .. w
                else
                    table.insert(t, p)
                    p = w
                end
            else
                if #p > 0 then
                    table.insert(t, p)
                end
                p = w
            end
        end

        while strlen(p) > len do
            table.insert(t, strsub(p, 1, len))
            p = strsub(p, len+1)
        end
        if #p > 0 or #t == 0 then
            table.insert(t, p)
        end
    end

    xform(t, f[(align or 'left') .. 'Justify'])
    return xform(t, f.finalFormat)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--local REG_DEFAULTMODE          = 0x0166
local REG_LCD                  = 0x0009
local REG_LCDMODE              = 0x000D
local REG_MASTER               = 0x00B9
local REG_ADC_DISPLAY_MODE     = 0x030E

local REG_SERAUT               = 0xA200
local OPT_AUTO1                = 0
local OPT_AUTO2                = 1

local REG_SER1_OFFSET          = 0xA201
local REG_SER2_OFFSET          = 0xA241

local REG_SER_TYPE             = 0
local REG_SER_SERIAL           = 1
local REG_SER_FORMAT           = 2
local REG_SER_SOURCE           = 3

local SER_FORMAT_CUSTOM
private.registerDeviceInitialiser(function()
    SER_FORMAT_CUSTOM = private.k422(8) or 7
end)

local interfaces = {auto1 = REG_SER1_OFFSET, auto2 = REG_SER2_OFFSET}
local serials = {['5hz'] = 5, ['10hz'] = 2, ['25hz'] = 3}
local ports = {ser1a = 0, ser1b = 1, ser2a = 2, ser2b = 3, ser3a = 4, ser3b = 5}

local display = {}

function private.getDisplay()
  return display
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- Define the interfaces

local function Sw(x) return spc^0 * Ct(x) * spc^0 * -1 end

local serial = P{
            Sw(V'intf' * (spc^1 * V'opts')^0 * V'type'),
    type =  Cg(Cc('serial'), 'type'),
    intf =  Cg((Pi('auto') * S'12') / string.lower, 'intf'),
    opts =  V'port' + V'rate',
    port =  Cg((Pi'ser' * S'123' * S'abAB') / string.lower, 'port'),
    rate =  Pi'rate='^-1 * Cg(Pi'5hz' + Pi'10hz' + Pi'25hz', 'rate')
}

-- Note: USB's do not actually support 'ttyUSB#' specification.
local usb = P{
            Sw(V'port' * V'type'),
    type =  Cg(Cc('usb'), 'type'),
    port =  Cg(Cs(Pi'ttyUSB' / 'ttyUSB' * C(digit^1)) + Pi'usb' / 'ttyUSB0', 'port'),
}

local network = P{
            Sw(V'addr' * V'port'^0 * V'type'),
    type =  Cg(Cc('network'), 'type'),
    addr =  Cg(Cmt(num * P'.' * num * P'.' * num * P'.' * num, checkIP), 'addr'),
    port =  P':' * Cg(Cmt(num^1, checkPort) / tonumber, 'port')
}

local embedded =  Sw(Cg(Pi'embedded', 'type'))

local displayPattern = embedded + serial + usb + network

--- Displays.
--
-- It is possible to add these displays to the displayField table.
--
-- @table displays
-- @field console Console display. Anything written to this will print in the console.
-- @field D320 D320 remote display type. Communicates using ranger C.
-- @field D840 D840 remote display type. Communicates using ranger C.
-- @field Generic Generic remote display type. Communicates using ranger C, supports 7 characters.

-------------------------------------------------------------------------------
-- Called to add a display to the framework
-- @tparam displays type Type of display to add. These are stored in rinLibrary.display
-- @string prefix Name for added display fields. This will be added to @{displayField}.
-- @string[opt] options Extra addressing information. 
-- For device serial ports, this of the form '(auto1/auto2) [serial (ser1a-ser3b)] [Rate (5hz, 10hz, 25hz)]'.
-- Optional arguments (i.e. serial and rate) will not be written to the device unless they are explicitly set.
-- For USB serial ports: 'usb'
-- For Network serial ports: 'XXX.XXX.XXX.XXX:port'
-- @treturn bool Boolean showing success of adding the framework
-- @treturn string Error message if err, nil otherwise
-- @usage
-- local succeeded, err = device.addDisplay('D320', 'MyD320', 'auto1 ser1a 5hz')
function _M.addDisplay(type, prefix, options)
  local err

  prefix = prefix or ''

  --local success, disp  = pcall(require("rinLibrary.display." .. type))
  local success, disp = true, require("rinLibrary.display." .. type)
  if (success == false) then
    return false, disp
  end
   
  prefix = naming.canonicalisation(prefix)
  
  -- Get the settings. There may be none given.
  local settings = displayPattern:match(options)
  settings.reg = 0
  
  -- If the user does not specify any addressing options, then set up the 
  -- device serial.
  if (settings and settings.type == 'serial') then
    local reg_off = interfaces[settings.intf]
    settings.reg = reg_off
    
    -- If auto2 is used, make it's available
    if (settings.intf == 'auto2') then
      private.writeRegHexAsync(REG_SERAUT, OPT_AUTO2)
    end
  
    --Set the format
    private.writeRegHexAsync(reg_off + REG_SER_FORMAT, SER_FORMAT_CUSTOM)
    
    -- If the user specifies a port, set it.
    if (settings.port) then
      private.writeRegHexAsync(reg_off + REG_SER_SERIAL, ports[settings.port])
    end
    
    -- If the user specifies a rate, set it.
    if (settings.rate) then
      private.writeRegHexAsync(reg_off + REG_SER_TYPE, serials[settings.rate])
    end

    _M.saveSettings()
  end
  
  display, err = disp.add(private, display, prefix, settings)
  
  if (err) then
    return nil, err
  end

  return true
end

-------------------------------------------------------------------------------
-- Link display fields
-- Operations performed on a linked display field will apply to all displays 
-- that have been linked.
-- @string name The name for the linked display
-- @tparam displayField ... Displays to link.
-- @usage
-- device.linkDisplay('link1', 'topLeft', 'MyD320')
-- device.writeDisplay('link1', "Display this message to both display fields")
function _M.linkDisplay(name, ...)
  local fields = {...}
  
  name = naming.canonicalisation(name)
  
  -- Action on all display fields in link
  local function forAll(action, ...)

    for k, v in pairs(fields) do
      display[v][action](...)
    end
  end
  
  for k, v in pairs(fields) do
    fields[k] = naming.canonicalisation(v)
  end
  
  display[name] = {
    linkedDisplay = true,
    linkedDisplays = fields,
    write       = function(...) forAll("write", ...) end,
    transmit    = function(...) forAll("transmit", ...) end,
    writeUnits  = function(...) forAll("writeUnits", ...) end,
    setAnnun    = function(...) forAll("setAnnun", ...) end,
    clearAnnun  = function(...) forAll("clearAnnun", ...) end,
    rotWait     = function(...) forAll("rotWait", ...) end, 
    writeStatus = function(...) forAll("writeStatus", ...) end,
  }
  
end

-------------------------------------------------------------------------------
-- Show the status (net/gross, overload, etc.) on a display
-- @tparam displayField displayDevice The display to mirror to
-- @bool[opt] setting True for mirror, false for off (default)
function _M.mirrorStatus(displayDevice, setting)
  local name = naming.canonicalisation(displayDevice)
  setting = setting or false
  displayDevice = naming.convertNameToValue(name or 'none', display)

  if (displayDevice and displayDevice.remote) then
    displayDevice.mirrorStatus = setting
    displayDevice.transmit(false)
  end
  
  if (displayDevice and displayDevice.linkedDisplay) then
    for k, v in pairs(displayDevice.linkedDisplays) do
      display[v].mirrorStatus = setting
      display[v].transmit(false)
    end
  end
end

-------------------------------------------------------------------------------
-- Private function to update the status (if mirrorStatus enabled)
-- @local
function private.callbackLCDStatus()
  for k,v in pairs(display) do
    if v.writeStatus and v.mirrorStatus then
      v.writeStatus(_M.anyStatusSet, _M.allStatusSet, _M.dualRangeMode())
    end
  end
end

--- Display Control Modes.
--
-- The control parameter for the write to display functions is reasonably
-- complex.
--
-- If this parameter is left nil, defaults are used for all settings (see below).
--
-- If this parameter is a number, it is treated as the time between segments
-- of the message to display.  The other settings default as below.
--
-- The this parameter is a string, it is considered to be a space or comma separated list
-- of values.  For example, the string <i>"time=2, once, clear, align=left"</i>
-- specifies a two second display between elements, clear the field after wards, only display
-- the message once and left align the message.  For the <i>time</i> parameter, the <i>time=</i> can be omitted.
-- Thus, "once 2 clear, align=left" has the same meaning as the previous example.
--
-- If this parameter is a table, it contains a number of fields which fine tune
-- the display behaviour.  These fields are described below.
--
-- @table displayControl
-- @field align Takes a value of either <i>left</i> or <i>right</i>.  The text in the field is aligned
-- to this end of the field.  The default is left justified.
-- @field clear Clear is a boolean, that clears the message from the display once it has been
-- shown (default: don't clear).  The clear implies the once option.
-- @field finish A function to call once the display have finished -- this can only be specified in the
-- tabular form and implies once, not clear and not restore.
-- @field once Once is a boolean that forces the message to be shown once rather
-- than repeating (default: repeat/display forever).
-- @field restore Restore the field to the settings it had prior to having the message displayed.  This
-- implies once and not clear.
-- @field sync Synchronously write message to the display (default: asynchronous).  This guarantees that
-- the message is on the display when the call returns but will cause a slight loss of performance for
-- long multi-part messages.  Generally, you shouldn't need to add this control modifier.
-- @field time The time parameter is the number of second between the display being updated (default 0.8).
-- @field wait Wait is a boolean for causes the display call to not return until after
-- the message has been fully displayed (default: don't wait).  The wait implies the once option.
-- The wait option and linked displays do not work well together.
-- @field marquee The marquee parameter will cause the text to scroll across the screen, rather than 
-- showing a word at a time.

--- LCD Control Modes.
--@table lcdControlModes
-- @field default Set to a default setting (currently dual)
-- @field dual Change to dual display mode
-- @field lua Communication mode, necessary for LUA control
-- @field master Change to master display mode
-- @field product Change to product display mode
local currentLcdMode, lcdModeMap, lcdModeUnmap
private.registerDeviceInitialiser(function()
    lcdModeMap = {
        default = private.batching(0) or private.k422(0) or 1,
        dual    = private.batching(0) or 1,                         -- dynamic
        lua     = private.batching(1) or 2,
        master  = private.batching(2) or 3,
        product = private.valueByDevice{ k402=0, k422=0, k491=0 }   -- normal
    }
    lcdModeUnmap = utils.invert(lcdModeMap)
    currentLcdMode = lcdModeMap.default
end)

--- ADC Display Modes.
-- These settings change the ADC display output but do notmake it active.
--@table adcDisplayModes
-- @field weight Display weight
-- @field piece_count Display piece count
-- @field alternate_units Display alternative units
local adcModeMap, currentAdcMode = {
    weight = 0,
    piece_count = 1,
    alternate_units = 2
}
local adcModeUnmap = utils.invert(adcModeMap)

-------------------------------------------------------------------------------
-- Called to setup LCD control.
-- The rinApp framework generally takes care of calling this function for you.
-- However, sometimes you'll want to return control to the display device
-- for a time and grab control again later.
-- @tparam lcdControlModes mode is 'lua' to control display from script or 'default'
-- to return control to the default instrument application.  If not specified,
-- <i>default</i> is assumed.
-- @treturn lcdControlModes The previous mode setting
-- @usage
-- device.lcdControl('default')     -- let the display control itself
-- ...
-- device.lcdControl('lua')         -- switch on Lua display
function _M.lcdControl(mode)
    local oldMode = currentLcdMode
    currentLcdMode = naming.convertNameToValue(mode, lcdModeMap, lcdModeMap.default)
    private.exReg(REG_LCDMODE, currentLcdMode)
    return naming.convertValueToName(oldMode, lcdModeUnmap, oldMode)
end

-------------------------------------------------------------------------------
-- Called to set the ADC display mode.
-- This call does not make the display active.
-- @tparam[opt] adcDisplayModes mode The ADC display mode to use, if not 
-- specified <i>weight</i> is assumed.
-- @treturn adcDisplayModes The old ADC display mode.
-- @usage
-- device.adcDisplayMode('alternate_units')
function _M.adcDisplayMode(mode)
    local oldMode = currentAdcMode or private.readReg(REG_ADC_DISPLAY_MODE)
    currentAdcMode = naming.convertNameToValue(mode, adcModeMap, lcdModeMap.weight)
    private.writeRegAsync(REG_ADC_DISPLAY_MODE, currentAdcMode)
    return naming.convertValueToName(oldMode, adcModeUnmap, oldMode)
end


-------------------------------------------------------------------------------
-- Decode the time argument to the write function.
-- The input argument can be a number which is interpreted as a time,
-- it can be nil for all defaults or it can be a table which is returned
-- unchanged.
-- @param t Input time/param value
-- @local
local function writeArgs(t)
    if t == nil then
        return {}
    elseif type(t) == 'number' then
        return { time = t }
    elseif type(t) == 'string' then
        local r = writeArgPat:match(t)
        if r == nil then
            dbg.error("LCD: unparsable display parameter:", t)
            return {}
        end
        return r
    elseif type(t) == 'table' then
        return deepcopy(t)
    end
    dbg.error("LCD: unknown display parameter:", tostring(t))
    return {}
end

-------------------------------------------------------------------------------
-- Remove the timer associated with sliding the display, if present and
-- clean up
-- @local
function private.removeSlideTimer(f)
    timers.removeTimer(f.slideTimer)
    f.slideTimer = nil
end

-------------------------------------------------------------------------------
-- Write a message to the given display field.
-- @param f Display field.
-- @param s String to write
-- @param params Display parameters
-- @local
function private.write(f, s, params)
    if f then
        private.removeSlideTimer(f)
        if s then
            local t = writeArgs(params)
            utils.checkCallback(t.finish)
            local wait = t.wait
            local once = t.once or wait or t.clear or t.restore or t.finish
            local time = math.max(t.time or 0.8, 0.2)
            local sync = t.sync
            local marquee = t.marquee

            if not t.finish then
                if t.restore then
                    local c, p, u, w = f.current, f.params, f.units1, f.units2
                    t.finish = function()
                        private.write(f, c, p)
                        utils.call(f.writeUnits, u, w)
                    end
                elseif t.clear then
                    t.finish = function()
                        f.write(xform({''}, f.finalFormat)[1], false)
                        f.params, f.current, f.currentReg = nil, '', nil
                    end
                end
            end

            if private.writeAuto then
              private.writeAuto(f, 0)
            end
            
            local function writeToDisplay(s)
                if f.currentReg ~= s then
                    f.currentReg = s
                    f.write(s, sync)
                end
            end
            
            if not marquee then
              f.params, f.current = t, tostring(s)
              local slidePos, slideWords = 1, splitWords(f, f.current, t.align)
 
              writeToDisplay(slideWords[1])
  
              f.slideTimer = timers.addTimer(time, time, function()
                  slidePos = private.addModBase1(slidePos, 1, #slideWords, true)
                  if slidePos == 1 and once then
                      private.removeSlideTimer(f)
                      wait = false
                      utils.call(t.finish)
                  elseif #slideWords == 1 then
                      private.removeSlideTimer(f)
                  else
                      writeToDisplay(slideWords[slidePos])
                  end
              end)
            else
              f.params, f.current = t, string.rep(" ", f.length) ..  s
              f.slideTimer = timers.addTimer(time, time, function()
                  -- Check if message is finished
                  if f.current == false then
                      return
                  end
              
                  -- If there's nothing left to move, clear the screen
                  if f.current == '' then
                      writeToDisplay('')  
                      if once then
                        private.removeSlideTimer(f)
                        wait = false
                        utils.call(t.finish)
                      else
                        f.current = string.rep(" ", f.length) ..  s
                      end
              
                  -- If there's something left to write, write a substring of 
                  -- characters to the device and remove a character from the 
                  -- message
                  else
                      local spec = string.format("%%-%ds", f.length)
                      local sStr = string.sub(f.current,1,f.length)
                      writeToDisplay(string.format(spec, sStr))
                      f.current = string.sub(f.current, 2)
                  end
              end)
            end
            _M.app.delayUntil(function() return not wait end)
            
        elseif (f.auto == nil or f.auto == 0) and private.writeAuto then
            private.writeAuto(f, f.saveAuto)
        end

    end
end

-------------------------------------------------------------------------------
-- Write a message to the given display field.
-- @param f Display field.
-- @param s String to write
-- @local
local function writeToken(f, s)
  -- Do not allow writing to socket-connected displays
  if f == nil then
    return nil, "Invalid"
  end
  
  if f.sock == nil then
    return dispHelp.writeRegHex(private, false, f.reg, s)
  else
    return f.sock:write(s)
  end  

end

-------------------------------------------------------------------------------
-- Apply a map to selected members of the display list
-- @param p Predicate that selects which elements to act on
-- @param f Function to apply
-- @local
function private.map(p, f)
    for _, v in pairs(private.getDisplay()) do
        if p(v) then f(v) end
    end
end

-------------------------------------------------------------------------------
-- Save the specified display fields and return a function that will restore
-- them to their current settings.
-- @param p Predicate that selects which elements to act on
-- @return Function to restore selected display elements
-- @local
function private.saver(p)
    local restorations = {}
    private.map(p, function(v)
            table.insert(restorations, { disp=v, 
                                         current=v.current, 
                                         params=v.params, 
                                         units1=v.units1, 
                                         uints2=v.units2,
                                         auto = v.auto or 0,
                                        })
        end)

    return function()
        for _, v in ipairs(restorations) do
            private.write(v.disp, v.current, v.params)
            if (v.disp.writeUnits) then
              v.disp.writeUnits(v.units1, v.units2)
            end
            if (v.disp.regAuto) then
              private.writeAuto(v.disp, v.auto)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Save the all display fields and fields and units.
-- @treturn func Function that restores the display fields to their current values
-- @usage
-- local restore = device.saveDisplay()
-- device.write('topLeft', 'fnord') -- If uses K400, may require device.writeAuto('topLeft', 0)
-- restore()
function _M.saveDisplay()
    return private.saver(function(v) return v.localDisplay end)
end

-------------------------------------------------------------------------------
-- Write string to this specified display section
-- @function write
-- @tparam displayField where Which display to write to
-- @string s string to display
-- @tparam[opt] displayControl params displayControl parameters
-- @usage
-- device.write('topLeft', 'HELLO WORLD', 'time=2, wait')
function _M.write(where, s, params)
    local disp = naming.convertNameToValue(where, display)
    
    if (disp and disp.linkedDisplay) then
      for k, v in pairs(disp.linkedDisplays) do
        private.write(naming.convertNameToValue(v, display), s, params)  
      end
    else
      private.write(disp, s, params)  
    end
end

-------------------------------------------------------------------------------
-- Write a message directly to the given display field. 
-- This message may include tokens, (only valid for displays connected directly 
-- to the R400 i.e. the R400 LCD), or may include user-implemented protocols.
-- THIS FUNCTION IS NOT RECOMMENDED FOR TYPICAL USE, see write
-- @tparam displayField where which display section to write to
-- @string s String to write
-- @see write
function _M.writeDirect(where, s)
  local disp = naming.convertNameToValue(where, display)
  
  if (disp and disp.linkedDisplay) then
    for k, v in pairs(disp.linkedDisplays) do
      writeToken(naming.convertNameToValue(v, display), s)  
    end
  else
    writeToken(disp, s)  
  end

end

-------------------------------------------------------------------------------
-- Turns the annunciators on
-- @tparam displayField where which display section to write to
-- @tparam Annunciators ... holds annunciator names
-- @usage
-- device.setAnnunciators('topLeft', 'battery', 'clock', 'balance')
function _M.setAnnunciators(where, ...)
  local f = naming.convertNameToValue(where, display)

  if type(f) == 'table' and utils.callable(f.setAnnun) then
    return f.setAnnun(...)
  end
end

-------------------------------------------------------------------------------
-- Turns the annunciators off
-- @tparam displayField where which display section to write to
-- @tparam Annunciators ... holds annunciator names
-- @usage
-- device.clearAnnunciators('topLeft', 'net', 'battery', 'hold')
function _M.clearAnnunciators(where, ...)
  local f = naming.convertNameToValue(where, display)

  if type(f) == 'table' and utils.callable(f.clearAnnun) then
    return f.clearAnnun(...)
  end
end

-------------------------------------------------------------------------------
-- Set units for specified field.
-- The other field isn't always supported.  Likewise, not all fields have units.
-- @tparam displayField where Which display to write to
-- @tparam Units unts Unit to display
-- @tparam Other other ('per&#95;h', 'per&#95;m', 'per&#95;s', 'pc', 'tot', &#8230;)
-- @usage
-- device.writeUnits('topLeft', 'kg')
function _M.writeUnits(where, unts, other)

    local f = naming.convertNameToValue(where, display)

    if f and utils.callable(f.writeUnits) then
      return f.writeUnits(unts, other)
    else
      return nil, nil, "Invalid name"
    end
end

-------------------------------------------------------------------------------
-- Load a raw binary dump of the current LCD display segments.
-- @return Binary blob representing the current display
-- @usage
--  local data, err = master.getRawLCD()
--
--  if err then
--      dbg.warn('Screen Duplicate:', err)
--  else
--      slave.setRawLCD(data)
--  end
function _M.getRawLCD()
    return private.readRegDec(REG_LCD)
end

-------------------------------------------------------------------------------
-- Store a raw binary dump to the current LCD display segments.  It is the
-- users' responsibility to ensure that the binary blob is suitable for the
-- destination display.
-- @param data Binary blob representing the desired display
-- @usage
--  local data, err = master.getRawLCD()
--
--  if err then
--      dbg.warn('Screen Duplicate:', err)
--  else
--      slave.setRawLCD(data)
--  end
function _M.setRawLCD(data)
    private.writeRegAsync(REG_MASTER, data, 'crc')
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Add in the registers from the R400 Display
-- These are necessary so that when readAuto returns a register, the register
-- is recognised by the library.
-- 
local R400Reg = require 'rinLibrary.display.R400'

deprecated.REG_LCDMODE                  = R400Reg.REG_LCDMODE
deprecated.REG_DISP_BOTTOM_LEFT         = R400Reg.REG_DISP_BOTTOM_LEFT
deprecated.REG_DISP_BOTTOM_RIGHT        = R400Reg.REG_DISP_BOTTOM_RIGHT
deprecated.REG_DISP_TOP_LEFT            = R400Reg.REG_DISP_TOP_LEFT
deprecated.REG_DISP_TOP_RIGHT           = R400Reg.REG_DISP_TOP_RIGHT
deprecated.REG_DISP_TOP_ANNUN           = R400Reg.REG_DISP_TOP_ANNUN
deprecated.REG_DISP_TOP_UNITS           = R400Reg.REG_DISP_TOP_UNITS
deprecated.REG_DISP_BOTTOM_ANNUN        = R400Reg.REG_DISP_BOTTOM_ANNUN
deprecated.REG_DISP_BOTTOM_UNITS        = R400Reg.REG_DISP_BOTTOM_UNITS
deprecated.REG_DISP_AUTO_TOP_ANNUN      = R400Reg.REG_DISP_AUTO_TOP_ANNUN
deprecated.REG_DISP_AUTO_TOP_LEFT       = R400Reg.REG_DISP_AUTO_TOP_LEFT
deprecated.REG_DISP_AUTO_BOTTOM_LEFT    = R400Reg.REG_DISP_AUTO_BOTTOM_LEFT
deprecated.REG_LCD                      = R400Reg.REG_LCD

if _TEST then
    _M.strLenLCD = dispHelp.strLenLCD
    _M.strSubLCD = dispHelp.strSubLCD
    _M.padDots    = dispHelp.padDots
    _M.splitWords = splitWords
end

end
