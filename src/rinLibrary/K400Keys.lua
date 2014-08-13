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
local timers = require 'rinSystem.rinTimers.Pack'
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local utils = require 'rinSystem.utilities'
local deepcopy = require 'rinLibrary.deepcopy'

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
-- @field setup Key setup (string)
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

local keyUnmap, keyMap = {}, {
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
for k, v in pairs(keyMap) do
    keyUnmap[v] = k
end

--- Key Groups are defined as follows.
--@table keygroups
-- @field all All keys.
-- @field arrow Up, down, okay and cancel.
-- @field cursor The non-digit keys to the right of the display.
-- @field extended Power + key combination keys (pwr_...)
-- @field functions The three function buttons below the display.
-- @field keypad The sixteen buttons to the right of the display.
-- @field numpad The ten digits.
-- @field primary The six buttong below the display plus on and setup.

local allKeyGroups = {
    'all',      'cursor',   'extended', 'functions',
    'keypad',   'numpad',   'primary',  'arrow'
}
local keyGroup = newKeyGroup(allKeyGroups)
local keyBinds = newKeyBinds()

local idleTimerID, idleCallback, idleTimeout = nil, nil, 10

--Lua key handling
local REG_GET_KEY          = 0x0321
local REG_FLUSH_KEYS       = 0x0322
local REG_APP_DO_KEYS      = 0x0324
local REG_APP_KEY_HANDLER  = 0x0325

local keyID = nil

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
    return {
        [KEY_0]          = { 'numpad',  'keypad',               'all' },
        [KEY_1]          = { 'numpad',  'keypad',               'all' },
        [KEY_2]          = { 'numpad',  'keypad',               'all' },
        [KEY_3]          = { 'numpad',  'keypad',               'all' },
        [KEY_4]          = { 'numpad',  'keypad',               'all' },
        [KEY_5]          = { 'numpad',  'keypad',               'all' },
        [KEY_6]          = { 'numpad',  'keypad',               'all' },
        [KEY_7]          = { 'numpad',  'keypad',               'all' },
        [KEY_8]          = { 'numpad',  'keypad',               'all' },
        [KEY_9]          = { 'numpad',  'keypad',               'all' },
        [KEY_POWER]      = { 'primary',                         'all' },
        [KEY_ZERO]       = { 'primary',                         'all' },
        [KEY_TARE]       = { 'primary',                         'all' },
        [KEY_SEL]        = { 'primary',                         'all' },
        [KEY_F1]         = { 'primary', 'functions',            'all' },
        [KEY_F2]         = { 'primary', 'functions',            'all' },
        [KEY_F3]         = { 'primary', 'functions',            'all' },
        [KEY_PLUSMINUS]  = { 'cursor',  'keypad',               'all' },
        [KEY_DP]         = { 'cursor',  'keypad',               'all' },
        [KEY_CANCEL]     = { 'arrow',   'cursor',  'keypad',    'all' },
        [KEY_UP]         = { 'arrow',   'cursor',  'keypad',    'all' },
        [KEY_DOWN]       = { 'arrow',   'cursor',  'keypad',    'all' },
        [KEY_OK]         = { 'arrow',   'cursor',  'keypad',    'all' },
        [KEY_SETUP]      = { 'primary',                         'all' },
        [KEY_PWR_ZERO]   = { 'extended',                        'all' },
        [KEY_PWR_TARE]   = { 'extended',                        'all' },
        [KEY_PWR_SEL ]   = { 'extended',                        'all' },
        [KEY_PWR_F1  ]   = { 'extended',                        'all' },
        [KEY_PWR_F2  ]   = { 'extended',                        'all' },
        [KEY_PWR_F3  ]   = { 'extended',                        'all' },
        [KEY_PWR_CANCEL] = { 'extended',                        'all' }
    }
end

--- Key events are grouped into a number of different types.
--
-- By default, both short and long presses are seen
--@table keyEvents
-- @field short A short press of a key
-- @field long A long press of a key
-- @field repeat A continued repeating press of a key (preceeded by a long event)
-- @field up A release of a key

local keyMode = {
    short = true,
    long = true,
    up = true,
    ['repeat'] = true
}

local KEYF_UP, KEYF_LONG, KEYF_REPEAT = 0x40, 0x80, 0x40000000
local KEYF_MASK = 0x3F

local repeatStart, repeatDecay, repeatFinish

local keyCallback       -- Forward declaration

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
-- @local
local function keyRepeater(keyHandler, key)
    keyCallback(key + KEYF_REPEAT, nil)
    keyHandler.repeatInterval = math.max(keyHandler.repeatInterval * repeatDecay, repeatFinish)
    keyHandler.repeatTimer = timers.addTimer(0, keyHandler.repeatInterval, keyRepeater, keyHandler, key)
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
-- Called when keys are streamed, send the keys to each group it is bound to
-- in order of priority, until one of them returns true.
-- key states are 'short', 'long', 'up' and 'repeat'
-- Note: keybind tables should be sorted by priority
-- @function keyCallback
-- @param data Data on key streamed
-- @param err Potential error message
-- @local
keyCallback = function(data, err)
    if data == KEY_IDLE then return end

    local state = "short"
    local key = bit32.band(data, 0x3F)
    local keyHandler = keyBinds[key]

    if bit32.band(data, KEYF_UP) ~= 0 then
        state = "up"
    elseif bit32.band(data, KEYF_LONG) ~= 0 then
        state = "long"
    elseif bit32.band(data, KEYF_REPEAT) ~= 0 then
        state = 'repeat'
    end

    -- Debug - throw away first 0 key garbage -- this doesn't seem to appear anymore
    if data == 0 and firstKey then
        return
    end
    firstKey = false

    -- Throw away uninteresting events
    -- Key up events on the power key are always delivered
    --if state ~= 'up' or key ~= KEY_POWER then

    local handled = false
    if keyHandler ~= nil then
        local keyName = naming.convertValueToName(key, keyUnmap)

        -- No point trying to deal with a key we don't know about
        if keyName == nil then
            return
        end

        if hasRepeatHandler(keyHandler) then
            if state == 'long' then
                timers.removeTimer(keyHandler.repeatTimer)
                keyHandler.repeatTimer = timers.addTimer(0, 0, keyRepeater, keyHandler, key)
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
                dbg.warn('Attempt to call key event handler recursively : ', keyName)
                return true
            end
            local cb = keyHandler[state]
            keyHandler[state] = handler
            local r = cb(keyName, state)
            if keyHandler[state] == handler then
                keyHandler[state] = cb
            end
            if r == true then
                handled = true
            end
        end

        if not handled then
            for i = 1, #keyHandler do
                local group = keyGroup[keyHandler[i]]
                if utils.callable(group[state]) then
                    local function handler()
                        dbg.warn('Attempt to call key group event Handler recursively : ', keyName)
                        return true
                    end
                    local cb = group[state]
                    group[state] = handler
                    local r = cb(keyName, state)
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

    if not handled and state ~= 'repeat' and (state ~= 'up' or key == KEY_POWER) then
        private.writeRegAsync(REG_APP_DO_KEYS, data)
    end
    if state ~= 'up' then
        private.bumpIdleTimer()
    end
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
    keyID = private.addStreamLib(REG_GET_KEY, keyCallback, 'change')
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
-- @usage
-- -- Callback function parameters are key ('ok' etc) and state ('short', 'long', 'up' or 'repeat')
-- local function F1Pressed(key, state)
--     if state == 'short' then
--         dbg.info('F1 pressed')
--     end
--     return true    -- F1 handled here so don't send back to instrument for handling
-- end
-- device.setKeyCallback('f1', F1Pressed)
function _M.setKeyCallback(keyName, callback, ...)
    utils.checkCallback(callback)
    local key = naming.convertNameToValue(keyName, keyMap)
    if key then
        local events = {...}
        if #events == 0 then
            events = { 'short', 'long' }
        end
        for _, e in pairs(events) do
            if keyMode[e] then
                keyBinds[key][e] = callback
            else
                dbg.error('Attempt to add unknown key event: ', e)
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
-- @usage
-- -- Callback to handle F1 key event 
-- local function handleKey(key, state)
--     showMarquee(string.format("%s Pressed ", key))
--     if key == 'cancel' and state == 'long' then 
--         rinApp.running = false
--     end
--     return true     -- key handled so don't send back to instrument
-- end
-- device.setKeyGroupCallback('all', handleKey, 'long')
-- device.setKeyGroupCallback('numpad', handleKey, 'short')
function _M.setKeyGroupCallback(keyGroupName, callback, ...)
    utils.checkCallback(callback)
    local kg = naming.convertNameToValue(keyGroupName, keyGroup, keyGroupName)
    local events = {...}
    if #events == 0 then
        events = { 'short', 'long' }
    end
    for _, e in pairs(events) do
        if keyMode[e] then
            kg[e] = callback
        else
            dbg.error('Attempt to add unknown key group event: ', e)
        end
    end
end

-------------------------------------------------------------------------------
-- Save all key call backs, optionally deleting all existing callbacks
-- @function saveKeyCallbacks
-- @param keep True if the existing callbacks should be maintained
-- @return Saved state that can be restored later
-- @local
function private.saveKeyCallbacks(keep)
    local saved = { g=keyGroup, k=keyBinds }
    if keep then
        keyGroup = deepcopy(keyGroup)
        keyBinds = deepcopy(keyBinds)
    else
        keyGroup = newKeyGroup(allKeyGroups)
        keyBinds = newKeyBinds()
    end
    return saved
end

-------------------------------------------------------------------------------
-- Restore all key call backs from a saved state
-- @function restoreKeyCallbacks
-- @param saved Saved call back state
-- @local
function private.restoreKeyCallbacks(saved)
    keyGroup = saved.g
    keyBinds = saved.k
end

-------------------------------------------------------------------------------
-- Send an artificial key press to the instrument
-- @param keyName Key to simulate
-- @param status 'long' or 'short'
-- @usage
-- -- Send a short cancel key press to the display
-- device.sendKey('cancel', 'short')
function _M.sendKey(keyName, status)
    local key = naming.convertNameToValue(keyName, keyMap)
    if key then
        local data = key
        if status == 'long' then
            data = bit32.bor(data, 0x80)
        end
        private.writeReg(REG_APP_DO_KEYS, data)
    else
        dbg.warn('Unknown key :', keyName)
    end
end

-------------------------------------------------------------------------------
-- Send an artificial IO key press to the instrument
-- @param io IO number (1 to 32)
-- @param status 'long' or 'short'
-- @usage
-- -- Send a short IO10 key press to the display
-- device.sendIOKey(10, 'short')
function _M.sendIOKey(io,status)
    if io and io >= 1 and io <= 32 then
        local data = io + 0x1F -- IO1 is 0x20
        if status == 'long' then
            data = bit32.bor(data, 0x80)
        end
        private.writeReg(REG_APP_DO_KEYS, data)
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_GET_KEY          = REG_GET_KEY
deprecated.REG_FLUSH_KEYS       = REG_FLUSH_KEYS
deprecated.REG_APP_DO_KEYS      = REG_APP_DO_KEYS
deprecated.REG_APP_KEY_HANDLER  = REG_APP_KEY_HANDLER

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

end
