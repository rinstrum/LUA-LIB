-------------------------------------------------------------------------------
--- LCD Services.
-- Functions to configure the LCD
-- @module rinLibrary.K400LCD
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local tonumber = tonumber
local math = math
local string = string
local bit32 = require "bit"
local timers = require 'rinSystem.rinTimers.Pack'
local naming = require 'rinLibrary.namings'
local dbg = require "rinLibrary.rinDebug"

-------------------------------------------------------------------------------
-- Return the number of LCD characters a string will consume.
-- @param s The string to assess
-- @return The number of display characters
-- @local
local function strLenR400(s)
    local len = 0
    local dotFound = true
    for i = 1,#s do
        local ch = string.sub(s,i,i)
        if not dotFound and  ch == '.' then
            dotFound = true
        else
            if ch ~= '.' then
                dotFound = false
            end
            len = len + 1
        end
    end
    return len
end

-------------------------------------------------------------------------------
-- @local
local function strSubR400(s,stPos,endPos)
   local len = 0
   local dotFound = true
   local substr = ''
   if stPos < 1 then
       stPos = #s + stPos + 1
   end
   if endPos < 1 then
       endPos = #s + endPos + 1
   end

   for i = 1,#s do
     local ch = string.sub(s,i,i)
     if not dotFound and  ch == '.' then
         dotFound = true
     else
        if ch ~= '.' then
           dotFound = false
        end
        len = len + 1
     end
     if (len >= stPos) and (len <= endPos) then
          substr = substr .. ch
     end
   end
  return substr
end

-------------------------------------------------------------------------------
-- Takes a string and pads ... with . . . for R420 to handle.
-- @param s String
-- @return Padded string
-- @local
local function padDots(s)
    if #s == 0 then
        return s
    end
    local str = string.gsub(s,'%.%.','%. %.')
    str = string.gsub(str,'%.%.','%. %.')
    if string.sub(str,1,1) == '.' then
        str = ' '..str
    end
    return str
end

-------------------------------------------------------------------------------
-- Split a long string into shorter strings of multiple words
-- that fit into length len.
-- @param s String
-- @param len Length of display field
-- @return list of fragments of the string formatted to fit the field width
-- @local
local function splitWords(s, len)
    s = tostring(s)
    local t = {}
    local p = ''
    local len = len or 8

    if strLenR400(s) <= len then
        table.insert(t,s)
        return t
    end

    for w in string.gmatch(s, "%S+") do
        if strLenR400(p) + strLenR400(w) < len then
            if p == '' then
                p = w
            else
                p = p .. ' '..w
            end
        elseif strLenR400(p) > len then
            table.insert(t,strSubR400(p,1,len))
            p = strSubR400(p,len+1,-1)
            if strLenR400(p) + strLenR400(w) < len then
                p = p .. ' ' .. w
            else
                table.insert(t,p)
                p = w
            end
        else
            if #p > 0 then
                table.insert(t,p)
            end
            p = w
        end
    end

    while strLenR400(p) > len do
        table.insert(t,strSubR400(p,1,len))
        p = strSubR400(p,len+1,-1)
    end
    if #p > 0 or #t == 0 then
        table.insert(t,p)
    end
    return t
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--LCD display registers
local REG_LCDMODE              = 0x000D
local REG_DISP_BOTTOM_LEFT     = 0x000E    -- Takes string
local REG_DISP_BOTTOM_RIGHT    = 0x000F    -- Takes string
local REG_DISP_TOP_LEFT        = 0x00B0    -- Takes string
local REG_DISP_TOP_RIGHT       = 0x00B1    -- Takes string
local REG_DISP_TOP_ANNUN       = 0x00B2
local REG_DISP_TOP_UNITS       = 0x00B3    -- Takes string
local REG_DISP_BOTTOM_ANNUN    = 0x00B4
local REG_DISP_BOTTOM_UNITS    = 0x00B5

local REG_DISP_AUTO_TOP_ANNUN  = 0x00B6    -- Register number  REG_*
local REG_DISP_AUTO_TOP_LEFT   = 0x00B7    -- Register number  REG_*
local REG_DISP_AUTO_BOTTOM_LEFT= 0x00B8    -- Register number  REG_*

--local REG_DEFAULTMODE          = 0x0166

local botAnnunState = 0
local topAnnunState = 0
local waitPos = 1

local curTopLeft = ''
local curTopRight = ''
local curBotLeft = ''
local curBotRight = ''
local curTopUnits = 0
local curBotUnits = 0
local curBotUnitsOther = 0
local curAutoTopLeft = 0
local curAutoBotLeft = 0

local saveBotLeft = ''
local saveAutoTopLeft = 0
local saveAutoBotLeft = 0
local saveBotRight = ''
local saveBotUnits = 0
local saveBotUnitsOther = 0

local slideBotLeftPos, slideBotLeftWords, slideBotLeftTimer
local slideBotRightPos, slideBotRightWords, slideBotRightTimer
local slideTopLeftPos, slideTopLeftWords, slideTopLeftTimer

--- LCD Control Modes.
--@table lcdControlModes
-- @field default Set to a default setting (currently dual)
-- @field dual Change to dual display mode
-- @field lua Commuication mode, necessary for LUA control
-- @field master Change to master display mode
-- @field product Change to product display mode
local lcdModes = {
    default = private.k410(0) or 1,
    dual    = private.k410(0) or 1,
    lua     = private.k410(1) or 2,
    master  = private.k410(2) or 3,
    product = private.k402(0) or private.k491(0)
}

-------------------------------------------------------------------------------
-- Called to setup LCD control.
-- The rinApp framework generally takes care of calling this function for you.
-- However, sometimes you'll want to return control to the display device
-- for a time and grab control again later.
-- @param mode  is 'lua' to control display from script or 'default'
-- to return control to the default instrument application
-- @usage
-- device.lcdControl('default')     -- let the display control itself
-- ...
-- device.lcdControl('lua')         -- switch on Lua display
function _M.lcdControl(mode)
    mode = mode or 'default'
    local m = lcdModes[mode]
    if m == nil then
        dbg.error("K400LCD: unknown lcd mode: ", mode)
        m = lcdModes.default
    end
    private.exReg(REG_LCDMODE, m)
end

-------------------------------------------------------------------------------
-- Right justify a string in a given field
-- @param s string to justify
-- @param w width to justify to
-- @return justified string
-- @usage
-- if device.rightJustify('hello', 6) == ' hello' then
--     print('yes')
-- end
function _M.rightJustify(s, w)
    s = tostring(s)
    local l = strLenR400(s)
    if l >= w then
        return s
    end
    return string.rep(" ", w-l) .. s
end

-------------------------------------------------------------------------------
-- Save the bottom left and right fields and units.
-- @usage
-- device.saveBot()
-- device.writeBotLeft('fnord')
-- device.restoreBot()
function _M.saveBot()
    saveBotLeft = curBotLeft
    saveBotRight = curBotRight
    saveBotUnits = curBotUnits
    saveBotUnitsOther = curBotUnitsOther
end

-------------------------------------------------------------------------------
-- Restore the bottom left and right fields and units.
-- @usage
-- device.saveBot()
-- device.writeBotLeft('fnord')
-- device.restoreBot()
function _M.restoreBot()
    _M.writeBotLeft(saveBotLeft)
    _M.writeBotRight(saveBotRight)
    _M.writeBotUnits(saveBotUnits, saveBotUnitsOther)
end

-------------------------------------------------------------------------------
-- Save the top and bottom left field auto settings
-- @usage
-- device.saveAutoLeft()
function _M.saveAutoLeft()
    saveAutoTopLeft = _M.readAutoTopLeft()
    saveAutoBotLeft = _M.readAutoBotLeft()
end

-------------------------------------------------------------------------------
-- Shift the top left display section one position
-- @local
local function slideTopLeft()
    slideTopLeftPos = slideTopLeftPos + 1
    if slideTopLeftPos > #slideTopLeftWords then
       slideTopLeftPos = 1
    end
    private.writeRegHexAsync(REG_DISP_TOP_LEFT,
         string.format('%-6s',padDots(slideTopLeftWords[slideTopLeftPos])))
end

-------------------------------------------------------------------------------
-- Write string to Top Left of LCD, curTopLeft is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
-- @usage
-- device.writeTopLeft('HELLO WORLD', 0.6)
function _M.writeTopLeft(s,t)
    local t = t or 0.8

    if t < 0.2 then
       t = 0.2
    end
    if s then
        if s ~= curTopLeft then
            _M.writeAutoTopLeft(0)
            curTopLeft = s
            slideTopLeftWords = splitWords(s,6)
            slideTopLeftPos = 1
            timers.removeTimer(slideTopLeftTimer)
            private.writeRegHexAsync(REG_DISP_TOP_LEFT,
                 string.format('%-6s',padDots(slideTopLeftWords[slideTopLeftPos])))
            if #slideTopLeftWords > 1 then
                slideTopLeftTimer = timers.addTimer(t, t, slideTopLeft)
            end
        end
    elseif curAutoTopLeft == 0 then
       _M.writeAutoTopLeft(saveAutoTopLeft)
    end
end

-------------------------------------------------------------------------------
-- Write string to Top Right of LCD, curTopRight is set to s
-- @param s string to display
-- @usage
-- device.writeTopRight('ABCD')
function _M.writeTopRight(s)
    if s and s ~= curTopRight then
        private.writeRegHexAsync(REG_DISP_TOP_RIGHT, s)
        curTopRight = s
    end
end

-------------------------------------------------------------------------------
-- Shift the bottom left display section one position
-- @local
local function slideBotLeft()
    slideBotLeftPos = slideBotLeftPos + 1
    if slideBotLeftPos > #slideBotLeftWords then
       slideBotLeftPos = 1
    end
    private.writeRegHexAsync(REG_DISP_BOTTOM_LEFT,
         string.format('%-9s',padDots(slideBotLeftWords[slideBotLeftPos])))
end

-------------------------------------------------------------------------------
-- Write string to Bottom Left of LCD, curBotLeft is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
-- @usage
-- device.writeBotLeft('AARDVARK BOTHER HORSES')
function _M.writeBotLeft(s, t)
    local t = t or 0.8

    if t < 0.2 then
       t = 0.2
    end

    if s then
        if s ~= curBotLeft then
            _M.writeAutoBotLeft(0)
            curBotLeft = s
            slideBotLeftWords = splitWords(s,9)
            slideBotLeftPos = 1
            timers.removeTimer(slideBotLeftTimer)
            private.writeRegHexAsync(REG_DISP_BOTTOM_LEFT,
                 string.format('%-9s',padDots(slideBotLeftWords[slideBotLeftPos])))
            if #slideBotLeftWords > 1 then
                slideBotLeftTimer = timers.addTimer(t, t, slideBotLeft)
            end
        end
    elseif curAutoBotLeft == 0 then
       _M.writeAutoBotLeft(saveAutoBotLeft)
    end
end

-------------------------------------------------------------------------------
-- Shift the bottom right display section one position
-- @local
local function slideBotRight()
    slideBotRightPos = slideBotRightPos + 1
    if slideBotRightPos > #slideBotRightWords then
       slideBotRightPos = 1
    end
    private.writeRegHexAsync(REG_DISP_BOTTOM_RIGHT,
         string.format('%-8s',padDots(slideBotRightWords[slideBotRightPos])))
end

-------------------------------------------------------------------------------
-- Write string to Bottom Right of LCD, curBotRight is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
-- @usage
-- device.writeBotRight('AARDVARK BOTHER HORSES')
function _M.writeBotRight(s, t)
    local t = t or 0.8

    if t < 0.2 then
       t = 0.2
    end

    if s then
        if s ~= curBotRight then
            curBotRight = s
            slideBotRightWords = splitWords(s,8)
            slideBotRightPos = 1
            timers.removeTimer(slideBotRightTimer)
            private.writeRegHexAsync(REG_DISP_BOTTOM_RIGHT,
                 string.format('%-8s',padDots(slideBotRightWords[slideBotRightPos])))
            if #slideBotRightWords > 1 then
                slideBotRightTimer = timers.addTimer(t, t, slideBotRight)
            end
        end
    end
end


-----------------------------------------------------------------------------
-- Set the bottom annunciators directly.
-- @local
local function writeBotAnnuns()
    private.writeRegHexAsync(REG_DISP_BOTTOM_ANNUN, botAnnunState)
end

-----------------------------------------------------------------------------
-- Set the top annunciators directly.
-- @local
local function writeTopAnnuns()
    private.writeRegHexAsync(REG_DISP_TOP_ANNUN, topAnnunState)
end

-----------------------------------------------------------------------------
-- Link register address with Top annunciators to update automatically
-- @param reg address of register to link Top Annunciator state to.
-- Set to 0 to enable direct control of the area.
-- @usage
-- device.writeAutoTopAnnun(0)
function _M.writeAutoTopAnnun(reg)
    local r = private.getRegisterNumber(reg)
    private.writeRegHexAsync(REG_DISP_AUTO_TOP_ANNUN, r)
end


-----------------------------------------------------------------------------
-- Link register address with Top Left display to update automatically
-- @param register address of register to link Top Left display to.
-- Set to 0 to enable direct control of the area
-- @usage
-- device.writeAutoTopLeft('grossnet')
function _M.writeAutoTopLeft(register)
    local reg = private.getRegisterNumber(register)

    if reg ~= curAutoTopLeft then
        timers.removeTimer(slideTopLeftTimer)
        curTopLeft = nil
        private.writeRegHexAsync(REG_DISP_AUTO_TOP_LEFT, reg)
        saveAutoTopLeft = curAutoTopLeft
        curAutoTopLeft = reg
    end
end

-----------------------------------------------------------------------------
-- Reads the current Top Left auto update register
-- @return register that is being used for auto update, 0 if none
-- @usage
-- local old = device.readAutoTopLeft()
-- device.writeAutoTopLeft(0)
-- ...
-- device.writeAutoTopLeft(old)
function _M.readAutoTopLeft()
    local reg = private.readRegDec(REG_DISP_AUTO_TOP_LEFT)
    reg = tonumber(reg)
    curAutoTopLeft = reg
    return private.getRegisterName(reg)
end

-----------------------------------------------------------------------------
-- Link register address with Bottom Left display to update automatically
-- @param register address of register to link Bottom Left display to.
-- Set to 0 to enable direct control of the area
-- @usage
-- device.writeAutoBotLeft('grossnet')
function _M.writeAutoBotLeft(register)
    local reg = private.getRegisterNumber(register)

    if reg ~= curAutoBotLeft then
        timers.removeTimer(slideBotLeftTimer)
        curBotLeft = nil
        private.writeRegHexAsync(REG_DISP_AUTO_BOTTOM_LEFT, reg)
        saveAutoBotLeft = curAutoBotLeft
        curAutoBotLeft = reg
    end
end

-----------------------------------------------------------------------------
-- reads the current Bottom Left auto update register
-- @return register that is being used for auto update, 0 if none
-- @usage
-- local old = device.readAutoBotLeft()
-- device.writeAutoBotLeft(0)
-- ...
-- device.writeAutoBotLeft(old)
function _M.readAutoBotLeft()
    local reg = private.readRegDec(REG_DISP_AUTO_BOTTOM_LEFT)
    reg = tonumber(reg)
    curAutoBotLeft = reg
    return private.getRegisterName(reg)
end

--- LCD Annunciators
-- These are the definitions of all the annunicators top and bottom.
--@table Annunicators
-- @field sigma (top)
-- @field balance (top)
-- @field coz (top)
-- @field hold (top)
-- @field motion (top)
-- @field net (top)
-- @field range (top)
-- @field zero (top)
-- @field bal_sega (top)
-- @field bal_segb (top)
-- @field bal_segc (top)
-- @field bal_segd (top)
-- @field bal_sege (top)
-- @field bal_segf (top)
-- @field bal_segg (top)
-- @field range_segadg (top)
-- @field range_segc (top)
-- @field range_sege (top)
-- @field battery (bottom)
-- @field clock (bottom)
-- @field bat_lo (bottom)
-- @field bat_midl (bottom)
-- @field bat_midh (bottom)
-- @field bat_hi (bottom)
-- @field bat_full (bottom)
-- @field wait (bottom)
-- @field wait45 (bottom)
-- @field wait90 (bottom)
-- @field wait135 (bottom)
-- @field waitall (bottom)

-- REG_DISP_BOTTOM_ANNUN BIT SETTINGS
local WAIT      = 0x0040
local WAIT45    = 0x0100
local WAIT90    = 0x0200
local WAIT135   = 0x0080
local WAITALL   = 0x03C0
local WAIT_SEGS = { WAIT, WAIT45, WAIT90, WAIT135 }

-- REG_DISP_TOP_ANNUN BIT SETTINGS
local annunicatorMap = {
    sigma           = { v=0x00001,  locn='top' },
    balance         = { v=0x00002,  locn='top' },
    coz             = { v=0x00004,  locn='top' },
    hold            = { v=0x00008,  locn='top' },
    motion          = { v=0x00010,  locn='top' },
    net             = { v=0x00020,  locn='top' },
    range           = { v=0x00040,  locn='top' },
    zero            = { v=0x00080,  locn='top' },
    bal_sega        = { v=0x00100,  locn='top' },
    bal_segb        = { v=0x00200,  locn='top' },
    bal_segc        = { v=0x00400,  locn='top' },
    bal_segd        = { v=0x00800,  locn='top' },
    bal_sege        = { v=0x01000,  locn='top' },
    bal_segf        = { v=0x02000,  locn='top' },
    bal_segg        = { v=0x04000,  locn='top' },
    range_segadg    = { v=0x08000,  locn='top' },
    range_segc      = { v=0x10000,  locn='top' },
    range_sege      = { v=0x20000,  locn='top' },
    battery         = { v=0x0001,   locn='bottom' },
    clock           = { v=0x0002,   locn='bottom' },
    bat_lo          = { v=0x0004,   locn='bottom' },
    bat_midl        = { v=0x0008,   locn='bottom' },
    bat_midh        = { v=0x0010,   locn='bottom' },
    bat_hi          = { v=0x0020,   locn='bottom' },
    bat_full        = { v=0x003D,   locn='bottom' },
    wait            = { v=WAIT,     locn='bottom' },
    wait45          = { v=WAIT45,   locn='bottom' },
    wait90          = { v=WAIT90,   locn='bottom' },
    wait135         = { v=WAIT135,  locn='bottom' },
    waitall         = { v=WAITALL,  locn='bottom' }
}

-------------------------------------------------------------------------------
-- Convert the annunciator bit maps to a list of values
-- @param l List of annunciators
-- @return table of bit mask values for 'top' and 'bottom'
-- @local
local function convertAnnunicatorBits(l)
    local res = { top = 0, bottom = 0, unknown = 0 }
    local missing = { v=1, locn='unknown' }

    for _, v in pairs(l) do
        local bit = naming.convertNameToValue(v, annunicatorMap, missing)
        res[bit.locn] = bit32.bor(res[bit.locn], bit.v)
    end
    return res
end

-------------------------------------------------------------------------------
-- Turns the annunciators on
-- @param ... holds annunicator names
-- @usage
-- device.setAnnunicators('battery', 'clock', 'balance')
function _M.setAnnunicators(...)
    local bits = convertAnnunicatorBits{...}

    if bits.bottom ~= 0 then
        botAnnunState = bit32.bor(botAnnunState, bits.bottom)
        writeBotAnnuns()
    end

    if bits.top ~= 0 then
        topAnnunState = bit32.bor(topAnnunState, bits.top)
        writeTopAnnuns()
    end
end

-------------------------------------------------------------------------------
-- Turns the annunciators off
-- @param ... holds annunicator names
-- @usage
-- device.setAnnunicators('net', 'battery', 'hold')
function _M.clearAnnunicators(...)
    local bits = convertAnnunicatorBits{...}

    if bits.bottom ~= 0 then
        botAnnunState = bit32.band(botAnnunState, bit32.bnot(bits.bottom))
        writeBotAnnuns()
    end

    if bits.top ~= 0 then
        topAnnunState = bit32.band(topAnnunState, bit32.bnot(bits.top))
        writeTopAnnuns()
    end
end

-------------------------------------------------------------------------------
-- Rotate the WAIT annunciator
-- @param dir 1 clockwise, -1 anticlockwise 0 no change
-- @usage
-- while true do
--     device.rotWAIT(-1)
--     device.delay(0.7)
-- end
function _M.rotWAIT(dir)
    if dir ~= 0 then
        waitPos = (waitPos - dir / math.abs(dir)) % #WAIT_SEGS
        if waitPos == 0 then waitPos = #WAIT_SEGS end
    end

    botAnnunState = bit32.band(botAnnunState, bit32.bnot(WAITALL))
    botAnnunState = bit32.bor(botAnnunState, WAIT_SEGS[waitPos])
    writeBotAnnuns()
end

--- Main Units
--@table Units
-- @field UNITS_NONE
-- @field UNITS_KG
-- @field UNITS_LB
-- @field UNITS_T
-- @field UNITS_G
-- @field UNITS_OZ
-- @field UNITS_N
-- @field UNITS_ARROW_L
-- @field UNITS_P
-- @field UNITS_L
-- @field UNITS_ARROW_H
-- REG_DISP UNITS BIT SETTINGS
local UNITS_NONE    = 0x00
local UNITS_KG      = 0x01
local UNITS_LB      = 0x02
local UNITS_T       = 0x03
local UNITS_G       = 0x04
local UNITS_OZ      = 0x05
local UNITS_N       = 0x06
local UNITS_ARROW_L = 0x07
local UNITS_P       = 0x08
local UNITS_L       = 0x09
local UNITS_ARROW_H = 0x0A

local unitAnnunicators = {
    none      = UNITS_NONE,
    kg        = UNITS_KG,
    lb        = UNITS_LB,
    t         = UNITS_T,
    g         = UNITS_G,
    oz        = UNITS_OZ,
    n         = UNITS_N,
    arrow_l   = UNITS_ARROW_L,
    p         = UNITS_P,
    l         = UNITS_L,
    arrow_h   = UNITS_ARROW_H
}

--- Additional modifiers on bottom display
--@table Other
-- @field UNITS_OTHER_PER_H
-- @field UNITS_OTHER_PER_M
-- @field UNITS_OTHER_PER_S
-- @field UNITS_OTHER_PC
-- @field UNITS_OTHER_TOT
local UNITS_OTHER_PER_H   = 0x14
local UNITS_OTHER_PER_M   = 0x11
local UNITS_OTHER_PER_S   = 0x12
local UNITS_OTHER_PC      = 0x30
local UNITS_OTHER_TOT     = 0x08

local otherAunnunictors = {
    per_h   = UNITS_OTHER_PER_H,
    per_m   = UNITS_OTHER_PER_M,
    per_s   = UNITS_OTHER_PER_S,
    pc      = UNITS_OTHER_PC,
    tot     = UNITS_OTHER_TOT
}

-------------------------------------------------------------------------------
-- Set top units
-- @param units (.UNITS_NONE etc)
-- @usage
-- device.writeTopUnits('kg')
function _M.writeTopUnits (units)
    local u = naming.convertNameToValue(units, unitAnnunicators, UNITS_NONE)

    private.writeReg(REG_DISP_TOP_UNITS, u)
    curTopUnits = u
end

-------------------------------------------------------------------------------
-- Set bottom units
-- @param units (.UNITS_NONE etc)
-- @param other (.UNITS_OTHER_PER_H etc)
-- @usage
-- device.writeBotUnits('oz', 'per_m')
function _M.writeBotUnits (units, other)
    local u = naming.convertNameToValue(units, unitAnnunicators, UNITS_NONE)
    local o = naming.convertNameToValue(other, otherAunnunictors, UNITS_NONE)

    private.writeReg(REG_DISP_BOTTOM_UNITS, bit32.bor(bit32.lshift(o, 8), u))
    curBotUnits = u
    curBotUnitsOther = o
end

-------------------------------------------------------------------------------
-- Called to restore the LCD to its default state
-- @usage
-- device.restoreLcd()
function _M.restoreLcd()
    _M.writeAutoTopAnnun(0)
    _M.writeAutoTopLeft('grossnet')
    _M.writeAutoBotLeft(0)
    _M.writeTopRight('')
    _M.writeBotLeft('')
    _M.writeBotRight('')
    writeBotAnnuns(0)
    _M.writeBotUnits()
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_LCDMODE                  = REG_LCDMODE
deprecated.REG_DISP_BOTTOM_LEFT         = REG_DISP_BOTTOM_LEFT
deprecated.REG_DISP_BOTTOM_RIGHT        = REG_DISP_BOTTOM_RIGHT
deprecated.REG_DISP_TOP_LEFT            = REG_DISP_TOP_LEFT
deprecated.REG_DISP_TOP_RIGHT           = REG_DISP_TOP_RIGHT
deprecated.REG_DISP_TOP_ANNUN           = REG_DISP_TOP_ANNUN
deprecated.REG_DISP_TOP_UNITS           = REG_DISP_TOP_UNITS
deprecated.REG_DISP_BOTTOM_ANNUN        = REG_DISP_BOTTOM_ANNUN
deprecated.REG_DISP_BOTTOM_UNITS        = REG_DISP_BOTTOM_UNITS
deprecated.REG_DISP_AUTO_TOP_ANNUN      = REG_DISP_AUTO_TOP_ANNUN
deprecated.REG_DISP_AUTO_TOP_LEFT       = REG_DISP_AUTO_TOP_LEFT
deprecated.REG_DISP_AUTO_BOTTOM_LEFT    = REG_DISP_AUTO_BOTTOM_LEFT

deprecated.setAutoTopAnnun              = _M.writeAutoTopAnnun
deprecated.setAutoTopLeft               = _M.writeAutoTopLeft
deprecated.writeBotAnnuns               = function(s) botAnnunState = s writeBotAnnuns() end
deprecated.writeTopAnnuns               = function(s) topAnnunState = s writeTopAnnuns() end
deprecated.setAutoBotLeft               = _M.writeAutoBotLeft
deprecated.setBitsTopAnnuns             = setBitsTopAnnuns
deprecated.clrBitsTopAnnuns             = clrBitsTopAnnuns
deprecated.setBitsBotAnnuns             = setAnnunicators
deprecated.clrBitsBotAnnuns             = clearAnnunicators

deprecated.BATTERY                      = annunicatorMap.battery.v
deprecated.CLOCK                        = annunicatorMap.clock.v
deprecated.BAT_LO                       = annunicatorMap.bat_lo.v
deprecated.BAT_MIDL                     = annunicatorMap.bat_midl.v
deprecated.BAT_MIDH                     = annunicatorMap.bat_midh.v
deprecated.BAT_HI                       = annunicatorMap.bat_hi.v
deprecated.BAT_FULL                     = annunicatorMap.bat_full.v
deprecated.WAIT                         = annunicatorMap.wait.v
deprecated.WAIT45                       = annunicatorMap.wait45.v
deprecated.WAIT90                       = annunicatorMap.wait90.v
deprecated.WAIT135                      = annunicatorMap.wait135.v
deprecated.WAITALL                      = annunicatorMap.waitall.v
deprecated.SIGMA                        = annunicatorMap.sigma.v
deprecated.BALANCE                      = annunicatorMap.balance.v
deprecated.COZ                          = annunicatorMap.coz.v
deprecated.HOLD                         = annunicatorMap.hold.v
deprecated.MOTION                       = annunicatorMap.motion.v
deprecated.NET                          = annunicatorMap.net.v
deprecated.RANGE                        = annunicatorMap.range.v
deprecated.ZERO                         = annunicatorMap.zero.v
deprecated.BAL_SEGA                     = annunicatorMap.bal_sega.v
deprecated.BAL_SEGB                     = annunicatorMap.bal_segb.v
deprecated.BAL_SEGC                     = annunicatorMap.bal_segc.v
deprecated.BAL_SEGD                     = annunicatorMap.bal_segd.v
deprecated.BAL_SEGE                     = annunicatorMap.bal_sege.v
deprecated.BAL_SEGF                     = annunicatorMap.bal_segf.v
deprecated.BAL_SEGG                     = annunicatorMap.bal_segg.v
deprecated.RANGE_SEGADG                 = annunicatorMap.range_segadg.v
deprecated.RANGE_SEGC                   = annunicatorMap.range_segc.v
deprecated.RANGE_SEGE                   = annunicatorMap.range_sege.v
deprecated.UNITS_NONE                   = UNITS_NONE
deprecated.UNITS_KG                     = UNITS_KG
deprecated.UNITS_LB                     = UNITS_LB
deprecated.UNITS_T                      = UNITS_T
deprecated.UNITS_G                      = UNITS_G
deprecated.UNITS_OZ                     = UNITS_OZ
deprecated.UNITS_N                      = UNITS_N
deprecated.UNITS_ARROW_L                = UNITS_ARROW_L
deprecated.UNITS_P                      = UNITS_P
deprecated.UNITS_L                      = UNITS_L
deprecated.UNITS_ARROW_H                = UNITS_ARROW_H
deprecated.UNITS_OTHER_PER_H            = UNITS_OTHER_PER_H
deprecated.UNITS_OTHER_PER_M            = UNITS_OTHER_PER_M
deprecated.UNITS_OTHER_PER_S            = UNITS_OTHER_PER_S
deprecated.UNITS_OTHER_PC               = UNITS_OTHER_PC
deprecated.UNITS_OTHER_TOT              = UNITS_OTHER_TOT

end

