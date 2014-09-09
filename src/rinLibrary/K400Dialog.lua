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
local timers = require 'rinSystem.rinTimers.Pack'
local system = require 'rinSystem.Pack'
local dbg = require 'rinLibrary.rinDebug'

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

local REG_EDIT_REG = 0x0320

local dialogRunning = 0
local editing = false

local sEditVal = ' '        -- default edit value for sEdit()
local sEditIndex = 1        -- starting index for sEdit()
local sEditKeyTimer = 0     -- counts time since a key pressed for sEdit() - in scrUpdTm increments
local sEditKeyTimeout = 4   -- number of counts before starting a new key in sEdit()

local scrUpdTm = 0.5        -- screen update frequency in Sec
local blinkOff = false      -- blink cursor for string editing

local msgDisp = false	    -- message is being displayed by dispMsg function
local msgTimer = nil		-- timer for user message display

-------------------------------------------------------------------------------
-- Is a message currently being displayed?
-- @return true iff a message is displayed
-- @usage
-- if not device.messageDisplayed() then
--     device.displayMessage('hello', 2.123)
-- end
function _M.messageDisplayed()
    return msgDisp
end

-------------------------------------------------------------------------------
-- Is a dialog currently being displayed?
-- @return true iff a dialog is displayed
-- @local
function _M.dialogRunning()
    return dialogRunning ~= 0
end

-------------------------------------------------------------------------------
-- Stop the currently running dialog and exit to the previous or the main
-- application loop.
-- @local
function _M.abortDialog()
    dialogRunning = dialogRunning - 1
    if dialogRunning < 0 then
        dialogRunning = 0
    end
end

-------------------------------------------------------------------------------
-- Enter into a new dialog.
-- @local
function _M.startDialog()
    dialogRunning = dialogRunning + 1
    private.bumpIdleTimer()
end

-------------------------------------------------------------------------------
-- Cancel a displayed message, if any.
-- @local
local function endDisplayMessage()
	if msgDisp then
        msgDisp = false
	    timers.removeTimer(msgTimer)
        msgTimer = nil
        _M.restoreBot()
    end
end

-------------------------------------------------------------------------------
-- Called to display a message to the screen for a time
-- @param msg message displayed on bottom left LCD
-- @param t number of seconds to display message (can be fractional; e.g. 2.125)
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @usage
-- -- Display an happy message for one and a half seconds.
-- -- Program will continue operation immediately.
-- device.displayMessage('joy', 1.5)
function _M.displayMessage(msg, t, units, unitsOther)
    local t = t or 0.5

    endDisplayMessage()
	if msg and t > 0 then
		msgDisp = true
		_M.saveBot()
		_M.write('bottomLeft', msg)			-- display message
		_M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none') -- display optional units
		msgTimer = timers.addTimer(0, t, endDisplayMessage)
	end
end

-------------------------------------------------------------------------------
-- Called to display a message to the screen for a time and waits for it to finish
-- @param msg message displayed on bottom left LCD
-- @param t number of seconds to display message (can be fractional; e.g. 2.125)
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @usage
-- -- Display an unhappy message for one and a half seconds.
-- -- Program will pause operation immediately.
-- device.displayMessageWait('unhappy', 1.5)
function _M.displayMessageWait(msg, t, units, unitsOther)
    _M.displayMessage(msg, t, units, unitsOther)
    _M.app.delayUntil(function() return not mspDisp end)
end

-------------------------------------------------------------------------------
-- Called to get a key from specified key group
-- @param keyGroup The key group, 'all' is default
-- @param keep True if the existing callbacks should be maintained, this can
-- cause some interference issues unless used prudently.
-- @return key
-- @return state ('short' or 'long')
-- @usage
-- device.displayMessage('Press key', 3)
-- print('key pressed was:', device.getKey())
function _M.getKey(keyGroup, keep)
    keyGroup = keyGroup or 'all'
    local getKeyState, getKeyPressed

    local saved = private.saveKeyCallbacks(keep)

    _M.setKeyGroupCallback(keyGroup,
        function(key, state)
            getKeyPressed = key
            getKeyState = state
            return true
        end, 'short', 'long')
    if keyGroup ~= 'all' then
        _M.setKeyGroupCallback('all', function() return true end)
    end

    _M.startDialog()
    _M.app.delayUntil(function()
        return not _M.dialogRunning() or getKeyState
    end)
    _M.abortDialog()
    private.restoreKeyCallbacks(saved)

    return getKeyPressed, getKeyState
end

-------------------------------------------------------------------------------
-- Check to see if editing routines active
-- @return true if editing false otherwise
-- @usage
-- if not device.isEditing() then
--     device.displayMessage('idle')
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


-----------------------------------------------------------------------------------------------
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
    [1] = "$/\\1",
    [2] = "ABC2",
    [3] = "DEF3",
    [4] = "GHI4",
    [5] = "JKL5",
    [6] = "MNO6",
    [7] = "PQRS7",
    [8] = "TUV8",
    [9] = "WXYZ9",
    [0] = " 0"
}

-----------------------------------------------------------------------------------------------
-- Return a character for the key pressed, according to the number of times it has been pressed
-- @param k key pressed
-- @param p number of times key has been pressed
-- @return letter, number or symbol character represented on the number key pad
-- @local
local function keyChar(k, p)
    return keyCharSelect(keyMapping[k], p)
end

-----------------------------------------------------------------------------------------------
-- Trim white space from a string.
-- @local
local function sTrim(s)       -- removes whitespace from strings
    return s:match'^%s*(.*%S)' or ''
end

-----------------------------------------------------------------------------------------------
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

-----------------------------------------------------------------------------------------------
-- Simulate a blinking cursor by altering the string periodically.
-- @local
local function blinkCursor()
--  used in sEdit() function below
    sEditKeyTimer = sEditKeyTimer + 1 -- increment key press timer for sEdit()
    local str
    local pre
    local suf
    local max = #sEditVal
    blinkOff = not blinkOff
    if blinkOff then
        pre = string.sub(sEditVal, 1, sEditIndex-1)
        if sEditIndex < max then
            suf = string.sub(sEditVal, sEditIndex+1, -1)
        else
            suf = ''
        end
        str = pre .. "_" .. suf
    else
        str = sEditVal
    end
--  print(str)  -- debug
    _M.write('bottomLeft', str)
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a string
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param maxLen maximum number of characters to include
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return value and true if ok pressed at end
-- @usage
-- local name = device.sEdit('NEW NAME', 'ZINC', 8)
function _M.sEdit(prompt, def, maxLen, units, unitsOther)

    editing = true                  -- is editing occurring
    local key, state                -- instrument key values
    local pKey = nil                -- previous key pressed
    local presses = 0               -- number of consecutive presses of a key

    if def then                     -- if a string is supplied
        def = sTrim(def)            -- trim any whitespace
    end

    local default = def or ' '      -- default string to edit, if no default passed to function, default to one space
    sEditVal = tostring(default)    -- edit string
    local sLen = #sEditVal       -- length of string being edited
    sEditIndex = sLen               -- index in string of character being edited
    local ok = false                -- OK button was pressed to accept editing
    local strTab = {}               -- temporary table holding edited string characters
    local blink = false             -- cursor display variable

    endDisplayMessage()             -- abort any existing display prompt
    local cursorTmr = timers.addTimer(scrUpdTm, 0, blinkCursor)  -- add timer to blink the cursor
    _M.saveBot()

    if sLen >= 1 then   -- string length should always be >= 1 because of 'default' assignment above
        for i=0,math.min(sLen, maxLen),1 do
            strTab[i] = string.sub(sEditVal, i, i)   -- convert the string to a table for easier character manipulation
        end
        --print('strTab = ' .. table.concat(strTab))  -- debug
    end
    sEditVal = table.concat(strTab);

    if def then         -- if a default string is given
        pKey = 'def'    -- give pKey a value so we start editing from the end
    end

    _M.write('bottomRight', prompt)        -- write the prompt
    _M.write('bottomLeft', sEditVal)    -- write the default string to edit
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none') -- display optional units

    _M.startDialog()
    while editing and _M.app.isRunning() do
        key, state = _M.getKey('keypad')  -- wait for a key press
        if sEditKeyTimer > sEditKeyTimeout then   -- if a key is not pressed for a couple of seconds
            pKey = 'timeout'                            -- ignore previous key presses and treat this as a different key
        end
        sEditKeyTimer = 0                        -- reset the timeout counter now a key has been pressed
        if not _M.dialogRunning() then    -- editing aborted so return default
            ok = false
           editing = false
           sEditVal = default
        elseif state == "short" then                            -- short key presses for editing
            if type(key) == 'number' then     -- keys 0 to 9 on the keypad
--              print('i:' .. sEditIndex .. ' l:' .. sLen)   -- debug
                if key == pKey then         -- if same as the previous key pressed
                    presses = presses + 1   -- add 1 to number of presses of this key
                else
                    presses = 1             -- otherwise reset presses to 1
                    if pKey and (sEditIndex >= sLen) and (strTab[sEditIndex] ~= " ") then     -- if not first key pressed
                        sEditIndex = sEditIndex + 1       -- new key pressed, increment the character position
                    end
                    pKey = key              -- remember the key pressed
                end
--              print('i:' .. sEditIndex)    -- debug
                strTab[sEditIndex] = keyChar(key, presses)    -- update the string (table) with the new character
            --
            elseif (key == 'dp') and (key ~= pKey) then        -- decimal point key (successive decimal points not allowed)
                if (pKey and (sEditIndex >= sLen)) or (strTab[sEditIndex] == " ") then    -- if not first key pressed and not space at end
                    sEditIndex = sEditIndex + 1           -- new key pressed, increment the character position
                end
                strTab[sEditIndex] = "."                 -- update the string (table) with the new character
                pKey = key                                  -- remember the key pressed
            --
            elseif key == 'up' then                    -- up key, previous character
                sEditIndex = sEditIndex - 1               -- decrease index
                if sEditIndex < 1 then                       -- if at first character
                    sEditIndex = sLen                            -- go to last character
                end
                pKey = key                                  -- remember the key pressed
            --
            elseif key == 'down' then          -- down key, next character
                sEditIndex = sEditIndex + 1       -- increment index
                if sEditIndex > sLen then            -- if at last character
                    if strTab[sLen] ~= " " then         -- and last character is not a space
                        if sLen < maxLen then               -- and length of string < maximum
                            sLen = sLen + 1                     -- increase length of string
                            strTab[sLen] = " "                  -- and add a space to the end
                        else                                -- string length = maximum
                            sEditIndex = 1                   -- go to the first character
                        end
                    else                                -- otherwise (last character is a space)
                        if sLen > 1 then                    -- as long as the string is more than 1 character long
                            strTab[sLen] = nil              -- delete the last character
                            sLen = sLen - 1                 -- decrease the length of the string
                            sEditIndex = 1               -- and go to the first character
                        end
                    end
                end
                pKey = key                                  -- remember the key pressed
            --
            elseif key == 'plusminus' then     -- plus/minus key - insert a character
                if sLen < maxLen then
                    sLen = sLen + 1                     -- increase the length of the string
                end
                for i = sLen, sEditIndex+1, -1 do
                    strTab[i] = strTab[i-1]             -- shuffle the characters along
                end
                strTab[sEditIndex] = " "             -- insert a space
                pKey = key                          -- remember the key pressed
            --
            elseif key == 'ok' then        -- OK key
                editing = false                      -- finish editing
                ok = true                           -- accept changes
            --
            elseif key == 'cancel' then    -- cancel key
                if sEditIndex < sLen then
                    for i = sEditIndex, sLen-1 do    -- delete current character
                        strTab[i] = strTab[i+1]         -- shuffle characters along
                    end
                end
                strTab[sLen] = nil                  -- clear last character
                sEditIndex = sEditIndex - 1   -- decrease length of string
                pKey = key                          -- remember the key pressed
            end
        elseif state == "long" then         -- long key press only for cancelling editing
            if key == 'cancel' then    -- cancel key
                sEditVal = default               -- reinstate default string
                editing = false                     -- finish editing
            end
        end
        if editing or ok then                       -- if editing or OK is selected
            sEditVal = table.concat(strTab)      -- update edited string
            sLen = #sEditVal
--          print('eVal = \'' .. sEditVal .. '\'')   -- debug
        end
    end
    _M.abortDialog()

    _M.restoreBot() -- restore previously displayed messages

    timers.removeTimer(cursorTmr) -- remove cursor blink timer
    return sEditVal, ok                  -- return edited string and OK status
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a value, numeric digits and '.' only
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param typ type of value to enter ('integer','number','passcode')
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return value and true if ok pressed at end
-- @usage
-- local qty = device.edit('QUANTITY', 123, 'integer')
function _M.edit(prompt, def, typ, units, unitsOther)

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
    endDisplayMessage()
    _M.saveBot()
    _M.write('bottomRight', prompt)
    if hide then
       _M.write('bottomLeft', string.rep('+',#editVal))
    else
       _M.write('bottomLeft', editVal)
    end
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')

    local first = true

    local ok = false
    _M.startDialog()
    while editing and _M.app.isRunning() do
        key, state = _M.getKey('keypad')
        if not _M.dialogRunning() then    -- editing aborted so return default
            ok = false
           editing = false
           sEditVal = def
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
    _M.abortDialog()
    _M.restoreBot()

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
    endDisplayMessage()
    if (prompt) then
        _M.saveBot()
        if type(prompt) == 'string' then
            _M.write('bottomRight', prompt)
        else
            _M.write('bottomRight', private.getRegName(reg))
        end
    end
    private.writeReg(REG_EDIT_REG, reg)
    _M.startDialog()
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
    _M.abortDialog()
    if prompt then
        _M.restoreBot()
    end
    return private.readReg(reg)
end

-------------------------------------------------------------------------------
-- Prompts operator and waits for OK or CANCEL key press
-- @param prompt string to put on bottom right LCD
-- @param q string to put on bottom left LCD
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return either 'ok' or 'cancel'
-- @usage
-- local confirm = device.askOK('SURE?', 'FILE WILL BE DELETED') == 'ok'
function _M.askOK(prompt, q, units, unitsOther)
    local askOKResult = 'cancel'

    endDisplayMessage()
    _M.saveBot()
    _M.write('bottomRight', prompt or '')
    _M.write('bottomLeft', q or '')
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')

    _M.startDialog()
    while _M.app.isRunning() do
        local key = _M.getKey('arrow')

        if not _M.dialogRunning() or key == 'cancel' then    -- editing aborted so return default
            break
        elseif key == 'ok' then
            askOKResult = 'ok'
            break
        end
    end
    _M.abortDialog()
    _M.restoreBot()
    return askOKResult
end

-------------------------------------------------------------------------------
-- Prompts operator to select from a list of options using
-- arrow keys and ok
-- @param prompt string to put on bottom right LCD
-- @param options table of option strings
-- @param def default selection string.byte
-- @param loop If true, top option loops to the bottom option and vice versa
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return selected string if OK pressed or nil if CANCEL pressed
-- @usage
-- local opt = selectOption('COMMAND', { 'HELP', 'QUIT' }, 'QUIT', true)
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
    endDisplayMessage()
    _M.saveBot()
    _M.write('bottomRight', string.upper(prompt))
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')

    _M.startDialog()
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
    _M.abortDialog()
    _M.restoreBot()
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
-- @param loop If true, top option loops to the bottom option and vice versa
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return array containing selected item names
-- @usage
-- local multiselect = require 'rinLibrary.multiselect'
-- local options = multiselect()
-- options.set('cement', 'sand', 'putty', 'oil', 'gravel')
-- local selections = device.selectFromOptions('mix', options)
-- for i = 1, #selections do
--     print('selection ' .. i .. ' is ' .. selections[i])
-- end
function _M.selectFromOptions(prompt, options, loop, units, unitsOther)
    prompt = string.upper(prompt)
    local index = 1
    local opts = options.get()
    local origSelected = options.getSelected()

    editing = true
    endDisplayMessage()
    _M.saveBot()
    _M.writeUnits('bottomLeft', units or 'none', unitsOther or 'none')

    _M.startDialog()
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
    _M.abortDialog()
    _M.restoreBot()
    return options.getSelected()
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

end

