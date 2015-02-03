-------------------------------------------------------------------------------
--- LCD Services.
-- Functions to configure the LCD
-- @module rinLibrary.K400LCD
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
--
local tonumber = tonumber
local math = math
local string = string
local table = table
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local pcall = pcall

local bit32 = require "bit"
local timers = require 'rinSystem.rinTimers'
local naming = require 'rinLibrary.namings'
local canonical = naming.canonicalisation
local dbg = require "rinLibrary.rinDebug"
local system = require "rinSystem"
local utils = require 'rinSystem.utilities'
local deepcopy = utils.deepcopy
local dispHelp = require 'rinLibrary.displayHelper'

-- This shouldn't need to be here, but supports deprecated functions.
-- Remove when possible
local R400Reg = require 'rinLibrary.display.R400'

local lpeg = require 'rinLibrary.lpeg'
local C, Cg, Cs, Ct = lpeg.C, lpeg.Cg, lpeg.Cs, lpeg.Ct
local P, Pi, R, S, V, spc = lpeg.P, lpeg.Pi, lpeg.R, lpeg.S, lpeg.V, lpeg.space
local sdot = P'.'
local scdot = (1 - sdot) * sdot^-1
local equals, formatPosition = spc^0 * P'=' * spc^0

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Define a pattern to match the display options and produce an option table.
local function boolArg(s) return Cg(Pi(s), s) end
local function nameArg(s) return Pi(s) / s end
local writeArgPat = P{
            spc^0 * Ct((V'opt' * ((spc + P',')^1 * V'opt')^0)^-1) * spc^0 * P(-1),
    opt =   V'time' + boolArg'clear' + boolArg'wait' + boolArg'once' +
                boolArg'sync' + boolArg'restore' + V'align',
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

local display = {}

-------------------------------------------------------------------------------
-- Called to add a display to the framework
-- @param type Type of display to add. These are stored in rinLibrary.display
-- @param prefix Name prefix for added display fields
-- @param address Extra addressing information.
-- @param port Port to try and connect on (valid for IP address connections only)
-- @return boolean showing success of adding the framework, error message
-- @usage
-- local succeeded, err = device.addDisplay('R400')
function _M.addDisplay(type, prefix, address, port)
  local err

  prefix = prefix or ''

  --local success, disp  = pcall(require("rinLibrary.display." .. type))
  local success, disp = true, require("rinLibrary.display." .. type)
  if (success == false) then
    return false, disp
  end

  prefix = naming.canonicalisation(prefix);

  display, err = disp.add(private, display, prefix, address, port)
  
  if (err) then
    return nil, err
  end

  return true
end

-------------------------------------------------------------------------------
-- Show the status (net/gross, overload, etc.) on a display
-- @param displayDevice The display to mirror to
-- @param setting boolean value, true for mirror, false for off
function _M.mirrorStatus(displayDevice, setting)
  local name = naming.canonicalisation(displayDevice)
  displayDevice = naming.convertNameToValue(name or 'none', display)

  if (displayDevice and displayDevice.remote) then
    displayDevice.mirrorStatus = setting
    displayDevice.transmit(false)
  end
end

-------------------------------------------------------------------------------
-- Private function to update the status (if mirrorStatus enabled)
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

--- Display Fields.
--
-- These are use as the first arugment the the @see write and associated functions.
--
-- @table displayField
-- @field bottomLeft The bottom left field
-- @field bottomRight The bottom right field
-- @field topLeft The top left field
-- @field topRight The top right field

--- LCD Control Modes.
--@table lcdControlModes
-- @field default Set to a default setting (currently dual)
-- @field dual Change to dual display mode
-- @field lua Communication mode, necessary for LUA control
-- @field master Change to master display mode
-- @field product Change to product display mode
local currentLcdMode, lcdModes = 'default'
private.registerDeviceInitialiser(function()
    lcdModes = {
        default = private.batching(0) or private.k422(0) or 1,
        dual    = private.batching(0) or 1,                         -- dynamic
        lua     = private.batching(1) or 2,
        master  = private.batching(2) or 3,
        product = private.valueByDevice{ k402=0, k422=0, k491=0 }   -- normal
    }
end)

-------------------------------------------------------------------------------
-- Called to setup LCD control.
-- The rinApp framework generally takes care of calling this function for you.
-- However, sometimes you'll want to return control to the display device
-- for a time and grab control again later.
-- @param mode  is 'lua' to control display from script or 'default'
-- to return control to the default instrument application.
-- @return The previous mode setting
-- @usage
-- device.lcdControl('default')     -- let the display control itself
-- ...
-- device.lcdControl('lua')         -- switch on Lua display
function _M.lcdControl(mode)
    local oldMode = currentLcdMode
    currentLcdMode = mode
    local m = naming.convertNameToValue(mode, lcdModes, lcdModes.default)
    private.exReg(REG_LCDMODE, m)
    return oldMode
end

-------------------------------------------------------------------------------
-- Remove the timer associated with sliding the display, if present and
-- clean up
local function removeSlideTimer(f)
    timers.removeTimer(f.slideTimer)
    f.slideTimer = nil
end

-------------------------------------------------------------------------------
-- Query the auto register for a display field
-- @param f Display field
-- @return Register name
-- @local
local function readAuto(f)
    if f == nil or f.regAuto == nil then
        return nil
    end
    local reg = private.readRegDec(f.regAuto)
    reg = tonumber(reg)
    f.auto = reg
    return private.getRegisterName(reg)
end

-------------------------------------------------------------------------------
-- Set the auto register for a display field
-- @param f Display field
-- @param register Register name
-- @local
local function writeAuto(f, register)
    if f ~= nil and register ~= nil then
        local reg = private.getRegisterNumber(register)

        if f.regAuto ~= nil and reg ~= f.auto then
            removeSlideTimer(f)
            f.current = nil
            f.currentReg = nil
            private.writeRegHexAsync(f.regAuto, reg)
            f.saveAuto = f.auto or 0
            f.auto = reg
        end
    end
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
            dbg.error("K400LCD: unparsable display parameter:", t)
            return {}
        end
        return r
    elseif type(t) == 'table' then
        return deepcopy(t)
    end
    dbg.error("K400LCD: unknown display parameter:", tostring(t))
    return {}
end

-------------------------------------------------------------------------------
-- Write a message to the given display field.
-- @param f Display field.
-- @param s String to write
-- @param params Display parameters
-- @local
local function write(f, s, params)
    if f then
        removeSlideTimer(f)
        if s then
            local t = writeArgs(params)
            utils.checkCallback(t.finish)
            local wait = t.wait
            local once = t.once or wait or t.clear or t.restore or t.finish
            local time = math.max(t.time or 0.8, 0.2)
            local sync = t.sync

            if not t.finish then
                if t.restore then
                    local c, p, u, w = f.current, f.params, f.units1, f.units2
                    t.finish = function()
                        write(f, c, p)
                        f.writeUnits(f, u, w)
                    end
                elseif t.clear then
                    t.finish = function()
                        f.write(xform({''}, f.finalFormat)[1], false)
                        f.params, f.current, f.currentReg = nil, '', nil
                    end
                end
            end

            writeAuto(f, 0)
            f.params, f.current = t, tostring(s)
            local slidePos, slideWords = 1, splitWords(f, f.current, t.align)

            local function writeToDisplay(s)
                if f.currentReg ~= s then
                    f.currentReg = s
                    f.write(s, sync)
                end
            end
            writeToDisplay(slideWords[1])

            f.slideTimer = timers.addTimer(time, time, function()
                slidePos = private.addModBase1(slidePos, 1, #slideWords, true)
                if slidePos == 1 and once then
                    removeSlideTimer(f)
                    wait = false
                    utils.call(t.finish)
                elseif #slideWords == 1 then
                    removeSlideTimer(f)
                else
                    writeToDisplay(slideWords[slidePos])
                end
            end)
            _M.app.delayUntil(function() return not wait end)
        elseif f.auto == nil or f.auto == 0 then
            writeAuto(f, f.saveAuto)
        end

    end
end

-------------------------------------------------------------------------------
-- Apply a map to selected members of the display list
-- @param p Predicate that selects which elements to act on
-- @param f Function to apply
-- @local
local function map(p, f)
    for _, v in pairs(display) do
        if p(v) then f(v) end
    end
end

-------------------------------------------------------------------------------
-- Save the specified display fields and return a function that will restore
-- them to their current settings.
-- @param p Predicate that selects which elements to act on
-- @return Function to restore selected display elements
-- @local
local function saver(p)
    local restorations = {}
    map(p, function(v)
            table.insert(restorations, { f=v, c=v.current, p=v.params, u=v.units1, w=v.units2, wu=v.writeUnits })
        end)

    return function()
        for _, v in ipairs(restorations) do
            write(v.f, v.c, v.p)
            if (v.wu) then
              v.wu(v.u, v.w)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Save the all display fields and fields and units.
-- @return Function that restores the display fields to their current values
-- @usage
-- local restore = device.saveDisplay()
-- device.writeBotLeft('fnord')
-- restore()
function _M.saveDisplay()
    return saver(function(v) return v.localDisplay end)
end

-------------------------------------------------------------------------------
-- Save the bottom left and right fields and units.
-- @return Function that restores the bottom fields to their current values
-- @usage
-- local restoreBottom = device.saveBottom()
-- device.writeBotLeft('fnord')
-- restoreBottom()
function _M.saveBottom()
    return saver(function(v) return v.bottom end)
end


-------------------------------------------------------------------------------
-- Save the top and bottom left field auto settings
-- @return Function that restores the left auto fields to their current values
-- @usage
-- device.saveAutoLeft()
function _M.saveAutoLeft()
    local restorations = {}
    map(function(v) return v.left end,
        function(v)
            v.saveAuto = v.auto or 0
            table.insert(restorations, { f=v, a=v.saveAuto })
        end)
    return function()
        for _, v in ipairs(restorations) do
            writeAuto(v.f, v.a)
        end
    end
end

-------------------------------------------------------------------------------
-- Write string to thsi specified display section
-- @param where which display section to write to
-- @param s string to display
-- @param params displayControl parameter
-- @see displayField
-- @see displayControl
-- @usage
-- device.write('TopLeft', 'HELLO WORLD', 0.6)
function _M.write(where, s, params)
    write(naming.convertNameToValue(where, display), s, params)
end

-----------------------------------------------------------------------------
-- Link register address with display field to update automatically.
-- Not all fields support this functionality.
-- @param where which display section to write to
-- @param register address of register to link display to.
-- Set to 0 to enable direct control of the area
-- @see displayField
-- @usage
-- device.writeAuto('topLeft', 'grossnet')
function _M.writeAuto(where, register)
    return writeAuto(naming.convertNameToValue(where, display), register)
end

-----------------------------------------------------------------------------
-- Reads the current auto update register for the specified field
-- @return register that is being used for auto update, 0 if none
-- @see displayField
-- @usage
-- local old = device.readAuto('topLeft')
-- device.writeAuto('topLeft', 'none')
-- ...
-- device.writeAuto('topLeft', old)
function _M.readAuto(where)
    return readAuto(naming.convertNameToValue(where, display))
end

-------------------------------------------------------------------------------
-- Write string to Top Left of LCD.  The write interface is preferred.
-- @function writeTopLeft
-- @param s string to display
-- @param params displayControl parameter
-- @see write
-- @see displayControl
-- @usage
-- device.writeTopLeft('HELLO WORLD', 0.6)
function _M.writeTopLeft(s, params)
    return _M.write('topleft', s, params)
end

-------------------------------------------------------------------------------
-- Write string to Top Right of LCD.  The write interface is preferred.
-- @function writeTopRight
-- @param s string to display
-- @param params displayControl parameter
-- @see write
-- @see displayControl
-- @usage
-- device.writeTopRight('ABCD')
function _M.writeTopRight(s, params)
    return _M.write('topright', s, params)
end

-------------------------------------------------------------------------------
-- Write string to Bottom Left of LCD.  The write interface is preferred.
-- @function writeBotLeft
-- @param s string to display
-- @param params displayControl parameter
-- @see write
-- @see displayControl
-- @usage
-- device.writeBotLeft('AARDVARK BOTHER HORSES')
function _M.writeBotLeft(s, params)
    return _M.write('bottomleft', s, params)
end

-------------------------------------------------------------------------------
-- Write string to Bottom Right of LCD.  The write interface is preferred.
-- @function writeBotRight
-- @param s string to display
-- @param params deldisplayControl parameterssage
-- @see write
-- @see displayControl
-- @usage
-- device.writeBotRight('HORSES BOTHER AARDVARK')
function _M.writeBotRight(s, params)
    return _M.write('bottomright', s, params)
end

-----------------------------------------------------------------------------
-- Link register address with Top Left display to update automatically.
-- The writeAuto interface is preferred.
-- @function writeAutoTopLeft
-- @param register address of register to link Top Left display to.
-- Set to 0 to enable direct control of the area
-- @see writeAuto
-- @usage
-- device.writeAutoTopLeft('grossnet')
function _M.writeAutoTopLeft(param)
    return _M.writeAuto('topLeft', param)
end

-----------------------------------------------------------------------------
-- Reads the current Top Left auto update register
-- The readAuto interface is preferred.
-- @function readAutoTopLeft
-- @return register that is being used for auto update, 0 if none
-- @see readAuto
-- @usage
-- local old = device.readAutoTopLeft()
-- device.writeAuto('topLeft', 0)
-- ...
-- device.writeAuto('topLeft', old)
function _M.readAutoTopLeft()
    return _M.readAuto('topLeft')
end

-----------------------------------------------------------------------------
-- Link register address with Bottom Left display to update automatically
-- The writeAuto interface is preferred.
-- @function writeAutoBotLeft
-- @param register address of register to link Bottom Left display to.
-- Set to 0 to enable direct control of the area
-- @see writeAuto
-- @usage
-- device.writeAutoBotLeft('grossnet')
function _M.writeAutoBotLeft(param)
    return _M.writeAuto('bottomLeft', param)
end

-----------------------------------------------------------------------------
-- Reads the current Bottom Left auto update register
-- The readAuto interface is preferred.
-- @function readAutoBotLeft
-- @return register that is being used for auto update, 0 if none
-- @see readAuto
-- @usage
-- local old = device.readAutoBotLeft()
-- device.writeAuto('bottomLeft', 0)
-- ...
-- device.writeAuto('bottomLeft', old)
function _M.readAutoBotLeft()
    return _M.readAuto('bottomLeft')
end

-----------------------------------------------------------------------------
-- Link register address with Top annunciators to update automatically
-- @function writeAutoTopAnnun
-- @param register address of register to link Top Annunciator state to.
-- Set to 0 to enable direct control of the area.
-- @usage
-- device.writeAutoTopAnnun(0)
local writeAutoTopAnnun
private.registerDeviceInitialiser(function()
    writeAutoTopAnnun = private.exposeFunction('writeAutoTopAnnun', R400Reg.REG_DISP_AUTO_TOP_ANNUN, function(register)
        local r = private.getRegisterNumber(register)
        private.writeRegHexAsync(R400Reg.REG_DISP_AUTO_TOP_ANNUN, r)
    end)
end)

--- LCD Annunciators
-- These are the definitions of all the annunciators top, bottom, and remote.
-- Some displays may not support all annunciators. If an annunciator is not
-- supported, no action will occur.
--@table Annunciators
-- @field all All annunciators top and bottom
-- @field balance (top)
-- @field bal_sega (top)
-- @field bal_segb (top)
-- @field bal_segc (top)
-- @field bal_segd (top)
-- @field bal_sege (top)
-- @field bal_segf (top)
-- @field bal_segg (top)
-- @field bat_full Top battery charge bar (bottom)
-- @field bat_hi Second from top battery charge bar (bottom)
-- @field bat_midh Middle battery charge bar (bottom)
-- @field bat_midl Second from bottom battery charge bar (bottom)
-- @field bat_lo Bottom battery charge bar (bottom)
-- @field battery Battery icon (bottom)
-- @field clock (bottom)
-- @field coz (top)
-- @field hold (top)
-- @field motion (top, remote)
-- @field net (top, remote)
-- @field range_segadg (top)
-- @field range_segc (top)
-- @field range_sege (top)
-- @field range (top)
-- @field sigma (top)
-- @field wait135 Diagonal wait annunciator (bottom)
-- @field wait45 Diagonal wait annunciator (bottom)
-- @field wait90 Horizontal wait annunciator (bottom)
-- @field waitall All four wait annunciators (bottom)
-- @field wait Vertical wait annunciator (bottom)
-- @field zero (top, remote)
-- @field redlight Turn on the red traffic light (remote)
-- @field greenlight Turn on the green traffic light (remote)

--- Main Units
-- Some displays may not support all annunciators. If an annunciator is not
-- supported, no action will occur.
--@table Units
-- @field none No annunciator selected
-- @field kg Kilogram annunciator
-- @field lb Pound  annunciator
-- @field t Ton/Tonne  annunciator
-- @field g Gramme  annunciator
-- @field oz Ounce annunciator
-- @field n
-- @field arrow_l
-- @field p
-- @field l
-- @field arrow_h

--- Additional modifiers on bottom display
-- Some displays may not support all annunciators. If an annunciator is not
-- supported, no action will occur.
--@table Other
-- @field none No annuciator selected
-- @field hour Hour annunciator
-- @field minute Minute annunciator
-- @field percent Percent annunciator (includes slash)
-- @field per_h Per hour annunciator (slash + hour)
-- @field per_m Per meter annunciator (slash + minute)
-- @field per_s Per second annuicator (slash + second)
-- @field second Second annunicator
-- @field slash Slash line
-- @field total Total annunciator

-------------------------------------------------------------------------------
-- Turns the annunciators on
-- @param where which display section to write to
-- @param ... holds annunciator names
-- @usage
-- device.setAnnunciators('battery', 'clock', 'balance')
function _M.setAnnunciators(where, ...)
  local f = naming.convertNameToValue(where, display)

  if f then
    return f.setAnnun(...)
  else
    dbg.warn('setAnnunciators:', "deprecated. Use setAnnunciators(where, ...).")

    f = naming.convertNameToValue('topLeft', display)
    return f.setAnnun(where, ...)
 end

end

-------------------------------------------------------------------------------
-- Turns the annunciators off
-- @param where which display section to write to
-- @param ... holds annunciator names
-- @usage
-- device.clearAnnunciators('net', 'battery', 'hold')
function _M.clearAnnunciators(where, ...)
  local f = naming.convertNameToValue(where, display)

  if f then
    return f.clearAnnun(...)
  else
    dbg.warn('clearAnnunciators:', "deprecated. Use clearAnnunciators(where, ...).")

    f = naming.convertNameToValue('topLeft', display)
    return f.clearAnnun(where, ...)
  end

end

-------------------------------------------------------------------------------
-- Rotate the WAIT annunciator
-- @param where which display section to write to
-- @param dir 1 clockwise, -1 anticlockwise 0 no change
-- @usage
-- while true do
--     device.rotWAIT('topLeft', -1)
--     rinApp.delay(0.7)
-- end
local rotWaitWarnedDeprecated = false
function _M.rotWAIT(where, dir)
  local f = naming.convertNameToValue(where, display)

  if f and f.rotWAIT then
    return f.rotWait(dir)
  else
    if not rotWaitWarnedDeprecated then
        dbg.warn('rotWAIT:', "deprecated. Use rotWAIT(where, ...).")
        rotWaitWarnedDeprecated = true
    end

    f = naming.convertNameToValue('topLeft', display)
    return f.rotWait(dir)
  end
end

-------------------------------------------------------------------------------
-- Set units for specified field.
-- The other field isn't always supported.  Likewise, not all fields have units.
-- @param where which display section to write to
-- @param unts Unit to display
-- @param other ('per&#95;h', 'per&#95;m', 'per&#95;s', 'pc', 'tot')
-- @see displayField
-- @usage
-- device.writeUnits('topLeft', 'kg')
function _M.writeUnits(where, unts, other)

    local f = naming.convertNameToValue(where, display)

    if f then
      return f.writeUnits(unts, other)
    else
      return nil, nil, "Invalid name"
    end
end

-------------------------------------------------------------------------------
-- Set top units.  The writeUnits interface is preferred.
-- @param unts Unit to display
-- @see writeUnits
-- @usage
-- device.writeTopUnits('kg')
function _M.writeTopUnits(unts)
    return _M.writeUnits('topLeft', unts)
end

-------------------------------------------------------------------------------
-- Set bottom units.  The writeUnits interface is preferred.
-- @param unts Unit to display
-- @param other ('per&#95;h', 'per&#95;m', 'per&#95;s', 'pc', 'tot')
-- @see writeUnits
-- @usage
-- device.writeBotUnits('oz', 'per_m')
function _M.writeBotUnits(unts, other)
    return _M.writeUnits('bottomLeft', unts, other)
end

-------------------------------------------------------------------------------
-- Called to restore the LCD to its default state
-- @usage
-- device.restoreLcd()
function _M.restoreLcd()
    map(function(v) return v.localDisplay end, function(v) write(v, '') end)
    writeAuto(display.topleft, 'grossnet')
    writeAuto(display.bottomright, 0)

    writeAutoTopAnnun(0)
    _M.clearAnnunciators('bottomLeft', 'all')
    _M.writeUnits('bottomLeft', 'none')
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

-------------------------------------------------------------------------------
-- Notify the library that there is a remote display attached
-- @param name Name to be assigned to this display
-- @param type Type of the display
-- @param port Port used to communicate with the display
function _M.addRemoteDisplay(name, type, port)
    local d = nil
    display[canonical(name)] = d
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
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


deprecated.setAutoTopAnnun              = _M.writeAutoTopAnnun
deprecated.setAutoTopLeft               = _M.writeAutoTopLeft
deprecated.setAutoBotLeft               = _M.writeAutoBotLeft
deprecated.setBitsTopAnnuns             = _M.setAnnunciators
deprecated.clrBitsTopAnnuns             = _M.clearAnnunciators
deprecated.setBitsBotAnnuns             = _M.setAnnunciators
deprecated.clrBitsBotAnnuns             = _M.clearAnnunciators

-- Support the released function names with spelling errors :(
deprecated.setAnnunicators              = _M.setAnnunciators
deprecated.clearAnnunicators            = _M.clearAnnunciators

deprecated.BATTERY                      = 'battery'
deprecated.CLOCK                        = 'clock'
deprecated.BAT_LO                       = 'bat_lo'
deprecated.BAT_MIDL                     = 'bat_midl'
deprecated.BAT_MIDH                     = 'bat_midh'
deprecated.BAT_HI                       = 'bat_hi'
deprecated.BAT_FULL                     = 'bat_full'
deprecated.WAIT                         = 'wait'
deprecated.WAIT45                       = 'wait45'
deprecated.WAIT90                       = 'wait90'
deprecated.WAIT135                      = 'wait135'
deprecated.WAITALL                      = 'waitall'
deprecated.SIGMA                        = 'sigma'
deprecated.BALANCE                      = 'balance'
deprecated.COZ                          = 'coz'
deprecated.HOLD                         = 'hold'
deprecated.MOTION                       = 'motion'
deprecated.NET                          = 'net'
deprecated.RANGE                        = 'range'
deprecated.ZERO                         = 'zero'
deprecated.BAL_SEGA                     = 'bal_sega'
deprecated.BAL_SEGB                     = 'bal_segb'
deprecated.BAL_SEGC                     = 'bal_segc'
deprecated.BAL_SEGD                     = 'bal_segd'
deprecated.BAL_SEGE                     = 'bal_sege'
deprecated.BAL_SEGF                     = 'bal_segf'
deprecated.BAL_SEGG                     = 'bal_segg'
deprecated.RANGE_SEGADG                 = 'range_segadg'
deprecated.RANGE_SEGC                   = 'range_segc'
deprecated.RANGE_SEGE                   = 'range_sege'
deprecated.UNITS_NONE                   = 'none'
deprecated.UNITS_KG                     = 'kg'
deprecated.UNITS_LB                     = 'lb'
deprecated.UNITS_T                      = 't'
deprecated.UNITS_G                      = 'g'
deprecated.UNITS_OZ                     = 'oz'
deprecated.UNITS_N                      = 'n'
deprecated.UNITS_ARROW_L                = 'arrow_l'
deprecated.UNITS_P                      = 'p'
deprecated.UNITS_L                      = 'l'
deprecated.UNITS_ARROW_H                = 'arrow_h'
deprecated.UNITS_OTHER_PER_H            = 'per_h'
deprecated.UNITS_OTHER_PER_M            = 'per_m'
deprecated.UNITS_OTHER_PER_S            = 'per_s'
deprecated.UNITS_OTHER_PC               = 'pc'
deprecated.UNITS_OTHER_TOT              = 'total'

deprecated.rightJustify                 = dispHelp.rightJustify

-------------------------------------------------------------------------------
-- Save the bottom left and right fields and units.
-- Don't use this function, use saveBottom instead.
-- @function saveBot
-- @see saveBottom
-- @usage
-- device.saveBot()
-- device.writeBotLeft('fnord')
-- device.restoreBot()
function deprecated.saveBot()
    map(function(v) return v.bottom end,
        function(v)
            v.saveCurrent = v.current
            v.saveParams = v.params
            v.saveUnits1 = v.units1
            v.saveUnits2 = v.units2
        end)
end

-------------------------------------------------------------------------------
-- Restore the bottom left and right fields and units.
-- Don't use this function, use saveBottom instead.
-- @function restoreBot
-- @see saveBottom
-- @usage
-- device.saveBot()
-- device.writeBotLeft('fnord')
-- device.restoreBot()
function deprecated.restoreBot()
    map(function(v) return v.bottom end,
        function(v)
            write(v, v.saveCurrent, v.saveParams)
            v.nits(v.saveUnits1, v.saveUnits2)
        end)
end

if _TEST then
    _M.strLenLCD = dispHelp.strLenLCD
    _M.strSubLCD = dispHelp.strSubLCD
    _M.padDots    = dispHelp.padDots
    _M.splitWords = splitWords
    _M.convertAnnunciatorBits = R400Reg.convertAnnunciatorBits
end

end
