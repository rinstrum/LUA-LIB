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
local bit32 = require "bit"

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
  return(len)
end

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
  return(substr)
end

-- takes a string and pads ... with . . . for R420 to handle
local function padDots(s)
    if #s == 0 then
        return s
    end
    local str = string.gsub(s,'%.%.','%. %.')
    str = string.gsub(str,'%.%.','%. %.')
    if string.sub(str,1,1) == '.' then
        str = ' '..str
    end
    return(str)
end

-- local function to split a long string into shorter strings of multiple words
-- that fit into length len
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
return function (_M)

--LCD display registers
_M.REG_DISP_BOTTOM_LEFT     = 0x000E    -- Takes string
_M.REG_DISP_BOTTOM_RIGHT    = 0x000F    -- Takes string
_M.REG_DISP_TOP_LEFT        = 0x00B0    -- Takes string
_M.REG_DISP_TOP_RIGHT       = 0x00B1    -- Takes string
_M.REG_DISP_TOP_ANNUN       = 0x00B2
_M.REG_DISP_TOP_UNITS       = 0x00B3    -- Takes string
_M.REG_DISP_BOTTOM_ANNUN    = 0x00B4
_M.REG_DISP_BOTTOM_UNITS    = 0x00B5

_M.REG_DISP_AUTO_TOP_ANNUN  = 0x00B6    -- Register number  REG_*
_M.REG_DISP_AUTO_TOP_LEFT   = 0x00B7    -- Register number  REG_*
_M.REG_DISP_AUTO_BOTTOM_LEFT= 0x00B8    -- Register number  REG_*

_M.REG_BUZ_LEN      = 0x0327
_M.REG_BUZ_NUM      = 0x0328

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

function _M.saveBot()
   saveBotLeft = curBotLeft
   saveBotRight = curBotRight
   saveBotUnits = curBotUnits
   saveBotUnitsOther = curBotUnitsOther
end

function _M.restoreBot()
  _M.writeBotLeft(saveBotLeft)
  _M.writeBotRight(saveBotRight)
  _M.writeBotUnits(saveBotUnits, saveBotUnitsOther)
end

function _M.saveAutoLeft()
    saveAutoTopLeft = _M.readAutoTopLeft()
    saveAutoBotLeft = _M.readAutoBotLeft()
end

local function slideTopLeft()
    local function dispWord()
        _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_TOP_LEFT,
             string.format('%-6s',padDots(slideTopLeftWords[slideTopLeftPos])))
     end
    slideTopLeftPos = slideTopLeftPos + 1
    if slideTopLeftPos > #slideTopLeftWords then
       slideTopLeftPos = 1
       dispWord()
       return
    end
    dispWord()
end

-------------------------------------------------------------------------------
-- Write string to Top Left of LCD, curTopLeft is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
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
            if slideTopLeftTimer then     -- remove any running display
                _M.system.timers.removeTimer(slideTopLeftTimer)
            end
            _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_TOP_LEFT,
                 string.format('%-6s',padDots(slideTopLeftWords[slideTopLeftPos])))
            if #slideTopLeftWords > 1 then
                slideTopLeftTimer = _M.system.timers.addTimer(t,t,slideTopLeft)
            end
        end
    elseif curAutoTopLeft == 0 then
       _M.writeAutoTopLeft(saveAutoTopLeft)
    end
end

-------------------------------------------------------------------------------
-- Write string to Top Right of LCD, curTopRight is set to s
-- @param s string to display
function _M.writeTopRight(s)
    if s then
        if s ~= curTopRight then
           _M.sendReg(_M.CMD_WRFINALHEX, _M.REG_DISP_TOP_RIGHT, s)
           curTopRight = s
        end
    end
end

local function slideBotLeft()
    local function dispWord()
        _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_LEFT,
             string.format('%-9s',padDots(slideBotLeftWords[slideBotLeftPos])))
     end
    slideBotLeftPos = slideBotLeftPos + 1
    if slideBotLeftPos > #slideBotLeftWords then
       slideBotLeftPos = 1
       dispWord()
       return
    end
    dispWord()
end

-------------------------------------------------------------------------------
-- Write string to Bottom Left of LCD, curBotLeft is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
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
            _M.system.timers.removeTimer(slideBotLeftTimer)
            _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_LEFT,
                 string.format('%-9s',padDots(slideBotLeftWords[slideBotLeftPos])))
            if #slideBotLeftWords > 1 then
                slideBotLeftTimer = _M.system.timers.addTimer(t,t,slideBotLeft)
            end
        end
    elseif curAutoBotLeft == 0 then
       _M.writeAutoBotLeft(saveAutoBotLeft)
    end
end

local function slideBotRight()
    local function dispWord()
        _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_RIGHT,
             string.format('%-8s',padDots(slideBotRightWords[slideBotRightPos])))
     end
    slideBotRightPos = slideBotRightPos + 1
    if slideBotRightPos > #slideBotRightWords then
       slideBotRightPos = 1
       dispWord()
       return
    end
    dispWord()
end

-------------------------------------------------------------------------------
-- Write string to Bottom Right of LCD, curBotRight is set to s
-- @param s string to display
-- @param t delay in seconds between display of sections of a large message
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
            _M.system.timers.removeTimer(slideBotRightTimer)
            _M.sendReg(_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_RIGHT,
                 string.format('%-8s',padDots(slideBotRightWords[slideBotRightPos])))
            if #slideBotRightWords > 1 then
                slideBotRightTimer = _M.system.timers.addTimer(t,t,slideBotRight)
            end
        end
    end
end

_M.writeBotAnnuns   = _M.preconfigureMsg(_M.REG_DISP_BOTTOM_ANNUN,
                                         _M.CMD_WRFINALHEX,
                                         "noReply")
_M.writeTopAnnuns   = _M.preconfigureMsg(_M.REG_DISP_TOP_ANNUN,
                                         _M.CMD_WRFINALHEX,
                                         "noReply")

-----------------------------------------------------------------------------
-- link register address  with Top annunciators to update automatically
--@function writeAutoTopAnnun
--@param reg address of register to link Top Annunciator state to.
-- Set to 0 to enable direct control of the area
_M.writeAutoTopAnnun  = _M.preconfigureMsg(_M.REG_DISP_AUTO_TOP_ANNUN,
                                         _M.CMD_WRFINALHEX,
                                         "noReply")

_M.setAutoTopAnnun = _M.writeAutoTopAnnun

-----------------------------------------------------------------------------
-- link register address with Top Left display to update automatically
--@param reg address of register to link Top Left display to.
-- Set to 0 to enable direct control of the area
function _M.writeAutoTopLeft(reg)
   if reg ~= curAutoTopLeft then
       if slideTopLeftTimer then     -- remove any running display
          _M.system.timers.removeTimer(slideTopLeftTimer)
       end
       curTopLeft = nil
       _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_DISP_AUTO_TOP_LEFT, reg, "noReply")
       saveAutoTopLeft = curAutoTopLeft
       curAutoTopLeft = reg
   end
end

_M.setAutoTopLeft = _M.writeAutoTopLeft

-----------------------------------------------------------------------------
-- reads the current Top Left auto update register
-- @return register that is being used for auto update, 0 if none
function _M.readAutoTopLeft()
   local reg = _M.sendRegWait(_M.CMD_RDFINALDEC,_M.REG_DISP_AUTO_TOP_LEFT)
   reg = tonumber(reg)
   curAutoTopLeft = reg
   return reg
end
-----------------------------------------------------------------------------
-- link register address with Bottom Left display to update automatically
--@param reg address of register to link Bottom Left display to.
-- Set to 0 to enable direct control of the area
function _M.writeAutoBotLeft(reg)
   if reg ~= curAutoBotLeft then
      _M.system.timers.removeTimer(slideBotLeftTimer)
       curBotLeft = nil
       _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_DISP_AUTO_BOTTOM_LEFT, reg, "noReply")
       saveAutoBotLeft = curAutoBotLeft
       curAutoBotLeft = reg
   end
end
_M.setAutoBotLeft = _M.writeAutoBotLeft

-----------------------------------------------------------------------------
-- reads the current Bottom Left auto update register
-- @return register that is being used for auto update, 0 if none
function _M.readAutoBotLeft()
   local reg = _M.sendRegWait(_M.CMD_RDFINALDEC,_M.REG_DISP_AUTO_BOTTOM_LEFT)
   reg = tonumber(reg)
   curAutoBotLeft = reg
   return reg
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
_M.BATTERY   = 0x0001
_M.CLOCK     = 0x0002
_M.BAT_LO    = 0x0004
_M.BAT_MIDL  = 0x0008
_M.BAT_MIDH  = 0x0010
_M.BAT_HI    = 0x0020
_M.BAT_FULL  = 0x003D
_M.WAIT      = 0x0040
_M.WAIT45    = 0x0100
_M.WAIT90    = 0x0200
_M.WAIT135   = 0x0080
_M.WAITALL   = 0x03C0
local WAIT_SEGS = { _M.WAIT, _M.WAIT45, _M.WAIT90, _M.WAIT135 }

-------------------------------------------------------------------------------
-- Sets the annunciator bits for Bottom Annunciators
-- @param d holds bit locations
function _M.setBitsBotAnnuns(d)
  botAnnunState = bit32.bor(botAnnunState, d)
  _M.writeBotAnnuns(botAnnunState)
end

-------------------------------------------------------------------------------
-- Clears the annunciator bits for Bottom Annunciators
-- @param d holds bit locations
function _M.clrBitsBotAnnuns(d)
  botAnnunState = bit32.band(botAnnunState, bit32.bnot(d))
  _M.writeBotAnnuns(botAnnunState)
end

-------------------------------------------------------------------------------
-- Rotate the WAIT annunciator
-- @param dir  1 clockwise, -1 anticlockwise 0 no change
function _M.rotWAIT(dir)
    if dir ~= 0 then
        waitPos = (waitPos - dir / math.abs(dir)) % #WAIT_SEGS
        if waitPos == 0 then waitPos = #WAIT_SEGS end
    end

    botAnnunState = bit32.band(botAnnunState, bit32.bnot(_M.WAITALL))
    botAnnunState = bit32.bor(botAnnunState, WAIT_SEGS[waitPos])
    _M.writeBotAnnuns(botAnnunState)
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
_M.SIGMA        = 0x00001
_M.BALANCE      = 0x00002
_M.COZ          = 0x00004
_M.HOLD         = 0x00008
_M.MOTION       = 0x00010
_M.NET          = 0x00020
_M.RANGE        = 0x00040
_M.ZERO         = 0x00080
_M.BAL_SEGA     = 0x00100
_M.BAL_SEGB     = 0x00200
_M.BAL_SEGC     = 0x00400
_M.BAL_SEGD     = 0x00800
_M.BAL_SEGE     = 0x01000
_M.BAL_SEGF     = 0x02000
_M.BAL_SEGG     = 0x04000
_M.RANGE_SEGADG = 0x08000
_M.RANGE_SEGC   = 0x10000
_M.RANGE_SEGE   = 0x20000

-------------------------------------------------------------------------------
-- Sets the annunciator bits for Top Annunciators
-- @param d holds bit locations
function _M.setBitsTopAnnuns(d)
  topAnnunState = bit32.bor(topAnnunState, d)
  _M.writeTopAnnuns(topAnnunState)
end

-------------------------------------------------------------------------------
-- Clears the annunciator bits for Top Annunciators
-- @param d holds bit locations
function _M.clrBitsTopAnnuns(d)
  topAnnunState = bit32.band(topAnnunState, bit32.bnot(d))
  _M.writeTopAnnuns(topAnnunState)
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
_M.UNITS_NONE    = 0x00
_M.UNITS_KG      = 0x01
_M.UNITS_LB      = 0x02
_M.UNITS_T       = 0x03
_M.UNITS_G       = 0x04
_M.UNITS_OZ      = 0x05
_M.UNITS_N       = 0x06
_M.UNITS_ARROW_L = 0x07
_M.UNITS_P       = 0x08
_M.UNITS_L       = 0x09
_M.UNITS_ARROW_H = 0x0A

--- Additional modifiers on bottom display
--@table Other
-- @field UNITS_OTHER_PER_H
-- @field UNITS_OTHER_PER_M
-- @field UNITS_OTHER_PER_S
-- @field UNITS_OTHER_PC
-- @field UNITS_OTHER_TOT
_M.UNITS_OTHER_PER_H   = 0x14
_M.UNITS_OTHER_PER_M   = 0x11
_M.UNITS_OTHER_PER_S   = 0x12
_M.UNITS_OTHER_PC      = 0x30
_M.UNITS_OTHER_TOT     = 0x08

-------------------------------------------------------------------------------
-- Set top units
-- @param units (.UNITS_NONE etc)
function _M.writeTopUnits (units)
   local units = units or _M.UNITS_NONE
   _M.writeReg(_M.REG_DISP_TOP_UNITS,units)
   curTopUnits = units
end
-------------------------------------------------------------------------------
-- Set bottom units
-- @param units (.UNITS_NONE etc)
-- @param other (.UNITS_OTHER_PER_H etc)
function _M.writeBotUnits (units, other)
   local units = units or _M.UNITS_NONE
   local other = other or _M.UNITS_NONE
   _M.writeReg(_M.REG_DISP_BOTTOM_UNITS,bit32.bor(bit32.lshift(other,8),units))
   curBotUnits = units
   curBotUnitsOther = other
end

-------------------------------------------------------------------------------
-- Called to restore the LCD to its default state
function _M.restoreLcd()
   _M.writeAutoTopAnnun(0)
   _M.writeAutoTopLeft(_M.REG_GROSSNET)
   _M.writeAutoBotLeft(0)
   _M.writeTopRight('')
   _M.writeBotLeft('')
   _M.writeBotRight('')
   _M.writeBotAnnuns(0)
   _M.writeBotUnits()
end


end

