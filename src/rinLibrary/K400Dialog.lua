-------------------------------------------------------------------------------
--- Dialog Control.
-- Functions for user interface dialogues
-- @module rinLibrary.K400Dialog
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
local sEditKeyTimer = 0     -- counts time since a key pressed for sEdit() - in scrUpdTm increments
local sEditKeyTimeout = 4   -- number of counts before starting a new key in sEdit()

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
-- @see rinLibrary.K400Keys.keygroups
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

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- This table defines the mapping from the numeric keys to alpha characters.
-- The first press results in the first character, the second the second and
-- so forth.
local keyMapping = {
    [1] = "$/\\+-1",
    [2] = "ABC2",
    [3] = "DEF3",
    [4] = "GHI4",
    [5] = "JKL5",
    [6] = "MNO6",
    [7] = "PQRS7",
    [8] = "TUV8",
    [9] = "WXYZ9",
    [0] = "_0"
}

-------------------------------------------------------------------------------
-- Return a character for the key pressed, according to the number of times it
-- has been pressed.
-- @param k key pressed
-- @param p number of times key has been pressed
-- @return letter, number or symbol character represented on the number key pad
-- @local
local function keyChar(k, p)
    return keyCharSelect(keyMapping[k], p)
end

-------------------------------------------------------------------------------
-- Trim white space from a string.
-- @local
local function sTrim(s)       -- removes whitespace from strings
    return s:match'^%s*(.*%S)' or ''
end

-------------------------------------------------------------------------------
-- Set the key timeout in terms of the number of blink half cycles
-- @param n The timeout
-- @return The previous timeout
-- @usage
-- device.setEditKeyTimeout(3)
function _M.setEditKeyTimeout(n)
    local old = sEditKeyTimeout
    sEditKeyTimeout = n or 4
    if n < 2 then n = 4 end
    return old
end

-------------------------------------------------------------------------------
-- Simulate a blinking cursor by altering the string periodically.
-- @local
local function blinkCursor(notTimer)
  local tempTable = utils.deepcopy(sEditTab)
  local str
  
  if (notTimer ~= true) then
    -- Increment the timer
    sEditKeyTimer = sEditKeyTimer + 1
    
    -- Shift cursor to the right on timeout if the length is less than max
    if sEditKeyTimer == sEditKeyTimeout then
      sEditIndex = sEditIndex + 1
    end
  end
  
  if notTimer ~= nil then
    blinkOff = notTimer
  end
  
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
  
  -- Convert the table into a string
  str = table.concat(tempTable)
  
  -- Only display the 9 rightmost characters
  str = string.sub(str, -9)
  
  -- Update the display
  _M.write('bottomLeft', str)
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a string
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param maxLen maximum number of characters to include (default 9)
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return value
-- @return true if ok pressed at end
-- @see edit
-- @see rinLibrary.K400LCD.Units
-- @see rinLibrary.K400LCD.Other
-- @usage
-- local name = device.sEdit('NEW NAME', 'ZINC', 8)
function _M.sEdit(prompt, def, maxLen, units, unitsOther)

    editing = true                  -- is editing occurring
    local key, state, source        -- instrument key values
    local pKey                      -- previous key pressed
    local timeout = false           -- Did a timeout occur
    local presses = 0               -- number of consecutive presses of a key
    local ok = false                -- Was the OK key pressed?
    local cursorTmr                 -- Timer for blinking cursor
    
    maxLen = maxLen or 9
    sEditTab = {}
    
    -- Start in a timed out state
    sEditKeyTimer = sEditKeyTimeout + 1
    
    -- Set the default string. This should be uppercase as the user can only
    -- enter upper case values, and a mixed case return does not make sense.
    local default = string.upper(tostring(def or ""))    -- edit string
    
    -- Get the starting index of the string
    local sLen = #default
    sEditIndex = sLen + 1
    
    -- Save the bottom of the screen before we do anything.
    local restoreBottom = _M.saveBottom()
    
    -- Convert the default to a table
    for i=0,math.min(sLen, maxLen),1 do
        sEditTab[i] = string.sub(default, i, i)   
    end

    -- Set up the screen
    _M.write('bottomRight', prompt)     
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')
    
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
      key, state, source = _M.getKey({'keypad', 'ascii'})
      
      -- If a key wasn't been pressed within the timeout period, set the 
      -- previous key as timeout to force this key to be treated as an 
      -- independent key press.
      if sEditKeyTimer > sEditKeyTimeout then   
        timeout = true
      else
        timeout = false
      end
      
      -- Reset the key press timer if we're not at the end of the string
      if (sLen < maxLen) then
        sEditKeyTimer = 0
      end
      
      -- The dialog isn't running for some reason, so return.
      if not _M.dialogRunning() then    
        ok = false
        editing = false
      -- If there was a short keypress
      elseif state == "short" then
        -- If a numeric key was pressed on the display
        if type(key) == 'number' and source == 'display' then
            -- If the key is the same as the previous key increment the press
            -- count, otherwise reset it.
            if key == pKey and timeout == false then
              presses = presses + 1
              
              -- Update the string and the display
              pKey = key
              sEditTab[sEditIndex] = keyChar(key, presses)
              -- If we're in the middle of the string, then reset the timer
              if (sEditIndex < sLen + 1) then
                sEditKeyTimer = 0
              end
              resetTimer(true)
            -- Only handle if the maxLen hasn't been exceeded
            elseif (sEditIndex < sLen) or 
                (sEditIndex <= sLen + 1 and sLen < maxLen) then
              presses = 1
              
              -- Bump the index if this is a new key press that was not after
              -- a timeout at the end of the string.
              if (timeout == false) then
                sEditIndex = sEditIndex + 1
              end
              
              -- Increment the length if this is a new key press at the end of 
              -- the string.
              if (sEditIndex > sLen) then
                sLen = sLen + 1
              end
              
              -- Update the string and the display
              pKey = key
              sEditTab[sEditIndex] = keyChar(key, presses)
              -- If we're in the middle of the string, then reset the timer
              if (sEditIndex < sLen + 1) then
                sEditKeyTimer = 0
              end
              resetTimer(true)
            end
        -- decimal point key
        elseif (key == 'dp') then 
          -- Only handle if the maxLen hasn't been exceeded
          if (sEditIndex < sLen + 1 or sLen < maxLen) then
            -- Do not allow repeat decimal keys
            if (sEditTab[sEditIndex-1] ~= "." and sEditTab[sEditIndex+1] ~= ".") then
              -- If the previous key didn't time out, time it out.
              if (type(pKey) == 'number' and timeout == false) then
                sEditIndex = sEditIndex + 1
              end
            
              -- Update the string 
              sEditTab[sEditIndex] = "."                 
              pKey = key
  
              -- Increment the string length and the index
              if (sEditIndex > sLen) then
                sLen = sLen + 1
              end
              sEditIndex = sEditIndex + 1
            end
            
            sEditKeyTimer = sEditKeyTimeout + 1
            resetTimer(true)
          end
        -- Move to previous character
        elseif key == 'up' then                    
          sEditIndex = sEditIndex - 1
          if sEditIndex < 1 then
              sEditIndex = math.min(sLen, maxLen) + 1
          end
          -- Update pKey, and update the timer so the timeout won't occur
          pKey = key
          sEditKeyTimer = sEditKeyTimeout + 1
        -- Move to next character
        elseif key == 'down' then
          sEditIndex = math.min(sEditIndex, maxLen + 1) + 1
          if sEditIndex > sLen + 1 then
              sEditIndex = 1
          end
          -- Update pKey, and update the timer so the timeout won't occur
          pKey = key
          sEditKeyTimer = sEditKeyTimeout + 1
        -- Insert a character
        elseif key == 'plusminus' then
          if sEditIndex < sLen + 1 and sLen + 1 <= maxLen then
            sLen = sLen + 1
            
            -- Shuffle the characters along
            for i = sLen, sEditIndex, -1 do
              sEditTab[i] = sEditTab[i-1]             
            end
            
            sEditKeyTimer = sEditKeyTimeout + 1
            sEditTab[sEditIndex] = '_'
            pKey = key
            resetTimer(true)
          end
          
        -- Finish editing if ok is pressed
        elseif key == 'ok' then
          editing = false
          ok = true
        -- Cancel editing
        elseif key == 'cancel' then 
          sEditKeyTimer = sEditKeyTimeout + 1
          
          -- Delete character in the middle of the string
          if sEditIndex < sLen + 1 then
            for i = sEditIndex, sLen do
              sEditTab[i] = sEditTab[i+1]
            end
            sLen = sLen - 1
            resetTimer(false)
          -- Clear character at end of the string
          elseif sLen >= 1 then
            -- Only change the index if there was a timeout
            if timeout == true then        
              sEditIndex = sEditIndex - 1
            end
            sLen = sLen - 1
            sEditTab[sEditIndex] = nil
            resetTimer(false)
          -- If there are no characters, exit the editor
          else    
            ok = false
            editing = false
          end
          pKey = key
          
        -- ASCII keys. This gives some support for usb keyboard
        else     
          -- Only handle if the maxLen hasn't been exceeded
          if (sLen < maxLen) then
            sEditTab[sEditIndex] = string.upper(key)
            pKey = key
            -- Increment the indexes and timeout
            if (sEditIndex > sLen) then
              sEditIndex = sEditIndex + 1
              sLen = sLen + 1
              sEditKeyTimer = sEditKeyTimeout + 1
            end
            resetTimer(true)
          end
        end
      elseif state == "long" then
        -- Exit the editor
        if key == 'cancel' then    
          ok = false
          editing = false
        end
      end
    end
    
    -- Clean up
    finished()
    restoreBottom()
    timers.removeTimer(cursorTmr)
    
    -- Return the entered value.
    if (ok == true)then
      return table.concat(sEditTab), true
    else
      return default, false
    end
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a value, numeric digits and '.' only
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param typ type of value to enter ('integer','number','passcode')
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @param clearDefault Clear the default value when a key is pressed
-- @return value
-- @return true if ok pressed at end
-- @see sEdit
-- @see rinLibrary.K400LCD.Units
-- @see rinLibrary.K400LCD.Other
-- @usage
-- local qty = device.edit('QUANTITY', 123, 'integer')
function _M.edit(prompt, def, typ, units, unitsOther, clearDefault)

    local key, state
    local hide = false

    if typ == 'passcode' then
        typ = 'integer'
        hide = true
    end

    local def = def or ''
    if type(def) ~= 'string' then
         def = tostring(def)
     end

    local editVal = def
    local editType = typ or 'integer'
    editing = true
    local restoreBottom = _M.saveBottom()
    _M.write('bottomRight', prompt)
    if hide then
       _M.write('bottomLeft', string.rep('+',#editVal))
    else
       _M.write('bottomLeft', editVal)
    end
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')

    local first
    if clearDefault == false then
      first = false
    else
      first = true
    end

    local ok = false
    local finished = _M.startDialog()
    while editing and _M.app.isRunning() do
        key, state = _M.getKey('keypad')
        if not _M.dialogRunning() then    -- editing aborted so return default
            ok = false
            editing = false
            editVal = def
        elseif state == 'short' then
            if type(key) == 'number' then
                if first then
                    editVal = tostring(key)
                else
                    editVal = editVal .. key
                end
                first = false
            elseif key == 'dp' and editType ~= 'integer' then
                if editType == 'number' then
                    if first or string.len(editVal) == 0 then
                       editVal = '0.'
                       first = false
                    elseif not string.find(editVal,'%.')  then
                       editVal = editVal .. '.'
                    end
                else
                   editVal = editVal .. '.'
                end
            elseif key == 'ok' then
                editing = false
                 if string.len(editVal) == 0 then
                    editVal = def
                 end
                ok = true
            elseif key == 'cancel' then
                if string.len(editVal) == 0 then
                    editVal = def
                    editing = false
                else
                    editVal = string.sub(editVal,1,-2)
                end
            end
        elseif state == 'long' then
            if key == 'cancel' then
                editVal = def
                editing = false
            end
        end
        if hide then
           _M.write('bottomLeft', string.rep('+',#editVal))
        else
           _M.write('bottomLeft', editVal..' ')
        end
    end
    finished()
    restoreBottom()

    return tonumber(editVal), ok
end

-------------------------------------------------------------------------------
-- Called to edit value of specified register
-- @param register is the address of the register to edit
-- @param prompt is true if name of register to be displayed during editing,
-- or set to a literal prompt to display
-- @return value of register
-- @usage
-- device.editReg('userid1', 'NAME')
function _M.editReg(register, prompt)
    local reg = private.getRegisterNumber(register)
    local restoreBottom = nil

    if prompt then
        restoreBottom = _M.saveBottom()
        if type(prompt) == 'string' then
            _M.write('bottomRight', prompt)
        else
            _M.write('bottomRight', private.getRegName(reg))
        end
    end
    private.writeReg(REG_EDIT_REG, reg)
    local finished = _M.startDialog()
    while true do
        local data,err = private.readRegHex(REG_EDIT_REG)

        if err or (data and tonumber(data,16) ~= reg) then
            break
        end
        _M.app.delay(0.050)
        if not _M.dialogRunning() or not _M.app.isRunning() then
            _M.sendKey('cancel', 'long')
        end
    end
    finished()
    utils.call(restoreBottom)
    return private.readReg(reg)
end

-------------------------------------------------------------------------------
-- Prompts operator and waits for OK or CANCEL key press
-- @param prompt string to put on bottom right LCD
-- @param q string to put on bottom left LCD
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return either 'ok' or 'cancel'
-- @see rinLibrary.K400LCD.Units
-- @see rinLibrary.K400LCD.Other
-- @usage
-- local confirm = device.askOK('SURE?', 'FILE WILL BE DELETED') == 'ok'
function _M.askOK(prompt, q, units, unitsOther)
    local askOKResult = 'cancel'

    local restoreBottom = _M.saveBottom() 
    _M.write('bottomRight', prompt or '')
    _M.write('bottomLeft', q or '')
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')

    local finished = _M.startDialog()
    while _M.app.isRunning() do
        local key = _M.getKey('arrow')

        if not _M.dialogRunning() or key == 'cancel' then    -- editing aborted so return default
            break
        elseif key == 'ok' then
            askOKResult = 'ok'
            break
        end
    end
    finished()
    restoreBottom()
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
-- @see rinLibrary.K400LCD.Units
-- @see rinLibrary.K400LCD.Other
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
    local restoreBottom = _M.saveBottom()
    _M.write('bottomRight', prompt)
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')

    loop = loop == nil and true or loop
    local finished = _M.startDialog()
    while editing and _M.app.isRunning() do
        _M.write('bottomLeft', string.upper(opts[index]))
        local key = _M.getKey('arrow')
        if not _M.dialogRunning() or key == 'cancel' then    -- editing aborted so return default
            editing = false
        elseif key == 'down' then
            index = private.addModBase1(index, 1, #opts, loop)
        elseif key == 'up' then
            index = private.addModBase1(index, -1, #opts, loop)
        elseif key == 'ok' then
            sel = opts[index]
            editing = false
        end
    end
    finished()
    restoreBottom()
    return sel
end

-------------------------------------------------------------------------------
-- Prompts operator to select from a multiselect object.  The legal selections
-- are displayed in alphabetic order and any number of items can be selected.
-- Keys uses are up and down to navigate, +/- to select or deselect, zero to
-- select none, decimal point to select all, ok to accept the current selections
-- and cancel to exit and revert to the original selections.
-- @param prompt string to put on bottom right LCD, this is preceeded by an
-- asterik or a space to indicate selection.
-- @param options multiselect object
-- @param loop If true, top option loops to the bottom option and vice versa.  Default: true
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return array containing selected item names
-- @see rinLibrary.K400LCD.Units
-- @see rinLibrary.K400LCD.Other
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
    local restoreBottom = _M.saveBottom()
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')

    loop = loop == nil and true or loop
    local finished = _M.startDialog()
    while editing and _M.app.isRunning() do
        _M.write('bottomLeft', string.upper(opts[index]))
        _M.write('bottomRight', (options.isSelected(opts[index]) and "*" or " ")..prompt)

        local key = _M.getKey('keypad')

        if not _M.dialogRunning() or key == 'cancel' then    -- editing aborted so return default
            options.selectOnly(unpack(origSelected))
            editing = false
        elseif key == 'down' then
            index = private.addModBase1(index, 1, #opts, loop)
        elseif key == 'up' then
            index = private.addModBase1(index, -1, #opts, loop)
        elseif key == 'plusminus' then
            options.toggle(opts[index])
        elseif key == 'ok' then
            editing = false
        elseif key == 0 then
            options.deselectAll()
        elseif key == 'dp' then
            options.selectAll()
        end
    end
    finished()
    restoreBottom()
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
-- @see rinLibrary.K400LCD.Units
-- @see rinLibrary.K400LCD.Other
-- @usage
-- local opt = selectConfig('COMMAND', { {'HELP', 'ME'}, {'QUIT', 'IT'} }, 1, true)
function _M.selectConfig(prompt, options, def, loop, units, unitsOther)
    local opts = options or {'cancel'}
    local sel = nil

    local index = def

    editing = true
    local restoreDisplay = _M.saveDisplay()
    _M.write('topLeft', prompt)
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')
    
    loop = loop == nil and true or loop
    local finished = _M.startDialog()
    while editing and _M.app.isRunning() do
        _M.write('bottomLeft', string.upper(opts[index][1]))
        _M.write('bottomRight', string.upper(opts[index][2]))
        local key = _M.getKey('arrow')
        if not _M.dialogRunning() or key == 'cancel' then    -- editing aborted so return default
            editing = false
        elseif key == 'down' then
            index = private.addModBase1(index, 1, #opts, loop)
        elseif key == 'up' then
            index = private.addModBase1(index, -1, #opts, loop)
        elseif key == 'ok' then
            sel = index
            editing = false
        end
    end
    finished()
    restoreDisplay()
    return sel
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_EDIT_REG = REG_EDIT_REG
local warnDelay = true
deprecated.delay = function(t)
    if warnDelay then
        dbg.warn("K400:", "delay has been moved to rinApp")
        warnDelay = false
    end
    _M.app.delay(t)
end

local warnDisplayMessage, warnDisplayMessageWait = true, true
function deprecated.displayMessage(msg, t, units, unitsOther)
    if warnDisplayMessage then
        dbg.warn("K400:", "instead of displayMessage, use write with 'restore'")
        warnDisplayMessage = false
    end
    local t = t or 0.5

	if msg and t > 0 then
		_M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none') -- display optional units
		_M.write('bottomLeft', msg, 'restore, time='..t)			-- display message
	end
end

function deprecated.displayMessageWait(msg, t, units, unitsOther)
    if warnDisplayMessageWait then
        dbg.warn("K400:", "instead of displayMessageWait, use write with 'restore, wait'")
        warnDisplayMessageWait = false
    end
    local t = t or 0.5

	if msg and t > 0 then
		_M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none') -- display optional units
		_M.write('bottomLeft', msg, 'wait, restore, time='..t)			-- display message
	end
end

end
