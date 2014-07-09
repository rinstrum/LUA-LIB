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
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrHome()..VT100.setAttr('red', 'black'))
--
-- print('Hello'..VT100.csrLeft(10)..'There')
------------------------------------------------------------------------------
function _M.set(s)
    io.write(s)
end

--------------------------------------------------------------------------------
-- Move Cursor to top left of screen
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrHome())
function _M.csrHome()
    return '\27[H'
end

--------------------------------------------------------------------------------
-- Move Cursor to position x,y on screen
-- @param x horizontal position from left, 0 (default) is start
-- @param y vertical position from top, 0 (default) is top of screen
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrXY(20, 12))
function _M.csrXY(x, y)
    return string.format('\27[%d;%df', y or 0, x or 0)
end

--------------------------------------------------------------------------------
-- Move Cursor up relative to current position
-- @param r is number of rows to move
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrUp(3))
function _M.csrUp(r)
    return string.format('\27[%dA', r or 0)
end

--------------------------------------------------------------------------------
-- Move Cursor down relative to current position
-- @param r is number of rows to move
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.csrDown(5)
function _M.csrDown(r)
    return string.format('\27[%dB', r or 0)
end

--------------------------------------------------------------------------------
-- Move Cursor left relative to current position
-- @param c is number of columns to move
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrLeft(7))
function _M.csrLeft(c)
    return string.format('\27[%dD', c or 0)
end

--------------------------------------------------------------------------------
-- Move Cursor right relative to current position
-- @param c is number of columns to move
-- @usage
-- local VT100 = require rinLibrary.rinVT100
--
-- VT100.set(VT100.csrRight(11))
function _M.csrRight(c)
    return string.format('\27[%dC', c or 0)
end

--------------------------------------------------------------------------------
-- Save current cursor position
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrSave())
-- VT100.set(VT100.csrHome())
-- VT100.set(VT100.csrRestore())
function _M.csrSave()
    return '\27[s'
end

--------------------------------------------------------------------------------
-- Restore cursor to saved position
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrSave())
-- VT100.set(VT100.csrXY(13, 17))
-- VT100.set(VT100.csrRestore())
function _M.csrRestore()
    return '\27[u'
end

--------------------------------------------------------------------------------
-- Clear terminal screen
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.clrScreen())
function _M.clrScreen()
    return '\27[2J'
end

--------------------------------------------------------------------------------
-- Clear to end of line from cursor position
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.csrXY(23, 19)
-- VT100.clrEol()
function _M.clrEol()
    return '\27[K'
end

--------------------------------------------------------------------------------
-- Clear to start of line from cursor position
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrXY(6, 18)..VT100.clrSol())
function _M.clrSol()
    return '\27[1K'
end

--------------------------------------------------------------------------------
-- Clear current row
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.csrXY(6, 18)
-- VT100.clrRow()
function _M.clrRow()
    return '\27[2K'
end

--------------------------------------------------------------------------------
-- Clear all lines above current cursor position
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrXY(12, 4)..VT100.clrAbove())
function _M.clrAbove()
    return '\27[1J'
end

--------------------------------------------------------------------------------
-- Clear all lines below current cursor position
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.csrXY(3, 17)..VT100.clrBelow())
function _M.clrBelow()
    return '\27[J'
end

--------------------------------------------------------------------------------
-- Clear terminal attributes to default settings
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.clrAttr())
function _M.clrAttr()
   return '\27[0m'
end

--------------------------------------------------------------------------------
-- set terminal to scroll entire screen
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.scrollAll())
function _M.scrollAll()
   return '\27[r'
end

--------------------------------------------------------------------------------
-- set terminal to scroll only a section of the screen
-- @param r1 row to start scrolling area
-- @param r2 row to end scrolling area
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.scrollSet(16, 22))
function _M.scrollSet(r1, r2)
   return string.format('\27[%d;%dr', r1, r2)
end

-- Screen Attributes
--@table attr
--@field Black
--@field Blue
--@field Cyan
--@field Green
--@field Magenta
--@field Red
--@field White
--@field Yellow

local BGBlack = '40'
local BGRed = '41'
local BGGreen = '42'
local BGYellow = '43'
local BGBlue = '44'
local BGMagenta = '45'
local BGCyan = '46'
local BGWhite = '47'

local FGBlack = '30'
local FGRed = '31'
local FGGreen= '32'
local FGYellow = '33'
local FGBlue = '34'
local FGMagenta = '35'
local FGCyan = '36'
local FGWhite = '37'

local lastFG = FGWhite
local lastBG = BGBlack
local currentFG = FGWhite
local currentBG = BGBlack

local fgMap = {
    black = FGBlack,     red = FGRed,     green = FGGreen,
    yellow = FGYellow,   blue = FGBlue,   magenta = FGMagenta,
    cyan = FGCyan,       white = FGWhite,
}

local bgMap = {
    black = BGBlack,     red = BGRed,     green = BGGreen,
    yellow = BGYellow,   blue = BGBlue,   magenta = BGMagenta,
    cyan = BGCyan,       white = BGWhite
}

--------------------------------------------------------------------------------
-- Convert a colour name to a colour code
-- @param n Colour name
-- @param map Colour name to colour code mapping
-- @param default Fallback colour if unrecognised
-- @return The colour code
-- @local
local function colour(n, map, default)
    return type(n) == 'string' and map[string.lower(n)] or default
end

--------------------------------------------------------------------------------
-- Set terminal attributes
-- @param fg foreground colours "white", "red", "green", "yellow", "blue", "magenta", "cyan", "black"
-- @param bg background colours "white", "red", "green", "yellow", "blue", "magenta", "cyan", "black"
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.setAttr('cyan', 'blue'))
function _M.setAttr(fg, bg)
    lastFG = currentFG
    lastBG = currentBG

    currentFG = colour(fg, fgMap, FGWhite)
    currentBG = colour(bg, bgMap, BGBlack)

    return '\27['..currentFG..';'..currentBG..'m'
end

--------------------------------------------------------------------------------
-- Restore last terminal attributes
-- @usage
-- local VT100 = require 'rinLibrary.rinVT100'
--
-- VT100.set(VT100.setAttr('yellow', 'white'))
-- VT100.set(VT100.restoreAttr())
function _M.restoreAttr()
    return _M.setAttr(lastFG, lastBG)
end

return _M
