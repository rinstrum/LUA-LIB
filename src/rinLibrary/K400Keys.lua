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

--Lua key handling
local REG_GET_KEY          = 0x0321
local REG_FLUSH_KEYS       = 0x0322
local REG_APP_DO_KEYS      = 0x0324
local REG_APP_KEY_HANDLER  = 0x0325

local keyID = nil

-- Be sure to update the ldoc table to match the defined keyGroups
--- Key Groups.
--@table keygroups
-- @field all
-- @field primary
-- @field functions
-- @field keypad
-- @field numpad
-- @field cursor
-- @field extended

local keyGroup = {}
for _, g in pairs({
            'all',      'cursor',   'extended',  'functions',
            'keypad',   'numpad',   'primary'
        }) do
    keyGroup[g] = { callback = nil }
end

local keyBinds = {
    [KEY_0]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_1]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_2]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_3]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_4]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_5]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_6]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_7]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_8]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_9]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [KEY_POWER]      = { keyGroup.primary,                       keyGroup.all },
    [KEY_ZERO]       = { keyGroup.primary,                       keyGroup.all },
    [KEY_TARE]       = { keyGroup.primary,                       keyGroup.all },
    [KEY_SEL]        = { keyGroup.primary,                       keyGroup.all },
    [KEY_F1]         = { keyGroup.primary,   keyGroup.functions, keyGroup.all },
    [KEY_F2]         = { keyGroup.primary,   keyGroup.functions, keyGroup.all },
    [KEY_F3]         = { keyGroup.primary,   keyGroup.functions, keyGroup.all },
    [KEY_PLUSMINUS]  = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [KEY_DP]         = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [KEY_CANCEL]     = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [KEY_UP]         = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [KEY_DOWN]       = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [KEY_OK]         = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [KEY_SETUP]      = { keyGroup.primary,                       keyGroup.all },
    [KEY_PWR_ZERO]   = { keyGroup.extended,                      keyGroup.all },
    [KEY_PWR_TARE]   = { keyGroup.extended,                      keyGroup.all },
    [KEY_PWR_SEL ]   = { keyGroup.extended,                      keyGroup.all },
    [KEY_PWR_F1  ]   = { keyGroup.extended,                      keyGroup.all },
    [KEY_PWR_F2  ]   = { keyGroup.extended,                      keyGroup.all },
    [KEY_PWR_F3  ]   = { keyGroup.extended,                      keyGroup.all },
    [KEY_PWR_CANCEL] = { keyGroup.extended,                      keyGroup.all }
}

local idleTimerID, idleCallback, idleTimeout = nil, nil, 10
local runningKeyCallback = nil  -- keeps track of any running callback to prevent recursive calls

-------------------------------------------------------------------------------
-- Give the idle timeout timer a kick
-- @function bumpIdleTimer
-- @local
function private.bumpIdleTimer()
    timers.removeTimer(idleTimerID)
    if idleCallback then
        idleTimerID = timers.addTimer(0, idleTimeout, idleCallback)
    else
        idleTimerID = nil
    end
end

-- Called when keys are streamed, send the keys to each group it is bound to
-- in order of priority, until one of them returns true.
-- key states are 'short','long','up'
-- Note: keybind tables should be sorted by priority
-- @param data Data on key streamed
-- @param err Potential error message
-- @local
local function keyCallback(data, err)

    local state = "short"
    local key = bit32.band(data, 0x3F)

    if bit32.band(data, 0x80) > 0 then
        state = "long"
    end

    if bit32.band(data, 0x40) > 0 then
        state = "up"
    end

--    dbg.debug('Key: ',data,err)
    -- Debug - throw away first 0 key garbage
    if data == 0 and firstKey then
        return
    end
    firstKey = false

    -- Debug  - throw away up and idle events
    if (state == "up" and key ~= KEY_POWER) or data == KEY_IDLE then
        return
    end

    local handled = false
    local groups = keyBinds[key]
    if groups ~= nil then
        local keyName = private.convertValueToName(key, keyUnmap)

        -- No point trying to deal with a key we don't know about
        if keyName == nil then
            return
        end

        if groups.directCallback then
            if runningKeyCallback == groups.directCallback then
               dbg.warn('Attempt to call Key Event Handler recursively : ', keyName)
               return
            end
            runningKeyCallback = groups.directCallback
            if groups.directCallback(keyName, state) == true then
                handled = true
            end
            runningKeyCallback = nil
        end

        if not handled then
            for i=1, #groups do
                if groups[i].callback then
                    if runningKeyCallback == groups[i].callback then
                        dbg.warn('Attempt to call Key Group Event Handler recursively : ', keyName)
                        return
                    end
                    runningKeyCallback = groups[i].callback
                    if groups[i].callback(keyName, state) == true then
                        handled = true
                        break
                    end
                end
            end
            runningKeyCallback = nil
        end
    end

    if not handled then
        private.writeRegAsync( REG_APP_DO_KEYS, data)
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
    _M.exReg(REG_FLUSH_KEYS, 0)
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
    idleCallback = f
    idleTimeout = t or 10
end

-------------------------------------------------------------------------------
-- Set the callback function for an existing key
-- @param keyName to monitor
-- @param callback Function to run when there is an event for that key.
-- @return The old callback function
-- @usage
-- -- Callback function parameters are key ('ok' etc) and state ('short' or 'long')
-- local function F1Pressed(key, state)
--     if state == 'short' then
--         dbg.info('F1 pressed')
--     end
--     return true    -- F1 handled here so don't send back to instrument for handling
-- end
-- device.setKeyCallback('f1', F1Pressed)
function _M.setKeyCallback(keyName, callback)
    local key = private.convertNameToValue(keyName, keyMap)
    local old = keyBinds[key].directCallback
    if key then
        keyBinds[key].directCallback = callback
    end
    return old
end

-------------------------------------------------------------------------------
-- Set the callback function for an existing key group
-- An individual key handler will override a group handler.  Likewise, the
-- groups have their own priority order from the fine grained to the all
-- encompassing.
-- @param keyGroupName A keygroup name
-- @param callback Function to run when there is an event on the keygroup
-- @return The old key group callback
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
-- device.setKeyGroupCallback('all', handleKey)
function _M.setKeyGroupCallback(keyGroupName, callback)
    local kg = private.convertNameToValue(keyGroupName, keyGroup, keyGroupName)
    local old = kg.callback
    kg.callback = callback
    return old
end

-------------------------------------------------------------------------------
-- Send an artificial key press to the instrument
-- @param keyName Key to simulate
-- @param status 'long' or 'short'
-- @usage
-- -- Send a short cancel key press to the display
-- device.sendKey('cancel', 'short')
function _M.sendKey(keyName, status)
    local key = private.convertNameToValue(keyName, keyMap)
    if key then
        local data = key
        if status == 'long' then
            data = bit32.bor(data, 0x80)
        end
        _M.sendRegWait('wrfinaldec', REG_APP_DO_KEYS, data)
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
        _M.sendRegWait('wrfinaldec',REG_APP_DO_KEYS, data)
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_GET_KEY          = REG_GET_KEY
deprecated.REG_FLUSH_KEYS       = REG_FLUSH_KEYS
deprecated.REG_APP_DO_KEYS      = REG_APP_DO_KEYS
deprecated.REG_APP_KEY_HANDLER  = REG_APP_KEY_HANDLER

deprecated.keyGroup             = keyGroup

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
