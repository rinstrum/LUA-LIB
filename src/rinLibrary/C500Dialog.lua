-------------------------------------------------------------------------------
--- Dialog Control.
-- Functions for user interface dialogues
-- @module rinLibrary.C500Dialog
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local tonumber = tonumber
local type = type
local math = math
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local table = table
local bit32 = require "bit"
local timers = require 'rinSystem.rinTimers'
local system = require 'rinSystem'
local dbg = require 'rinLibrary.rinDebug'
local utils = require 'rinSystem.utilities'
local null, True = utils.null, utils.True

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

local REG_EDIT_REG = 0x0320

local dialogRunning = false
local editing = false

local sEditTab = {}         -- Table containing string to edit
local sEditIndex = 1        -- starting index for sEdit()

local scrUpdTm = 0.5        -- screen update frequency in Sec
local blinkOff = false      -- blink cursor for string editing

-------------------------------------------------------------------------------
-- Is a dialog currently being displayed?
-- @return true iff a dialog is displayed
-- @usage
-- if not device.dialogRunning() then
--     write('bottomLeft', 'hello')
-- end
function _M.dialogRunning()
    return dialogRunning
end

-------------------------------------------------------------------------------
-- Stop the currently running dialog and exit to the previous or the main
-- application loop.
-- @local
function _M.abortDialog()
    dialogRunning = false
end

-------------------------------------------------------------------------------
-- Stop the current dialog running
-- @local
local function stopDialog()
    dialogRunning = false
end

-------------------------------------------------------------------------------
-- Enter into a new dialog.
-- @return function to restore dialog entry state to previous
-- @local
function _M.startDialog()
    local old = dialogRunning
    dialogRunning = true
    private.bumpIdleTimer()
    return old and null or stopDialog
end

-------------------------------------------------------------------------------
-- Called to get a key from specified key group
-- @param keyGroup The key group, 'all' is default. A list of key groups is also
-- allowed here and the legal keys are a union of these.
-- @param keep True if the existing callbacks should be maintained, this can 
-- cause some interference issues unless used prudently.
-- @return key
-- @return state ('short' or 'long')
-- @return source ('display' or 'usb')
-- @see rinLibrary.GenericKeys.keygroups
-- @usage
-- device.write('bottomLeft', 'Press key', 'time=3')
-- print('key pressed was:', device.getKey())
function _M.getKey(keyGroup, keep)
    keyGroup = keyGroup or 'all'
    if type(keyGroup) == 'string' then keyGroup = { keyGroup } end

    local getKeyState, getKeyPressed, getKeySource

    local savedKeyHandlers = _M.saveKeyCallbacks(keep)
    _M.setKeyGroupCallback('all', True)

    local function handler(key, state, source, modifiers)
        getKeyPressed = key
        getKeyState = state
        getKeySource = source
        return true
    end
    for _, g in pairs(keyGroup) do
        _M.setKeyGroupCallback(g, handler, 'short', 'long')
    end

    local finished = _M.startDialog()
    _M.app.delayUntil(function()
        return not _M.dialogRunning() or getKeyState
    end)
    finished()
    savedKeyHandlers()

    return getKeyPressed, getKeyState, getKeySource
end

-------------------------------------------------------------------------------
-- Check to see if editing routines active
-- @return true if editing false otherwise
-- @usage
-- if not device.isEditing() then
--     device.write('bottomLeft', 'idle')
-- end
function _M.isEditing()
   return editing
end

-------------------------------------------------------------------------------
-- Change the screen update frequency for the next dialog presented.
-- @param s The update frequency in seconds to set for next time
-- @return The previous update frequency
-- @usage
-- device.setScreenUpdateFrequency(1)   -- slow down updates
function _M.setScreenUpdateFrequency(s)
    local old = scrUpdTm
    scrUpdTm = s or 0.5
    if scrUpdTm < .1 then
        scrUpdTm = .5
    end
    return old
end


-------------------------------------------------------------------------------
-- Helper function that takes a string and a position and returns the character
-- at the specified position.  It modulo reduces its argument to the string's
-- length.
-- @param s String of legal characters
-- @param p Position in string
-- @return The relevant character
-- @local
local function keyCharSelect(s, p)
    if s == nil then return nil end
    local z = math.fmod(p, #s)
    if z == 0 then z = #s end
    return s:sub(z, z)
end

-------------------------------------------------------------------------------
-- Helper function that takes a string and returns the position of the first
-- character that matches c.
-- @param s String of legal characters
-- @param c Character to find in string
-- @local
local function keyCharGet(s, c)
  return string.find(s, c, nil, true)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- This table defines the mapping from the numeric keys to alpha characters.
-- The first press results in the first character, the second the second and
-- so forth.
local numKeyMapping = "0123456789."

-------------------------------------------------------------------------------
-- Trim white space from a string.
-- @local
local function sTrim(s)       -- removes whitespace from strings
    return s:match'^%s*(.*%S)' or ''
end

-------------------------------------------------------------------------------
-- Simulate a blinking cursor by altering the string periodically.
-- @local
local function blinkCursor(notTimer)
  local tempTable = utils.deepcopy(sEditTab)
  local str
  
  -- Ensure there's a character at the position
  tempTable[sEditIndex] = tempTable[sEditIndex] or " "
  
  -- Set the cursor
  blinkOff = not blinkOff
  if blinkOff then
    if (tempTable[sEditIndex] == "_") then
      tempTable[sEditIndex] = " "
    else
      tempTable[sEditIndex] = "_"
    end
  end
  
  --print(tempTable[1], tempTable[2], tempTable[3], tempTable[4], tempTable[5], tempTable[6], tempTable[7], tempTable[8])
  
  -- Convert the table into a string
  str = table.concat(tempTable)
  
  -- Only display the 6 rightmost characters
  str = string.sub(str, -6)
  
  -- Update the display
  _M.write('topLeft', str)
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a number
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param maxLen maximum number of characters to include (default 6)
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return value
-- @return true if ok pressed at end
-- @see edit
-- @see rinLibrary.GenericLCD.Units
-- @see rinLibrary.GenericLCD.Other
-- @usage
-- local name = device.edit('Update Num', '0.04', 6)
function _M.edit(prompt, def, maxLen, units, unitsOther)

    editing = true                  -- is editing occurring
    local key, state, source        -- instrument key values
    local alphabetIndex = 0         -- Index in alphabet of editor
    local ok = false                -- Was the OK key pressed?
    local cursorTmr                 -- Timer for blinking cursor
    
    maxLen = maxLen or 6
    sEditTab = {}
    
    -- Set the default string. This should be uppercase as the user can only
    -- enter upper case values, and a mixed case return does not make sense.
    local default = string.upper(tostring(def or ""))    -- edit string
    
    -- Get the starting index of the string
    local sLen = #default
    sEditIndex = sLen
    
    -- Save the display before we do anything.
    local restoreDisplay = _M.saveDisplay()
    
    -- Convert the default to a table
    for i=0,math.min(sLen, maxLen),1 do
        sEditTab[i] = string.sub(default, i, i)   
    end
    
    -- Set up the initial string
    if sEditIndex == 0 or (sEditIndex < maxLen and sEditTab[sEditIndex] == nil) then
      sEditIndex = sEditIndex + 1
      sLen = sLen + 1
      sEditTab[sEditIndex] = keyCharSelect(numKeyMapping, 1)
    end
    
    -- Set up the screen
    _M.write('topLeft', prompt, "time=1,wait")     
    _M.writeUnits('topLeft', units or 'none', unitsOther or 'none')
    
    -- Add timer to blink the cursor and call it to set up the screen.
    local resetTimer = function (blinkOff)
      timers.removeTimer(cursorTmr)
      cursorTmr = timers.addTimer(scrUpdTm, scrUpdTm, blinkCursor)
      blinkCursor(blinkOff)
    end
    resetTimer(true)

    local finished = _M.startDialog()
    while editing and _M.app.isRunning() do    
      -- Wait for a key press
      key, state, source = _M.getKey({'arrow'})
      
      -- The dialog isn't running for some reason, so return.
      if not _M.dialogRunning() then    
        ok = false
        editing = false
      -- If there was a short keypress
      elseif state == "short" then
        -- Arrow keys
        if key == 'f1' or key == 'zero' then
          -- Get the new alphabet index, and increment or decrement as necessary
          alphabetIndex = keyCharGet(numKeyMapping, sEditTab[sEditIndex])
          if key == 'zero' then
            alphabetIndex = alphabetIndex - 1
          elseif key == 'f1' then
            alphabetIndex = alphabetIndex + 1
          end
            
          -- Update the string and the display
          sEditTab[sEditIndex] = keyCharSelect(numKeyMapping, alphabetIndex)
          resetTimer(true)
        -- Move to previous character
        elseif key == 'tare' then                    
          sEditIndex = sEditIndex - 1
          if sEditIndex < 1 then
            sEditIndex = math.min(sLen, maxLen)
          end
          resetTimer(true)
        -- Move to next character
        elseif key == 'sel' then
          sEditIndex = math.min(sEditIndex, maxLen) + 1
          
          -- Loop around
          if sEditIndex > maxLen then
            sEditIndex = 1
          end
          
          -- Fill the character with a 0 if it's nil
          if sEditTab[sEditIndex] == nil then
            sEditTab[sEditIndex] = keyCharSelect(numKeyMapping, 1)
            sLen = sLen + 1
          end
          
        -- Finish editing if ok is pressed
        elseif key == 'f2' then
          editing = false
          ok = true
        -- Cancel editing
        elseif key == 'f3' then          
          -- Delete character in the middle of the string
          if sEditIndex < sLen then
            for i = sEditIndex, sLen do
              sEditTab[i] = sEditTab[i+1]
            end
            sLen = sLen - 1
            resetTimer(false)
          -- Clear character at end of the string
          elseif sLen > 1 then
            -- Only change the index if there was a timeout
            sEditTab[sEditIndex] = nil
            sEditIndex = sEditIndex - 1
            sLen = sLen - 1            
            resetTimer(false)
          end
          
--        -- ASCII keys. This gives some support for usb keyboard
--        else     
--          -- Only handle if the maxLen hasn't been exceeded
--          if (sLen < maxLen) then
--            sEditTab[sEditIndex] = string.upper(key)
--            -- Increment the indexes and timeout
--            if (sEditIndex > sLen) then
--              sEditIndex = sEditIndex + 1
--              sLen = sLen + 1
--            end
--            resetTimer(true)
--          end
        end
      elseif state == "long" then
        -- Exit the editor
        if key == 'f3' then    
          ok = false
          editing = false
        end
      end
    end
    
    -- Clean up
    finished()
    restoreDisplay()
    timers.removeTimer(cursorTmr)
    
    -- Return the entered value.
    if (ok == true)then
      return table.concat(sEditTab), true
    else
      return default, false
    end
end

-------------------------------------------------------------------------------
-- Prompts operator and waits for OK or CANCEL key press
-- @param prompt string to put on bottom right LCD
-- @param q string to put on bottom left LCD
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return either 'ok' or 'cancel'
-- @see rinLibrary.GenericLCD.Units
-- @see rinLibrary.GenericLCD.Other
-- @usage
-- local confirm = device.askOK('SURE?', 'FILE WILL BE DELETED') == 'ok'
function _M.askOK(prompt, q, units, unitsOther)
    local askOKResult = 'cancel'

    local restore = _M.saveDisplay()
    _M.write('topLeft', q or '', 'time=1,wait')
    _M.writeUnits('topLeft', units or 'none', unitsOther or 'none')
    _M.write('topLeft', prompt or '', units and '' or 'align=right')

    local finished = _M.startDialog()
    while _M.app.isRunning() do
        local key = _M.getKey()

        if not _M.dialogRunning() or key == 'f3' then    -- editing aborted so return default
            break
        elseif key == 'f2' then
            askOKResult = 'ok'
            break
        end
    end
    finished()
    restore()
    return askOKResult
end

-------------------------------------------------------------------------------
-- Prompts operator to select from a list of options using
-- arrow keys and ok
-- @param prompt string to put on bottom right LCD
-- @param options table of option strings
-- @param def default selection string.byte
-- @param loop If true, top option loops to the bottom option and vice versa.  Default: true
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return selected string if OK pressed or nil if CANCEL pressed
-- @see rinLibrary.GenericLCD.Units
-- @see rinLibrary.GenericLCD.Other
-- @usage
-- local opt = device.selectOption('COMMAND', { 'HELP', 'QUIT' }, 'QUIT', true)
function _M.selectOption(prompt, options, def, loop, units, unitsOther)
    local opts = options or {'cancel'}
    local sel = nil

    local index = 1
    if def then
        for k,v in ipairs(opts) do
            if v == def then
                index = k
            end
        end
    end

    editing = true
    local restoreDisplay = _M.saveDisplay()
    _M.write('topLeft', prompt, 'time=1,wait')
    _M.writeUnits('topLeft', units or 'none', unitsOther or 'none')

    loop = loop == nil and true or loop
    local finished = _M.startDialog()
    while editing and _M.app.isRunning() do
        _M.write('topLeft', string.upper(opts[index]), units and '' or 'align=right')
        local key = _M.getKey('arrow')
        if not _M.dialogRunning() or key == 'f3' then    -- editing aborted so return default
            editing = false
        elseif key == 'zero' or key == 'tare' then
            index = private.addModBase1(index, 1, #opts, loop)
        elseif key == 'f1' or key == 'sel' then
            index = private.addModBase1(index, -1, #opts, loop)
        elseif key == 'f2' then
            sel = opts[index]
            editing = false
        end
    end
    finished()
    restoreDisplay()
    return sel
end

-------------------------------------------------------------------------------
-- Prompts operator to select from a multiselect object.  The legal selections
-- are displayed in alphabetic order and any number of items can be selected.
-- Keys uses are up and down to navigate, > to select and deselect, ok to 
-- accept the current selections and cancel to exit and revert to the original
-- selections.
-- @param prompt string to put on bottom right LCD, this is preceeded by an
-- asterik or a space to indicate selection.
-- @param options multiselect object
-- @param loop If true, top option loops to the bottom option and vice versa.  Default: true
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return array containing selected item names
-- @see rinLibrary.GenericLCD.Units
-- @see rinLibrary.GenericLCD.Other
-- @usage
-- local multiselect = require 'rinLibrary.multiselect'
-- local options = multiselect()
-- options.set('cement', 'sand', 'putty', 'oil', 'gravel')
-- local selections = device.selectFromOptions('mix', options)
-- for i = 1, #selections do
--     print('selection ' .. i .. ' is ' .. selections[i])
-- end
function _M.selectFromOptions(prompt, options, loop, units, unitsOther)
    local index = 1
    local opts = options.get()
    local origSelected = options.getSelected()

    editing = true
    local restoreDisplay = _M.saveDisplay()
    _M.writeUnits('topLeft', units or 'none', unitsOther or 'none')
    _M.write('topLeft', prompt, 'time=1,wait')

    loop = loop == nil and true or loop
    local finished = _M.startDialog()
    while editing and _M.app.isRunning() do
        _M.write('topLeft', 
            (options.isSelected(opts[index]) and "*" or " ")..string.upper(opts[index]),
            units and '' or 'align=right')

        local key = _M.getKey('arrow')

        if not _M.dialogRunning() or key == 'f3' then    -- editing aborted so return default
            options.selectOnly(unpack(origSelected))
            editing = false
        elseif key == 'zero' then
            index = private.addModBase1(index, 1, #opts, loop)
        elseif key == 'f1' then
            index = private.addModBase1(index, -1, #opts, loop)
        elseif key == 'sel' then
            options.toggle(opts[index])
        elseif key == 'ok' then
            editing = false
        end
    end
    finished()
    restoreDisplay()
    return options.getSelected()
end

-------------------------------------------------------------------------------
-- Prompts operator to select from a list of options using
-- arrow keys and ok, simultaneously showing the current value of the option
-- @param prompt string to put on top left LCD
-- @param options table of option strings and values
-- @param def default selection index in options
-- @param loop If true, top option loops to the bottom option and vice versa.  Default: true
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return selected option string if OK pressed or nil if CANCEL pressed
-- @see rinLibrary.GenericLCD.Units
-- @see rinLibrary.GenericLCD.Other
-- @usage
-- local opt = device.selectConfig('COMMAND', { {'HELP', 'ME'}, {'QUIT', 'IT'} }, 1, true)
function _M.selectConfig(prompt, options, def, loop, units, unitsOther)
    local opts = options or {'cancel'}
    local sel = nil

    local index = def

    editing = true
    local restoreDisplay = _M.saveDisplay()
    _M.write('topLeft', prompt, 'time=1,wait')
    _M.writeUnits('topLeft', units or 'none', unitsOther or 'none')
    
    loop = loop == nil and true or loop
    local finished = _M.startDialog()
    while editing and _M.app.isRunning() do
        _M.write('topLeft', 
            string.upper(opts[index][1] .. ": " .. opts[index][2]),
            units and '' or 'align=right')
        local key = _M.getKey('arrow')
        if not _M.dialogRunning() or key == 'f3' then    -- editing aborted so return default
            editing = false
        elseif key == 'zero' or key == 'tare' then
            index = private.addModBase1(index, 1, #opts, loop)
        elseif key == 'f1' or key == 'sel' then
            index = private.addModBase1(index, -1, #opts, loop)
        elseif key == 'f2' then
            sel = index
            editing = false
        end
    end
    finished()
    restoreDisplay()
    return sel
end

end
