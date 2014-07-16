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

--- Keys.
--@table keys
-- @field KEY_0
-- @field KEY_1
-- @field KEY_2
-- @field KEY_3
-- @field KEY_4
-- @field KEY_5
-- @field KEY_6
-- @field KEY_7
-- @field KEY_8
-- @field KEY_9
-- @field KEY_POWER
-- @field KEY_ZERO
-- @field KEY_TARE
-- @field KEY_SEL
-- @field KEY_F1
-- @field KEY_F2
-- @field KEY_F3
-- @field KEY_PLUSMINUS
-- @field KEY_DP
-- @field KEY_CANCEL
-- @field KEY_UP
-- @field KEY_DOWN
-- @field KEY_OK
-- @field KEY_SETUP
-- @field KEY_PWR_ZERO
-- @field KEY_PWR_TARE
-- @field KEY_PWR_SEL
-- @field KEY_PWR_F1
-- @field KEY_PWR_F2
-- @field KEY_PWR_F3
-- @field KEY_PWR_CANCEL

_M.KEY_0                = 0x0000
_M.KEY_1                = 0x0001
_M.KEY_2                = 0x0002
_M.KEY_3                = 0x0003
_M.KEY_4                = 0x0004
_M.KEY_5                = 0x0005
_M.KEY_6                = 0x0006
_M.KEY_7                = 0x0007
_M.KEY_8                = 0x0008
_M.KEY_9                = 0x0009
_M.KEY_POWER            = 0x000A
_M.KEY_ZERO             = 0x000B
_M.KEY_TARE             = 0x000C
_M.KEY_SEL              = 0x000D
_M.KEY_F1               = 0x000E
_M.KEY_F2               = 0x000F
_M.KEY_F3               = 0x0010
_M.KEY_PLUSMINUS        = 0x0011
_M.KEY_DP               = 0x0012
_M.KEY_CANCEL           = 0x0013
_M.KEY_UP               = 0x0014
_M.KEY_DOWN             = 0x0015
_M.KEY_OK               = 0x0016
_M.KEY_SETUP            = 0x0017
_M.KEY_PWR_ZERO         = 0x0018
_M.KEY_PWR_TARE         = 0x0019
_M.KEY_PWR_SEL          = 0x001A
_M.KEY_PWR_F1           = 0x001B
_M.KEY_PWR_F2           = 0x001C
_M.KEY_PWR_F3           = 0x001D
_M.KEY_PWR_CANCEL       = 0x001E
_M.KEY_IDLE             = 0x001F

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
    [_M.KEY_0]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_1]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_2]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_3]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_4]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_5]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_6]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_7]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_8]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_9]          = { keyGroup.numpad,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_POWER]      = { keyGroup.primary,                       keyGroup.all },
    [_M.KEY_ZERO]       = { keyGroup.primary,                       keyGroup.all },
    [_M.KEY_TARE]       = { keyGroup.primary,                       keyGroup.all },
    [_M.KEY_SEL]        = { keyGroup.primary,                       keyGroup.all },
    [_M.KEY_F1]         = { keyGroup.primary,   keyGroup.functions, keyGroup.all },
    [_M.KEY_F2]         = { keyGroup.primary,   keyGroup.functions, keyGroup.all },
    [_M.KEY_F3]         = { keyGroup.primary,   keyGroup.functions, keyGroup.all },
    [_M.KEY_PLUSMINUS]  = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_DP]         = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_CANCEL]     = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_UP]         = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_DOWN]       = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_OK]         = { keyGroup.cursor,    keyGroup.keypad,    keyGroup.all },
    [_M.KEY_SETUP]      = { keyGroup.primary,                       keyGroup.all },
    [_M.KEY_PWR_ZERO]   = { keyGroup.extended,                      keyGroup.all },
    [_M.KEY_PWR_TARE]   = { keyGroup.extended,                      keyGroup.all },
    [_M.KEY_PWR_SEL ]   = { keyGroup.extended,                      keyGroup.all },
    [_M.KEY_PWR_F1  ]   = { keyGroup.extended,                      keyGroup.all },
    [_M.KEY_PWR_F2  ]   = { keyGroup.extended,                      keyGroup.all },
    [_M.KEY_PWR_F3  ]   = { keyGroup.extended,                      keyGroup.all },
    [_M.KEY_PWR_CANCEL] = { keyGroup.extended,                      keyGroup.all }
}

local idleTimerID, idleCallback, idleTimeout = nil, nil, 10
local runningKeyCallback = nil  -- keeps track of any running callback to prevent recursive calls

-------------------------------------------------------------------------------
-- Give the idle timeout timer a kick
-- @local
function private.bumpIdleTimer()
    timers.removeTimer(idleTimerID)
    if idleCallback then
        idleTimerID = timers.addTimer(0,idleTimeout,idleCallback)
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
    if (state == "up" and key ~= _M.KEY_POWER) or data == _M.KEY_IDLE then
       return
    end

    local handled = false
    local groups = keyBinds[key]
    if groups ~= nil then

       if groups.directCallback then
            if runningKeyCallback == groups.directCallback then
               dbg.warn('Attempt to call Key Event Handler recursively : ', key)
               return
            end
            runningKeyCallback = groups.directCallback
            if groups.directCallback(key, state) == true then
                handled = true
            end
            runningKeyCallback = nil
       end

      if not handled then
          for i=1, #groups do
            if groups[i].callback then
                if runningKeyCallback == groups[i].callback then
                    dbg.warn('Attempt to call Key Group Event Handler recursively : ', key)
                    return
                end
                runningKeyCallback = groups[i].callback
                if groups[i].callback(key, state) == true then
                    handled = true
                    break
                end
            end
          end
          runningKeyCallback = nil
       end
     end

    if not handled then
        _M.sendReg('wrfinaldec', REG_APP_DO_KEYS, data)
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
    _M.sendRegWait('wrfinalhex', REG_APP_KEY_HANDLER, 1)
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

    _M.sendRegWait('wrfinalhex', REG_APP_KEY_HANDLER, 0)

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
-- @param key to monitor (KEY_* )
-- @param callback Function to run when there is an event for that key.
-- @return The old callback function
-- @usage
-- -- Callback function parameters are key (.KEY_OK etc) and state ('short' or 'long')
-- local function F1Pressed(key, state)
--     if state == 'short' then
--         dbg.info('F1 pressed')
--     end
--     return true    -- F1 handled here so don't send back to instrument for handling
-- end
-- device.setKeyCallback(device.KEY_F1, F1Pressed)
function _M.setKeyCallback(key, callback)
    local old = keyBinds[key].directCallback
    keyBinds[key].directCallback = callback
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
-- Callback function parameters are key (.KEY_OK etc) and state ('short' or 'long')
-- Return true in the callback to prevent the handling from being passed along to the next keygroup
-- @usage
-- -- Callback to handle F1 key event 
-- local function handleKey(key, state)
--     showMarquee(string.format("%s Pressed ", key))
--     if key == device.KEY_PWR_CANCEL and state == 'long' then 
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
-- @param key (.KEY_*)
-- @param status 'long' or 'short'
-- @usage
-- -- Send a short cancel key press to the display
-- device.sendKey(device.KEY_CANCEL, 'short')
function _M.sendKey(key,status)
    if key then
        local data = key
        if status == 'long' then
            data = bit32.bor(data, 0x80)
        end
        _M.sendRegWait('wrfinaldec', REG_APP_DO_KEYS, data)
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

end
