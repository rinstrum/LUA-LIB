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
local function splitWords(s,len)
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
-- @param s Bit mask for the annunciators
-- @local
local function writeBotAnnuns(s)
    private.writeRegHexAsync(REG_DISP_BOTTOM_ANNUN, s)
end

-----------------------------------------------------------------------------
-- Set the top annunciators directly.
-- @param s Bit mask for the annunciators
-- @local
local function writeTopAnnuns(s)
    private.writeRegHexAsync(REG_DISP_TOP_ANNUN, s)
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

-------------------------------------------------------------------------------
-- Convert the annunciator bit maps to a value
-- @param t String to value table
-- @param l List of annunciators
-- @local
local function convertAnnunicatorBits(t, l)
    local res = 0
    for _, v in pairs(l) do
        res = bit32.bor(res, naming.convertNameToValue(v, t, 0))
    end
    return res
end

--- Bottom LCD Annunciators
--@table BotAnnuns
-- @field BATTERY
-- @field CLOCK
-- @field BAT_LO
-- @field BAT_MIDL
-- @field BAT_MIDH
-- @field BAT_HI
-- @field BAT_FULL
-- @field WAIT
-- @field WAIT45
-- @field WAIT90
-- @field WAIT135
-- @field WAITALL

-- REG_DISP_BOTTOM_ANNUN BIT SETTINGS
local BATTERY   = 0x0001
local CLOCK     = 0x0002
local BAT_LO    = 0x0004
local BAT_MIDL  = 0x0008
local BAT_MIDH  = 0x0010
local BAT_HI    = 0x0020
local BAT_FULL  = 0x003D
local WAIT      = 0x0040
local WAIT45    = 0x0100
local WAIT90    = 0x0200
local WAIT135   = 0x0080
local WAITALL   = 0x03C0
local WAIT_SEGS = { WAIT, WAIT45, WAIT90, WAIT135 }

local bottomAnnunicators = {
    battery     = BATTERY,
    clock       = CLOCK,
    bat_lo      = BAT_LO,
    bat_midl    = BAT_MIDL,
    bat_midh    = BAT_MIDH,
    bat_hi      = BAT_HI,
    bat_full    = BAT_FULL,
    wait        = WAIT,
    wait45      = WAIT45,
    wait90      = WAIT90,
    wait135     = WAIT135,
    waitall     = WAITALL
}

-------------------------------------------------------------------------------
-- Sets the annunciator bits for Bottom Annunciators
-- @param ... holds bit locations
-- @usage
-- device.setBitsBotAnnuns('battery', 'clock')
function _M.setBitsBotAnnuns(...)
    local bits = convertAnnunicatorBits(bottomAnnunicators, {...})
    botAnnunState = bit32.bor(botAnnunState, bits)
    writeBotAnnuns(botAnnunState)
end

-------------------------------------------------------------------------------
-- Clears the annunciator bits for Bottom Annunciators
-- @param ... holds bit locations
-- @usage
-- device.clrBitsBotAnnuns('battery')
function _M.clrBitsBotAnnuns(...)
    local bits = convertAnnunicatorBits(bottomAnnunicators, {...})
    botAnnunState = bit32.band(botAnnunState, bit32.bnot(bits))
    writeBotAnnuns(botAnnunState)
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
    writeBotAnnuns(botAnnunState)
end

--- Top LCD Annunciators
--@table TopAnnuns
-- @field SIGMA
-- @field BALANCE
-- @field COZ
-- @field HOLD
-- @field MOTION
-- @field NET
-- @field RANGE
-- @field ZERO
-- @field BAL_SEGA
-- @field BAL_SEGB
-- @field BAL_SEGC
-- @field BAL_SEGD
-- @field BAL_SEGE
-- @field BAL_SEGF
-- @field BAL_SEGG
-- @field RANGE_SEGADG
-- @field RANGE_SEGC
-- @field RANGE_SEGE

-- REG_DISP_TOP_ANNUN BIT SETTINGS
local SIGMA        = 0x00001
local BALANCE      = 0x00002
local COZ          = 0x00004
local HOLD         = 0x00008
local MOTION       = 0x00010
local NET          = 0x00020
local RANGE        = 0x00040
local ZERO         = 0x00080
local BAL_SEGA     = 0x00100
local BAL_SEGB     = 0x00200
local BAL_SEGC     = 0x00400
local BAL_SEGD     = 0x00800
local BAL_SEGE     = 0x01000
local BAL_SEGF     = 0x02000
local BAL_SEGG     = 0x04000
local RANGE_SEGADG = 0x08000
local RANGE_SEGC   = 0x10000
local RANGE_SEGE   = 0x20000

local topAnnunicators = {
    sigma           = SIGMA,
    balance         = BALANCE,
    coz             = COZ,
    hold            = HOLD,
    motion          = MOTION,
    net             = NET,
    range           = RANGE,
    zero            = ZERO,
    bal_sega        = BAL_SEGA,
    bal_segb        = BAL_SEGB,
    bal_segc        = BAL_SEGC,
    bal_segd        = BAL_SEGD,
    bal_sege        = BAL_SEGE,
    bal_segf        = BAL_SEGF,
    bal_segg        = BAL_SEGG,
    range_segadg    = RANGE_SEGADG,
    range_segc      = RANGE_SEGC,
    range_sege      = RANGE_SEGE
}

-------------------------------------------------------------------------------
-- Sets the annunciator bits for Top Annunciators
-- @param ... holds bit locations
-- @usage
-- device.setBitsTopAnnuns('sigma', 'motion', 'zero', 'range')
function _M.setBitsTopAnnuns(...)
    local bits = convertAnnunicatorBits(topAnnunicators, {...})
    topAnnunState = bit32.bor(topAnnunState, bits)
    writeTopAnnuns(topAnnunState)
end

-------------------------------------------------------------------------------
-- Clears the annunciator bits for Top Annunciators
-- @param d holds bit locations
-- @usage
-- device.clrBitsTopAnnuns('net', 'hold')
function _M.clrBitsTopAnnuns(...)
    local bits = convertAnnunicatorBits(topAnnunicators, {...})
    topAnnunState = bit32.band(topAnnunState, bit32.bnot(bits))
    writeTopAnnuns(topAnnunState)
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
deprecated.writeBotAnnuns               =  writeBotAnnuns           
deprecated.writeTopAnnuns               = writeTopAnnuns
deprecated.setAutoBotLeft               = _M.writeAutoBotLeft

deprecated.BATTERY                      = BATTERY
deprecated.CLOCK                        = CLOCK
deprecated.BAT_LO                       = BAT_LO
deprecated.BAT_MIDL                     = BAT_MIDL
deprecated.BAT_MIDH                     = BAT_MIDH
deprecated.BAT_HI                       = BAT_HI
deprecated.BAT_FULL                     = BAT_FULL
deprecated.WAIT                         = WAIT
deprecated.WAIT45                       = WAIT45
deprecated.WAIT90                       = WAIT90
deprecated.WAIT135                      = WAIT135
deprecated.WAITALL                      = WAITALL
deprecated.SIGMA                        = SIGMA
deprecated.BALANCE                      = BALANCE
deprecated.COZ                          = COZ
deprecated.HOLD                         = HOLD
deprecated.MOTION                       = MOTION
deprecated.NET                          = NET
deprecated.RANGE                        = RANGE
deprecated.ZERO                         = ZERO
deprecated.BAL_SEGA                     = BAL_SEGA
deprecated.BAL_SEGB                     = BAL_SEGB
deprecated.BAL_SEGC                     = BAL_SEGC
deprecated.BAL_SEGD                     = BAL_SEGD
deprecated.BAL_SEGE                     = BAL_SEGE
deprecated.BAL_SEGF                     = BAL_SEGF
deprecated.BAL_SEGG                     = BAL_SEGG
deprecated.RANGE_SEGADG                 = RANGE_SEGADG
deprecated.RANGE_SEGC                   = RANGE_SEGC
deprecated.RANGE_SEGE                   = RANGE_SEGE
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

