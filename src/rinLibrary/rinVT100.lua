-------------------------------------------------------------------------------
-- Functions for working with VT100 terminal interface
-- @module rinLibrary.rinVT100
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M= {}


-------------------------------------------------------------------------------
-- Send an escape sequence to the terminal
-- @param s string containing escape sequence to send
-- @usage
-- VT100 = require rinLibrary.rinVT100
--
-- VT100.set(VT100.csrHome()..VT100.setAttr(VT100.FGRed,VT100.BGBlack)
--
-- print('Hello'..VT100.csrLeft(10)..'There')
------------------------------------------------------------------------------
function _M.set(s)
  io.write(s)
end
--------------------------------------------------------------------------------
-- Move Cursor to top left of screen
function _M.csrHome()
  return('\27[H')
end

--------------------------------------------------------------------------------
-- Move Cursor to position x,y on screen
-- @param x horizontal position from left, 0 (default) is start
-- @param y vertical position from top, 0 (default) is top of screen

function _M.csrXY(x,y)
  local x = x or 0
  local y = y or 0
  return(string.format('\27[%d;%df',y,x))
end

--------------------------------------------------------------------------------
-- Move Cursor up relative to current position
-- @param r is number of rows to move

function _M.csrUp(r)
  local r = r or 0
  return(string.format('\27[%dA',r))
end

--------------------------------------------------------------------------------
-- Move Cursor down relative to current position
-- @param r is number of rows to move
function _M.csrDown(r)
  local r = r or 0
  return(string.format('\27[%dB',r))
end

--------------------------------------------------------------------------------
-- Move Cursor left relative to current position
-- @param c is number of columns to move
function _M.csrLeft(c)
  local c = c or 0
  return(string.format('\27[%dD',c))
end

--------------------------------------------------------------------------------
-- Move Cursor right relative to current position
-- @param c is number of columns to move

function _M.csrRight(c)
  local c = c or 0
  return(string.format('\27[%dC',c))
end

--------------------------------------------------------------------------------
-- Save current cursor position
function _M.csrSave()
  return('\27[s')
end

--------------------------------------------------------------------------------
-- Restore cursor to saved position
function _M.csrRestore()
  return('\27[u')
end

--------------------------------------------------------------------------------
-- Clear terminal screen
  
function _M.clrScreen()
 return('\27[2J')
end 

--------------------------------------------------------------------------------
-- Clear to end of line from cursor position 

function _M.clrEol()
 return('\27[K')
end
 
--------------------------------------------------------------------------------
-- Clear to start of line from cursor position 
 
function _M.clrSol()
  return ('\27[1K')
end  

--------------------------------------------------------------------------------
-- Clear current row

function _M.clrRow()
  return ('\27[2K')
end  

--------------------------------------------------------------------------------
-- Clear all lines above current cursor position

function _M.clrAbove()
  return ('\27[1J')
end  

--------------------------------------------------------------------------------
-- Clear all lines below current cursor position

function _M.clrBelow()
  return ('\27[J')
end  

--------------------------------------------------------------------------------
-- Clear terminal attributes to default settings
function _M.clrAttr() 
   return('\27[0m')
end 

--------------------------------------------------------------------------------
-- set terminal to scroll entire screen
function _M.scrollAll() 
   return('\27[r')
end 

--------------------------------------------------------------------------------
-- set terminal to scroll only a section of the screen
-- @param r1 row to start scrolling area
-- @param r2 row to end scrolling area
function _M.scrollSet(r1,r2) 
   return(string.format('\27[%d;%dr',r1,r2))
end 


-- Screen Attributes
--@table attr
--@field BGattr  Background colours
--@field BGBlack 
--@field BGRed 
--@field BGGreen 
--@field BGYellow 
--@field BGBlue  
--@field BGMagenta
--@field BGCyan  
--@field BGWhite
--@field FGattr Foreground colours 
--@field FGWhite 
--@field FGRed 
--@field FGGreen 
--@field FGYellow 
--@field FGBlue  
--@field FGMagenta
--@field FGCyan  
--@field FGWhite




_M.BGBlack = '40'
_M.BGRed = '41'
_M.BGGreen = '42'
_M.BGYellow = '43'
_M.BGBlue = '44'
_M.BGMagenta = '45'
_M.BGCyan = '46'
_M.BGWhite = '47'

_M.FGWhite = '37'
_M.FGRed = '31'
_M.FGGreen= '32'
_M.FGYellow = '33'
_M.FGBlue = '34'
_M.FGMagenta = '35'
_M.FGCyan = '36'
_M.FGWhite = '37'


_M.lastFG = _M.FGWhite
_M.lastBG = _M.BGBlack
--------------------------------------------------------------------------------
-- set terminal attributes
-- @param fg foreground colours FG*
-- @param bg background colours BG*

function _M.setAttr(fg,bg) 
   local fg = fg or _M.FGWhite
   local bg = bg or _M.BGBlack
   
   return '\27['..fg..';'..bg..'m'
end 

--------------------------------------------------------------------------------
-- restores last terminal attributes
function _M.restoreAttr()
   return(_M.setAttr(_M.lastFG, _M.lastBG))
end   
  
return _M