-------------------------------------------------------------------------------
-- Functions for working with VT100 terminal interface
-- @module rinLibrary.rinVT100
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

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
function set(s)
  io.write(s)
end
--------------------------------------------------------------------------------
-- Move Cursor to top left of screen
function csrHome()
  return('\27[H')
end

--------------------------------------------------------------------------------
-- Move Cursor to position x,y on screen
-- @param x horizontal position from left, 0 (default) is start
-- @param y vertical position from top, 0 (default) is top of screen

function csrXY(x,y)
  local x = x or 0
  local y = y or 0
  return(string.format('\27[%d;%df',y,x))
end

--------------------------------------------------------------------------------
-- Move Cursor up relative to current position
-- @param r is number of rows to move

function csrUp(r)
  local r = r or 0
  return(string.format('\27[%dA',r))
end

--------------------------------------------------------------------------------
-- Move Cursor down relative to current position
-- @param r is number of rows to move
function csrDown(r)
  local r = r or 0
  return(string.format('\27[%dB',r))
end

--------------------------------------------------------------------------------
-- Move Cursor left relative to current position
-- @param c is number of columns to move
function csrLeft(c)
  local c = c or 0
  return(string.format('\27[%dD',c))
end

--------------------------------------------------------------------------------
-- Move Cursor right relative to current position
-- @param c is number of columns to move

function csrRight(c)
  local c = c or 0
  return(string.format('\27[%dC',c))
end

--------------------------------------------------------------------------------
-- Save current cursor position
function csrSave()
  return('\27[s')
end

--------------------------------------------------------------------------------
-- Restore cursor to saved position
function csrRestore()
  return('\27[u')
end

--------------------------------------------------------------------------------
-- Clear terminal screen
  
function clrScreen()
 return('\27[2J')
end 

--------------------------------------------------------------------------------
-- Clear to end of line from cursor position 

function clrEol()
 return('\27[K')
end
 
--------------------------------------------------------------------------------
-- Clear to start of line from cursor position 
 
function clrSol()
  return ('\27[1K')
end  

--------------------------------------------------------------------------------
-- Clear current row

function clrRow()
  return ('\27[2K')
end  

--------------------------------------------------------------------------------
-- Clear all lines above current cursor position

function clrAbove()
  return ('\27[1J')
end  

--------------------------------------------------------------------------------
-- Clear all lines below current cursor position

function clrBelow()
  return ('\27[J')
end  

--------------------------------------------------------------------------------
-- Clear terminal attributes to default settings
function clrAttr() 
   return('\27[0m')
end 

--------------------------------------------------------------------------------
-- set terminal to scroll entire screen
function scrollAll() 
   return('\27[r')
end 

--------------------------------------------------------------------------------
-- set terminal to scroll only a section of the screen
-- @param r1 row to start scrolling area
-- @param r2 row to end scrolling area
function scrollSet(r1,r2) 
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




BGBlack = '40'
BGRed = '41'
BGGreen = '42'
BGYellow = '43'
BGBlue = '44'
BGMagenta = '45'
BGCyan = '46'
BGWhite = '47'

FGWhite = '37'
FGRed = '31'
FGGreen= '32'
FGYellow = '33'
FGBlue = '34'
FGMagenta = '35'
FGCyan = '36'
FGWhite = '37'

--------------------------------------------------------------------------------
-- set terminal attributes
-- @param fg foreground colours FG*
-- @param bg background colours BG*

function setAttr(fg,bg) 
   local fg = fg or FGWhite
   local bg = bg or BGBlack
   
   return '\27['..fg..';'..bg..'m'
end 

  
