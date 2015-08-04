-------------------------------------------------------------------------------
--- Key Handling.
-- Functions associated with the handing key presses
-- @module rinLibrary.K400Keys
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local pairs = pairs
local ipairs = ipairs
local bit32 = require "bit"
local timers = require 'rinSystem.rinTimers'
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local utils = require 'rinSystem.utilities'
local lpeg   = require "rinLibrary.lpeg"
local usb = require 'rinLibrary.rinUSB'

local deepcopy = utils.deepcopy
local C, P, Pi, R = lpeg.C, lpeg.P, lpeg.Pi, lpeg.R
local ioKeyNames = Pi'io_' * C(R'19' + R'12' * R'09' + P'3' * R'02') / function(n)
    return tonumber(n) + 0x1F
end * P(-1)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

-------------------------------------------------------------------------------
--- Keypad Control.
-- Functions to control instrument keypad
-- @section Keypad

local firstKey = true    -- flag to catch any garbage

--- Keys are represented as follows.
--
-- Digits are represented as the number they are and the rest are
-- represented as string.
--
-- In addition to the keys listed here, there are two additional collections
-- of pseudo keys: <i>IO_#</i> and <i>setpoint_#</i>.  These represent set point and
-- IO inputs.  They look like normal key presses and can produce the various key states
-- but they are sourced from the IO and set point subsystems.  Replace the
-- <i>#</i> with the IO or set point number in the name.
--@table keys
-- @field 0 Key 0 (number)
-- @field 1 Key 1 (number)
-- @field 2 Key 2 (number)
-- @field 3 Key 3 (number)
-- @field 4 Key 4 (number)
-- @field 5 Key 5 (number)
-- @field 6 Key 6 (number)
-- @field 7 Key 7 (number)
-- @field 8 Key 8 (number)
-- @field 9 Key 9 (number)
-- @field power Key power (string)
-- @field zero Key zero (string)
-- @field tare Key tare (string)
-- @field sel Key selection Gross/Net (string)
-- @field f1 Key F1 (string)
-- @field f2 Key F2 (string)
-- @field f3 Key F3 (string)
-- @field plusminus Key +/- (string)
-- @field dp Key dp (string)
-- @field cancel Key cancel (string)
-- @field up Key up (string)
-- @field down Key down (string)
-- @field ok Key ok (string)
-- @field setup Setup button accessed via unit's rear (string)
-- @field pwr_zero Key power &amp; zero pressed simultaneously (string)
-- @field pwr_tare Key power &amp; tare pressed simultaneously (string)
-- @field pwr_sel Key power &amp; sel pressed simultaneously (string)
-- @field pwr_f1 Key power &amp; f1 pressed simultaneously (string)
-- @field pwr_f2 Key power &amp; f2 pressed simultaneously (string)
-- @field pwr_f3 Key power &amp; f3 pressed simultaneously (string)
-- @field pwr_cancel Key power &amp; cancel pressed simultaneously (string)

local KEY_0                = 0x0000
local KEY_1                = 0x0001
local KEY_2                = 0x0002
local KEY_3                = 0x0003
local KEY_4                = 0x0004
local KEY_5                = 0x0005
local KEY_6                = 0x0006
local KEY_7                = 0x0007
local KEY_8                = 0x0008
local KEY_9                = 0x0009
local KEY_POWER            = 0x000A
local KEY_ZERO             = 0x000B
local KEY_TARE             = 0x000C
local KEY_SEL              = 0x000D
local KEY_F1               = 0x000E
local KEY_F2               = 0x000F
local KEY_F3               = 0x0010
local KEY_PLUSMINUS        = 0x0011
local KEY_DP               = 0x0012
local KEY_CANCEL           = 0x0013
local KEY_UP               = 0x0014
local KEY_DOWN             = 0x0015
local KEY_OK               = 0x0016
local KEY_SETUP            = 0x0017
local KEY_PWR_ZERO         = 0x0018
local KEY_PWR_TARE         = 0x0019
local KEY_PWR_SEL          = 0x001A
local KEY_PWR_F1           = 0x001B
local KEY_PWR_F2           = 0x001C
local KEY_PWR_F3           = 0x001D
local KEY_PWR_CANCEL       = 0x001E
local KEY_IDLE             = 0x001F

local keyMap = {
    [0]         = KEY_0,
    [1]         = KEY_1,
    [2]         = KEY_2,
    [3]         = KEY_3,
    [4]         = KEY_4,
    [5]         = KEY_5,
    [6]         = KEY_6,
    [7]         = KEY_7,
    [8]         = KEY_8,
    [9]         = KEY_9,
    power       = KEY_POWER,
    zero        = KEY_ZERO,
    tare        = KEY_TARE,
    sel         = KEY_SEL,
    f1          = KEY_F1,
    f2          = KEY_F2,
    f3          = KEY_F3,
    plusminus   = KEY_PLUSMINUS,
    dp          = KEY_DP,
    cancel      = KEY_CANCEL,
    up          = KEY_UP,
    down        = KEY_DOWN,
    ok          = KEY_OK,
    setup       = KEY_SETUP,
    pwr_zero    = KEY_PWR_ZERO,
    pwr_tare    = KEY_PWR_TARE,
    pwr_sel     = KEY_PWR_SEL,
    pwr_f1      = KEY_PWR_F1,
    pwr_f2      = KEY_PWR_F2,
    pwr_f3      = KEY_PWR_F3,
    pwr_cancel  = KEY_PWR_CANCEL,
    idle        = KEY_IDLE
}
local keyUnmap = utils.invert(keyMap)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Various translation maps for USB keyboard events to display key presses.
-- We permit unshifted, control shifted and meta/windows shifted keys to map
-- differently.  Alt shift is used to indicate a long press of the key.
local usbMap = {
    ['0'] = KEY_0,      ['1'] = KEY_1,      ['2'] = KEY_2,      ['3'] = KEY_3,
    ['4'] = KEY_4,      ['5'] = KEY_5,      ['6'] = KEY_6,      ['7'] = KEY_7,
    ['8'] = KEY_8,      ['9'] = KEY_9,      ['.'] = KEY_DP,
    ['-'] = KEY_PLUSMINUS,                  plusminus = KEY_PLUSMINUS,

    power = KEY_POWER,  power2 = KEY_POWER,
    select = KEY_SEL,
    f1 = KEY_F1,        f2 = KEY_F2,        f3 = KEY_F3,
    up = KEY_UP,        down = KEY_DOWN,
    ['\n'] = KEY_OK,    ok = KEY_OK,
    esc = KEY_CANCEL,   ['\b']=KEY_CANCEL,  delete = KEY_CANCEL,
    --setup = KEY_SETUP,  -- magic button on the back isn't mapped
}

local usbControlMap = {
    Z = KEY_ZERO,       T = KEY_TARE,       S = KEY_SEL,
}

local usbMetaMap = {
    P = KEY_POWER,
    Z = KEY_PWR_ZERO,   T = KEY_PWR_TARE,   S = KEY_PWR_SEL,
    f1 = KEY_PWR_F1,    f2 = KEY_PWR_F2,    f3 = KEY_PWR_F3,
    esc=KEY_PWR_CANCEL, ['\b'] = KEY_PWR_CANCEL,    delete = KEY_PWR_CANCEL,
}

--- Key Groups are defined as follows.
--
-- Except for the final two entries, this table is in priority order.  If a group
-- call back returns true, then any other call backs that would be relevant lower
-- down the table will not be invoked.
--
-- For example, a numeric digit is a member of these groups:
-- <i>numpad</i>, <i>keypad</i>, <i>alphanum</i>, <i>ascii</i> and <i>all</i>.
-- If the handler for the <i>numpad</i> returns false, the search continues
-- down the list and the <i>keypad</i> call back is invoked.  If this then returns
-- true, the later ones will not be called.
--
-- The final two key groups do not actually deal with keys.  Instead they refer to set point and IO
-- module IO pins.  When these change, simulated key presses are generated and these can
-- be used instead of handling the IO or set point directly.  These two groups are unrelated
-- to the others but allow detection and processing of all IO or set points.
--@table keygroups
-- @field arrow Up, down, okay and cancel.
-- @field cursor The non-digit keys to the right of the display.
-- @field numpad The ten digits.
-- @field keypad The sixteen buttons to the right of the display.
-- @field primary The six buttong below the display plus on and setup.
-- @field functions The three function buttons below the display.
-- @field alpha Alphabetic keys.  Only available for USB attached keyboards.
-- @field alphanum Alphabetic and numeric keys.
-- @field punctuation Punctuation symbols.  Only available for USB attached keyboards.
-- @field space White space characters.  Only available for USB attached keyboards.
-- @field ascii ASCII characters.
-- @field extended Power + key combination keys (pwr_...)
-- @field all All keys.
-- @field io All IO based simulated keys (these are not part of the <i>all</i> key group).
-- @field setpoint All set point based simulated keys (these are not part of the <i>all</i> key group).
-- @see rinLibrary.K400Dialog.getKey
local allKeyGroups = {
    'all',      'cursor',   'extended', 'functions',
    'keypad',   'numpad',   'primary',  'arrow',
    'alpha',    'alphanum', 'ascii',    'punctuation',
    'space',    'io',       'setpoint'
}

--- Key events are grouped into a number of different types.
--
-- By default, both short and long presses are seen.
--@table keyEvents
-- @field long A long press of a key
-- @field short A short press of a key
-- @field up A release of a key
-- @field down A press of a key
-- @field repeat A continued repeating press of a key (usually
-- preceeded by a long press)
local keyMode = {
    short = true,
    long = true,
    up = true,
    down = true,
    ['repeat'] = true
}

--Lua key handling
local REG_GET_KEY          = 0x0321
local REG_FLUSH_KEYS       = 0x0322
local REG_APP_DO_KEYS      = 0x0324
local REG_APP_KEY_HANDLER  = 0x0325
local REG_KEY_BUFFER_ENTRY = 0x0008

local keyID = nil
local ioKeyTimers = { }

-------------------------------------------------------------------------------
-- Create a table of keygroup callbacks
-- @param g The group names
-- @return Populated table suitable for group addition
-- @local
local function newKeyGroup(g)
    local r = {}
    for _, g in pairs(g) do
        r[g] = { --[[ short = nil, long = nil, up = nil, repeat = nil --]] }
    end
    return r
end

-------------------------------------------------------------------------------
-- Create a table of key callbacks
-- @return Populated table suitable for group addition
-- @local
local function newKeyBinds()
    local r = {
        [KEY_0]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_1]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_2]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_3]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_4]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_5]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_6]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_7]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_8]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_9]          = { 'numpad',  'keypad', 'alphanum', 'ascii' },
        [KEY_POWER]      = { 'primary'                                },
        [KEY_ZERO]       = { 'primary'                                },
        [KEY_TARE]       = { 'primary'                                },
        [KEY_SEL]        = { 'primary'                                },
        [KEY_F1]         = { 'primary', 'functions'                   },
        [KEY_F2]         = { 'primary', 'functions'                   },
        [KEY_F3]         = { 'primary', 'functions'                   },
        [KEY_PLUSMINUS]  = { 'cursor',  'keypad'                      },
        [KEY_DP]         = { 'cursor',  'keypad'                      },
        [KEY_CANCEL]     = { 'arrow',   'cursor', 'keypad'            },
        [KEY_UP]         = { 'arrow',   'cursor', 'keypad'            },
        [KEY_DOWN]       = { 'arrow',   'cursor', 'keypad'            },
        [KEY_OK]         = { 'arrow',   'cursor', 'keypad'            },
        [KEY_SETUP]      = { 'primary'                                },
        [KEY_PWR_ZERO]   = { 'extended'                               },
        [KEY_PWR_TARE]   = { 'extended'                               },
        [KEY_PWR_SEL]    = { 'extended'                               },
        [KEY_PWR_F1]     = { 'extended'                               },
        [KEY_PWR_F2]     = { 'extended'                               },
        [KEY_PWR_F3]     = { 'extended'                               },
        [KEY_PWR_CANCEL] = { 'extended'                               }
    }

    -- The USB keyboard character groups are algorithmatically generated
    for k in usb.usbKeyboardKeyIterator() do
        if usbMap[k] == nil and r[k] == nil then
            local b = {}
            if #k == 1 then
                if k >= 'a' and k<= 'z' then
                    table.insert(b, 'alpha')
                    table.insert(b, 'alphanum')
                elseif string.find(k, '^%s') then
                    table.insert(b, 'space')
                else
                    table.insert(b, 'punctuation')
                end
                table.insert(b, 'ascii')
            elseif k:find'^f%d+$' then -- also check for k:find'^fn' ??
                table.insert(b, 'functions')
            end
            r[k] = b
        end
    end

    -- Add the final all grouping
    for k, v in pairs(r) do
        table.insert(v, 'all')
    end

    -- Add set point and IO key names.  We add all of them here even if not
    -- all are supported because we're too early in the initialisation to
    -- do otherwise.  This is fixed by only mapping bindings for those that do
    -- exist.
    for i = 1, 32 do
        r[private.formatIOsName('io', i)] = { 'io' }
    end
    for i = 1, 16 do
        r[private.formatIOsName('setpoint', i)] = { 'setpoint' }
    end

    return r
end

local keyGroup = newKeyGroup(allKeyGroups)
local keyBinds = newKeyBinds()

local idleTimerID, idleCallback, idleTimeout = nil, nil, 10

local KEYF_UP, KEYF_LONG = 0x40, 0x80
local KEYF_MASK = 0x3F

local repeatStart, repeatDecay, repeatFinish

local dispatchKey       -- Forward declaration

-------------------------------------------------------------------------------
-- Give the idle timeout timer a kick
-- @function bumpIdleTimer
-- @local
function private.bumpIdleTimer()
    timers.removeTimer(idleTimerID)
    if utils.callable(idleCallback) then
        idleTimerID = timers.addTimer(0, idleTimeout, idleCallback)
    else
        idleTimerID = nil
    end
end

-------------------------------------------------------------------------------
-- Set the repeat interval parameters.
-- @param start The initial time between repeat key events (default 0.5 seconds)
-- @param decay The multiplicative decay factor between key events (default 0.85)
-- @param finish The fastest repeat interval permitted (default 0.12 seconds)
function _M.setKeyRepeatParameters(start, decay, finish)
    repeatStart = start or 0.5
    repeatDecay = decay or 0.85
    repeatFinish = finish or 0.12
end
_M.setKeyRepeatParameters()

-------------------------------------------------------------------------------
-- Called to generate repeating keys
-- @param keyHandler The key handler in question
-- @param key The key being pressed
-- @param source The source for the key press
-- @param modifiers Table contain additional key information
-- @local
local function keyRepeater(keyHandler, key, source, modifiers)
    dispatchKey(key, 'repeat', source, modifiers)
    keyHandler.repeatInterval = math.max(keyHandler.repeatInterval * repeatDecay, repeatFinish)
    keyHandler.repeatTimer = timers.addTimer(0, keyHandler.repeatInterval, keyRepeater, keyHandler, key, source, modifiers)
end

-------------------------------------------------------------------------------
-- Check if a given key from the binding table has a repeat handler installed
-- @param k Key from binding table
-- @return True iff there is a repeat handler installed for this key
-- @local
local function hasRepeatHandler(k)
    if utils.callable(k['repeat']) then
        return true
    end
    for i = 1, #k do
        if utils.callable(keyGroup[k[i]]['repeat']) then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Dispatch a key to the appropriate handler
-- @param key The key code or string
-- @param state The type of key press
-- @param source The source of the key press
-- @param modifiers Modified keys active
-- @local
dispatchKey = function(key, state, source, modifiers)
    local keyHandler, handled, keyName = keyBinds[key], false, key
    if keyHandler ~= nil then
        if type(key) == 'number' then
            keyName = naming.convertValueToName(key, keyUnmap)
        end
        if keyName == nil then return end

        if source ~= 'usb' and hasRepeatHandler(keyHandler) then
            if state == 'long' then
                timers.removeTimer(keyHandler.repeatTimer)
                keyHandler.repeatTimer = timers.addTimer(0, repeatStart, keyRepeater, keyHandler, key, source, modifiers)
                keyHandler.repeatInterval = repeatStart
            elseif state == 'up' then
                timers.removeTimer(keyHandler.repeatTimer)
                keyHandler.repeatTimer = nil
                keyHandler.repeatInterval = nil
            end
        elseif keyHandler.repeatTimer ~= nil then
            timers.removeTimer(keyHandler.repeatTimer)
            keyHandler.repeatTimer = nil
            keyHandler.repeatInterval = nil
        end

        if utils.callable(keyHandler[state]) then
            local function handler()
                dbg.warn('Attempt to call key event handler recursively:', keyName)
                return true
            end
            local cb = keyHandler[state]
            keyHandler[state] = handler
            handled = cb(keyName, state, source, modifiers)
            if keyHandler[state] == handler then
                keyHandler[state] = cb
            end
        end

        if not handled then
            local function handler()
                dbg.warn('Attempt to call key group event Handler recursively:', keyName)
                return true
            end
            for i = 1, #keyHandler do
                local group = keyGroup[keyHandler[i]]
                if utils.callable(group[state]) then
                    local cb = group[state]
                    group[state] = handler
                    local r = cb(keyName, state, source, modifiers)
                    if group[state] == handler then
                        group[state] = cb
                    end
                    if r == true then
                        handled = true
                        break
                    end
                end
            end
        end
    end

    if not handled and state ~= 'repeat' and state ~= 'down' and type(key) == 'number' and (state ~= 'up' or key == KEY_POWER) then
        local data = key + (state == 'up' and KEYF_UP or 0) + (state == 'long' and KEYF_LONG or 0)
        private.writeRegAsync(REG_APP_DO_KEYS, data)
    end
    if state ~= 'up' then
        private.bumpIdleTimer()
    end
end

-------------------------------------------------------------------------------
-- Called when keys are streamed, send the keys to each group it is bound to
-- in order of priority, until one of them returns true.
-- key states are 'short', 'long', 'up' and 'repeat'
-- Note: keybind tables should be sorted by priority
-- @function keyCallback
-- @param data Data on key streamed
-- @param err Potential error message
-- @local
local function keyCallback(data, err)
    if type(data) ~= 'number' then
        data = tonumber(data, 16)
    end
    if data == KEY_IDLE or data == nil then return end

    local state, downEvent = "short", true
    local key = bit32.band(data, 0x3F)

    if bit32.band(data, KEYF_UP) ~= 0 then
        state, downEvent = "up", false
    elseif bit32.band(data, KEYF_LONG) ~= 0 then
        state = "long"
    end

    -- Debug - throw away first 0 key garbage -- this doesn't seem to appear anymore
    if data == 0 and firstKey then
        return
    end
    firstKey = false

    if downEvent then
        dispatchKey(key, 'down', 'display', {})
    end
    return dispatchKey(key, state, 'display', {})
end

-------------------------------------------------------------------------------
-- Push a key stroke back into the event processing code.
-- We actually push the key back to the display so it can send it back to our
-- normal key processing.  This is a bit convoluted but allows for operation
-- of the display via a USB keyboard.
-- @param k Key stroke defintion structure return from kb_lib in L001-507
-- @local
local function keyPushback(k)
    local c, meta, control, state = string.lower(k.raw), k.meta, k.control, k.type
    if not control and not meta then
        c = usbMap[k.raw] or c
    elseif control and not meta then
        c = usbControlMap[k.raw] or c
    elseif meta and not control then
        c = usbMetaMap[k.raw] or c
    end
    if k.type == 'down' then
        state = k.alt and 'long' or 'short'
        dispatchKey(c, 'down', 'usb', k)
    end
    return dispatchKey(c, state, 'usb', k)
end

-------------------------------------------------------------------------------
-- Simulate a key press from an IO event or a set point event.
-- @param source io or setpoint
-- @param key io or setpoint number
-- @param state Boolean, true for down & false for up
-- @local
function private.ioKey(source, key, state)
    local src = source:lower()
    local k = src .. '_' .. key

    if state then       -- key down
        dispatchKey(k, 'down', src, {})
        ioKeyTimers[k] = timers.addTimer(0, 2, function()
            ioKeyTimers[k] = nil
            dispatchKey(k, 'long', src, {})
        end)
    else                -- key up
        if ioKeyTimers[k] then
            timers.removeTimer(ioKeyTimers[k])
            ioKeyTimers[k] = nil
            dispatchKey(k, 'short', src, {})
        end
        dispatchKey(k, 'up', src, {})
    end
end

-------------------------------------------------------------------------------
-- Enable or disable USB keyboard processing.
-- By default key presses on a USB keyboard device (keyboard, bar code scanner,
-- RFID reader) do not act like keys on the display being pressed.
-- @param enable Boolean, true means to process keys as per the display and false
-- doesn't.  The default is false.
-- @usage
-- device.usbProcessKeys(true)
function _M.usbProcessKeys(enable)
    usb.setLibKBDCallback(enable and keyPushback or nil)
end

-------------------------------------------------------------------------------
-- Flush any outstanding key events.
-- @usage
-- device.flushKeys()
function _M.flushKeys()
    private.exReg(REG_FLUSH_KEYS, 0)
end

-------------------------------------------------------------------------------
-- Setup key handling stream
-- This function must be called before any key processing can take place.
-- This routine is called automatically by the standard rinApp application
-- framework.
-- @usage
-- -- Initialise the key handling subsystem
-- device.setupKeys()
--
-- Note: this function generally does not need to be called as the application
-- framework takes care of this.
function _M.setupKeys()
    _M.flushKeys()
    private.writeRegHex(REG_APP_KEY_HANDLER, 1)
    keyID = _M.addStream(REG_GET_KEY, keyCallback, 'change')
end

-------------------------------------------------------------------------------
-- Cancel keypress handling
-- This function must be called after the application's main loop finishes.
-- This routine is called automatically by the standard rinApp application
-- framework.
-- @param flush Flush the current keypresses that have not yet been handled
-- @usage
-- -- Close down the key handling subsystem
-- device.endKeys()
--
-- Note: this function generally does not need to be called as the application
-- framework takes care of this.
function _M.endKeys(flush)
    if flush then
        _M.flushKeys()
    end

    private.writeRegHex(REG_APP_KEY_HANDLER, 0)

    _M.removeStream(keyID)
end

-------------------------------------------------------------------------------
-- Set a callback to run if more than t seconds of idle time is detected
-- between keys.  This is used to trap operator leaving without proper menu exit.
-- @param f function to run when idle time expired
-- @param t is timeout in seconds
-- @usage
-- local function idle()
--     device.abortDialog()
-- end
-- device.setIdleCallback(idle, 15) -- call idle if 15 seconds elapses between keys
function _M.setIdleCallback(f,t)
    utils.checkCallback(f)
    idleCallback = f
    idleTimeout = t or 10
end

-------------------------------------------------------------------------------
-- Set the callback function for an existing key
-- @param keyName to monitor
-- @param callback Function to run when there is an event for that key.
-- @param ... Events for which this callback should be used ('short', 'long', 'up', 'repeat')
-- @see keys
-- @usage
-- -- Callback function parameters are key ('ok' etc) and state ('short', 'long', 'up' or 'repeat')
-- local function F1Pressed(key, state)
--     if state == 'short' then
--         dbg.info('F1 pressed')
--     end
--     return true    -- F1 handled here so don't send back to instrument for handling
-- end
--
-- local function Number3Pressed(key, state)
--     print '3 was pressed'
--     return true
-- end
--
-- device.setKeyCallback('f1', F1Pressed)
-- device.setKeyCallback(3, Number3Pressed, 'short')
function _M.setKeyCallback(keyName, callback, ...)
    utils.checkCallback(callback)
    local key = naming.convertNameToValue(keyName, keyMap) or
                naming.convertNameToValue(keyName, usb.getKeyboardKeys()) or
                naming.convertNameToValue(keyName, private.getIOsNames())
    if key then
        local events = {...}
        if #events == 0 then
            events = { 'short', 'long' }
        end
        for _, e in pairs(events) do
            if keyMode[e] then
                keyBinds[key][e] = callback
            else
                dbg.error('Attempt to add unknown key event:', e)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for an existing key group
-- An individual key handler will override a group handler.  Likewise, the
-- groups have their own priority order from the fine grained to the all
-- encompassing.
-- @param keyGroupName A keygroup name
-- @param callback Function to run when there is an event on the keygroup
-- @param ... Events for which this callback should be used ('short', 'long', 'up')
-- Callback function parameters are key ('ok' etc) and state ('short' or 'long')
-- Return true in the callback to prevent the handling from being passed along to the next keygroup
-- @see keygroups
-- @usage
-- -- Callback to handle F1 key event
-- local function handleKey(key, state)
--     showMarquee(string.format("%s Pressed ", key))
--     if key == 'cancel' and state == 'long' then
--         rinApp.finish()
--     end
--     return true     -- key handled so don't send back to instrument
-- end
-- device.setKeyGroupCallback('all', handleKey, 'long')
-- device.setKeyGroupCallback('numpad', handleKey, 'short')
function _M.setKeyGroupCallback(keyGroupName, callback, ...)
    utils.checkCallback(callback)
    local kg = naming.convertNameToValue(keyGroupName, keyGroup, nil)
    if kg ~= nil then
        local events = {...}
        if #events == 0 then
            events = { 'short', 'long' }
        end
        for _, e in pairs(events) do
            if keyMode[e] then
                kg[e] = callback
            else
                dbg.error('Attempt to add unknown key group event:', e)
            end
        end
    else
        dbg.error('Unknown key group name:', keyGroupName)
    end
end

-------------------------------------------------------------------------------
-- Save all key call backs, optionally deleting all existing callbacks
-- @param keep True if the existing callbacks should be maintained
-- @return Function that when called restores the key handlers
-- @usage
-- local savedKeyHandlers = device.saveKeyCallbacks()
-- ...
-- savedKeyHandlers()
function _M.saveKeyCallbacks(keep)
    local g, b = keyGroup, keyBinds

    if keep then
        keyGroup, keyBinds = deepcopy(g), deepcopy(b)
    else
        keyGroup, keyBinds = newKeyGroup(allKeyGroups), newKeyBinds()
    end
    return function() keyGroup, keyBinds = g, b end
end

-------------------------------------------------------------------------------
-- Send an artificial key press to the given instrument register
-- @param keyName Key to simulate
-- @param status 'long' or 'short'
-- @param register Register to send the key press to
-- @return true
-- @see keys
-- @local
local function sendKeyToRegister(keyName, status, register)
    if keyName then
        local key = naming.convertNameToValue(keyName, keyMap) or ioKeyNames:match(keyName)
        if key then
            if status == 'long' then
                key = bit32.bor(key, 0x80)
            end
            private.writeRegAsync(register, key)
        else
            dbg.warn('Unknown key:', keyName)
        end
    end
    return true
end

-------------------------------------------------------------------------------
-- Send an artificial key press to the instrument.  This can be any of the
-- instrument keys or an IO key.
-- @param keyName Key to simulate
-- @param status 'long' or 'short'
-- @return true
-- @see keys
-- @usage
-- -- Send a short cancel key press to the display
-- device.sendKey('cancel', 'short')
--
-- -- Send a long IO 3 press to the display
-- device.sendKey('io_3', 'long')
function _M.sendKey(keyName, status)
    return sendKeyToRegister(keyName, status, REG_APP_DO_KEYS)
end

-------------------------------------------------------------------------------
-- Send an artificial key press to the instrument's key buffer.
-- This differs from sendKey in that the entire key processing sequence
-- occurs.  This means that this Lua application will see the key come back.
-- You will almost always want to use sendKey not this function.
-- @param keyName Key to simulate
-- @param status 'long' or 'short'
-- @return true
-- @see keys
-- @see sendKey
-- @usage
-- -- Send a short cancel key press to the display for return here
-- device.sendKeyBuffer('cancel', 'short')
function _M.sendKeyBuffer(keyName, status)
    return sendKeyToRegister(keyName, status, REG_KEY_BUFFER_ENTRY)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_GET_KEY          = REG_GET_KEY
deprecated.REG_FLUSH_KEYS       = REG_FLUSH_KEYS
deprecated.REG_APP_DO_KEYS      = REG_APP_DO_KEYS
deprecated.REG_APP_KEY_HANDLER  = REG_APP_KEY_HANDLER
deprecated.REG_KEYBUFFER        = REG_KEY_BUFFER_ENTRY

-- Use names not code here so comparison outside are possible.
deprecated.KEY_0            = 0
deprecated.KEY_1            = 1
deprecated.KEY_2            = 2
deprecated.KEY_3            = 3
deprecated.KEY_4            = 4
deprecated.KEY_5            = 5
deprecated.KEY_6            = 6
deprecated.KEY_7            = 7
deprecated.KEY_8            = 8
deprecated.KEY_9            = 9
deprecated.KEY_POWER        = 'power'
deprecated.KEY_ZERO         = 'zero'
deprecated.KEY_TARE         = 'tare'
deprecated.KEY_SEL          = 'sel'
deprecated.KEY_F1           = 'f1'
deprecated.KEY_F2           = 'f2'
deprecated.KEY_F3           = 'f3'
deprecated.KEY_PLUSMINUS    = 'plusminus'
deprecated.KEY_DP           = 'dp'
deprecated.KEY_CANCEL       = 'cancel'
deprecated.KEY_UP           = 'up'
deprecated.KEY_DOWN         = 'down'
deprecated.KEY_OK           = 'ok'
deprecated.KEY_SETUP        = 'setup'
deprecated.KEY_PWR_ZERO     = 'pwr_zero'
deprecated.KEY_PWR_TARE     = 'pwr_tare'
deprecated.KEY_PWR_SEL      = 'pwr_sel'
deprecated.KEY_PWR_F1       = 'pwr_f1'
deprecated.KEY_PWR_F2       = 'pwr_f2'
deprecated.KEY_PWR_F3       = 'pwr_f3'
deprecated.KEY_PWR_CANCEL   = 'pwr_cancel'
deprecated.KEY_IDLE         = 'idle'

function deprecated.sendIOKey(io, status)
    return _M.sendKey('io_' .. io, status)
end

end
