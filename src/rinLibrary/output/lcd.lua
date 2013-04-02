-------------------------------------------------------------------------------
-- Handles LCD output
-- @module lcd
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local bit32 = bit

--LCD display registers
_M.REG_DISP_BOTTOM_LEFT		= 0x000E	-- Takes string
_M.REG_DISP_BOTTOM_RIGHT 	= 0x000F	-- Takes string
_M.REG_DISP_TOP_LEFT		= 0x00A0	-- Takes string
_M.REG_DISP_TOP_RIGHT		= 0x00A1	-- Takes string
_M.REG_DISP_TOP_ANNUN		= 0x00A2
_M.REG_DISP_TOP_UNITS		= 0x00A3	-- Takes string
_M.REG_DISP_BOTTOM_ANNUN	= 0x00A4
_M.REG_DISP_BOTTOM_UNITS	= 0x00A5

_M.REG_DISP_AUTO_TOP_ANNUN	= 0x00A6	-- Register number  REG_*
_M.REG_DISP_AUTO_TOP_LEFT	= 0x00A7	-- Register number  REG_*
_M.REG_DISP_AUTO_BOTTOM_LEFT= 0x00A8	-- Register number  REG_*

_M.REG_BUZ_LEN      = 0x0327
_M.REG_BUZ_NUM      = 0x0328

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

-- REG_DISP_TOP_ANNUN BIT SETTINGS
_M.SIGMA		= 0x00001
_M.BALANCE		= 0x00002
_M.COZ			= 0x00004
_M.HOLD			= 0x00008
_M.MOTION		= 0x00010
_M.NET			= 0x00020
_M.RANGE		= 0x00040
_M.ZERO			= 0x00080
_M.BAL_SEGA		= 0x00100
_M.BAL_SEGB		= 0x00200
_M.BAL_SEGC		= 0x00400
_M.BAL_SEGD		= 0x00800
_M.BAL_SEGE		= 0x01000
_M.BAL_SEGF		= 0x02000
_M.BAL_SEGG		= 0x04000
_M.RANGE_SEGADG	= 0x08000
_M.RANGE_SEGC   = 0x10000
_M.RANGE_SEGE	= 0x20000


_M.botAnnunState = 0
_M.topAnnunState = 0
_M.waitPos = _M.WAIT

-------------------------------------------------------------------------------
-- Write string to Bottom Left of LCD, curBotLeft is set to s
-- @param s string to display
function _M.writeBotLeft(s)
   if s then
     _M.send(nil,_M.CMD_WRFINALHEX,_M.REG_DISP_BOTTOM_LEFT,  s, "noReply")
     _M.curBotLeft = s
   end	 
end

-------------------------------------------------------------------------------
-- Write string to Bottom Right of LCD, curBotRight is set to s
-- @param s string to display
function _M.writeBotRight(s)
   if s then
      _M.send(nil, _M.CMD_WRFINALHEX, _M.REG_DISP_BOTTOM_RIGHT, s, "noReply")
      _M.curBotRight = s
   end	  
end   

_M.writeBotAnnuns = _M.preconfigureMsg(_M.REG_DISP_BOTTOM_ANNUN, _M.CMD_WRFINALHEX, "noReply")
_M.writeBotUnits  = _M.preconfigureMsg(_M.REG_DISP_BOTTOM_UNITS, _M.CMD_WRFINALHEX, "noReply")

_M.writeTopLeft   = _M.preconfigureMsg(_M.REG_DISP_TOP_LEFT, _M.CMD_WRFINALHEX, "noReply")
_M.writeTopRight  = _M.preconfigureMsg(_M.REG_DISP_TOP_RIGHT, _M.CMD_WRFINALHEX, "noReply")
_M.writeTopAnnuns = _M.preconfigureMsg(_M.REG_DISP_TOP_ANNUN, _M.CMD_WRFINALHEX, "noReply")
_M.writeTopUnits  = _M.preconfigureMsg(_M.REG_DISP_TOP_UNITS, _M.CMD_WRFINALHEX, "noReply")
  
_M.setAutoTopAnnun  = _M.preconfigureMsg(_M.REG_DISP_AUTO_TOP_ANNUN, _M.CMD_WRFINALHEX, "noReply")
_M.setAutoTopLeft   = _M.preconfigureMsg(_M.REG_DISP_AUTO_TOP_LEFT, _M.CMD_WRFINALHEX, "noReply")
_M.setAutoBotLeft   = _M.preconfigureMsg(_M.REG_DISP_AUTO_BOTTOM_LEFT, _M.CMD_WRFINALHEX, "noReply")

  
-------------------------------------------------------------------------------
-- Sets the annunciator bits for Bottom Annunciators
-- @param d holds bit locations
function _M.setBitsBotAnnuns(d)
  _M.botAnnunState = bit32.bor(_M.botAnnunState,d)
  _M.writeBotAnnuns(_M.botAnnunState)
end

-------------------------------------------------------------------------------
-- Clears the annunciator bits for Bottom Annunciators
-- @param d holds bit locations
function _M.clrBitsBotAnnuns(d)
  _M.botAnnunState = bit32.band(_M.botAnnunState,bit32.bnot(d))
  _M.writeBotAnnuns(_M.botAnnunState)
end

-------------------------------------------------------------------------------
-- Rotate the WAIT annunciator 
-- @param dir  1 clockwise, -1 anticlockwise 0 no change
function _M.rotWAIT(dir)

  if _M.waitPos == _M.WAIT then
     if dir > 0 then _M.waitPos = _M.WAIT45 elseif dir < 0 then _M.waitPos = _M.WAIT135 end
  elseif _M.waitPos == _M.WAIT45 then
     if dir > 0 then _M.waitPos = _M.WAIT90 elseif dir < 0 then _M.waitPos = _M.WAIT end
  elseif _M.waitPos == _M.WAIT90 then
     if dir > 0 then _M.waitPos = _M.WAIT135 elseif dir < 0 then _M.waitPos = _M.WAIT45 end
  else   -- Must be WAIT135
     if dir > 0 then _M.waitPos = _M.WAIT elseif dir < 0 then _M.waitPos = _M.WAIT90 end
  end
 
  _M.botAnnunState = bit32.band(_M.botAnnunState,bit32.bnot(_M.WAITALL))
 
  _M.botAnnunState = bit32.bor(_M.botAnnunState,_M.waitPos)
  _M.writeBotAnnuns(_M.botAnnunState)  
  
end

-------------------------------------------------------------------------------
-- Sets the annunciator bits for Top Annunciators
-- @param d holds bit locations
function _M.setBitsTopAnnuns(d)
  _M.topAnnunState = bit32.bor(_M.topAnnunState,d)
  _M.writeTopAnnuns(_M.topAnnunState)
end

-------------------------------------------------------------------------------
-- Clears the annunciator bits for Top Annunciators
-- @param d holds bit locations
function _M.clrBitsTopAnnuns(d)
  _M.topAnnunState = bit32.band(_M.topAnnunState,bit32.bnot(d))
  _M.writeTopAnnuns(_M.topAnnunState)
end

-------------------------------------------------------------------------------
-- Called to restore the LCD to its default state
function _M.restoreLcd()
   _M.setAutoTopAnnun(_M.REG_GROSSNET)
   _M.setAutoTopLeft(_M.REG_GROSSNET)
   _M.writeTopRight('')
   _M.writeBotLeft('')
   _M.writeBotRight('')
   _M.writeBotAnnuns(0)
end

return _M