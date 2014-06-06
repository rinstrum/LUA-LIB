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

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M)

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
_M.REG_GET_KEY          = 0x0321
_M.REG_FLUSH_KEYS       = 0x0322
_M.REG_APP_DO_KEYS      = 0x0324
_M.REG_APP_KEY_HANDLER  = 0x0325

local keyID = nil

_M.keyGroup = {}

-- Be sure to update the ldoc table below to match the defined keyGroups
_M.keyGroup.all         = {callback = nil}
_M.keyGroup.primary     = {callback = nil}
_M.keyGroup.functions   = {callback = nil}
_M.keyGroup.keypad      = {callback = nil}
_M.keyGroup.numpad      = {callback = nil}
_M.keyGroup.cursor      = {callback = nil}
_M.keyGroup.extended    = {callback = nil}

local keyBinds = {
    [_M.KEY_0]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_1]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_2]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_3]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_4]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_5]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_6]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_7]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_8]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_9]          = {_M.keyGroup.numpad, _M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_POWER]      = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_ZERO]       = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_TARE]       = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_SEL]         = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_F1]         = {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
    [_M.KEY_F2]         = {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
    [_M.KEY_F3]         = {_M.keyGroup.primary,_M.keyGroup.functions, _M.keyGroup.all},
    [_M.KEY_PLUSMINUS]  = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_DP]         = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_CANCEL]     = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_UP]         = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_DOWN]       = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_OK]         = {_M.keyGroup.cursor,_M.keyGroup.keypad, _M.keyGroup.all},
    [_M.KEY_SETUP]      = {_M.keyGroup.primary, _M.keyGroup.all},
    [_M.KEY_PWR_ZERO]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_TARE]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_SEL ]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_F1  ]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_F2  ]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_F3  ]   = {_M.keyGroup.extended, _M.keyGroup.all},
    [_M.KEY_PWR_CANCEL ]   = {_M.keyGroup.extended, _M.keyGroup.all}
}

local idleTimerID, idleCallback, idleTimeout = nil, nil, 10
local runningKeyCallback = nil  -- keeps track of any running callback to prevent recursive calls

-------------------------------------------------------------------------------
-- Setup key handling stream
function _M.setupKeys()
    _M.sendRegWait(_M.CMD_EX, _M.REG_FLUSH_KEYS, 0)
    _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 1)
    keyID = _M.addStreamLib(_M.REG_GET_KEY, _M.keyCallback, 'change')
end

-------------------------------------------------------------------------------
-- Cancel keypress handling
-- @param flush Flush the current keypresses that have not yet been handled
function _M.endKeys(flush)
    if flush then
        _M.sendRegWait(_M.CMD_EX, _M.REG_FLUSH_KEYS, 0)
    end

    _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_APP_KEY_HANDLER, 0)

    _M.removeStream(keyID)
end

function _M.bumpIdleTimer()
    _M.system.timers.removeTimer(idleTimerID)
    if idleCallback then
        idleTimerID = _M.system.timers.addTimer(0,idleTimeout,idleCallback)
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
function _M.keyCallback(data, err)

    local state = "short"
    local key = bit32.band(data, 0x3F)

    if bit32.band(data, 0x80) > 0 then
        state = "long"
    end

    if bit32.band(data, 0x40) > 0 then
        state = "up"
    end

--    _M.dbg.debug('Key: ',data,err)
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
               _M.dbg.warn('Attempt to call Key Event Handler recursively : ', key)
               return
            end
            runningKeyCallback = groups.directCallback
            if groups.directCallback(key, state) == true then
                handled = true
            end
            runningKeyCallback = nil
       end

      if not handled then
          for i=1,#groups do
            if groups[i].callback then
                if runningKeyCallback == groups[i].callback then
                    _M.dbg.warn('Attempt to call Key Group Event Handler recursively : ', key)
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
        _M.sendReg(_M.CMD_WRFINALDEC,_M.REG_APP_DO_KEYS, data)
    end
    if state ~= 'up' then
        _M.bumpIdleTimer()
    end
end

-------------------------------------------------------------------------------
-- Set a callback to run if more than t seconds of idle time is detected
-- between keys.  This is used to trap operator leaving without proper menu exit.
-- @param f function to run when idle time expired
-- @param t is timeout in seconds
-- @usage
-- local function idle()
--    dwi.abortDialog()
-- end
-- dwi.setIdleCallback(idle,15) -- call idle if 15 seconds elapses between keys
function _M.setIdleCallback(f,t)
   idleCallback = f
   idleTimeout = t or 10
end
-------------------------------------------------------------------------------
-- Set the callback function for an existing key
-- @param key to monitor (KEY_* )
-- @param callback Function to run when there is an event for that key.
-- Callback function parameters are key (.KEY_OK etc) and state ('short' or 'long')
-- @usage
-- local function F1Pressed(key, state)
--  if state == 'short' then
--       dbg.info('F1 pressed')
--    end
--    return true    -- F1 handled here so don't send back to instrument for handling
--  end
--  dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)
--
function _M.setKeyCallback(key, callback)
    keyBinds[key].directCallback = callback
end

--- Key Groups.
--@table keygroups
-- @field keyGroup.all
-- @field keyGroup.primary
-- @field keyGroup.functions
-- @field keyGroup.keypad
-- @field keyGroup.numpad
-- @field keyGroup.cursor
-- @field keyGroup.extended

-------------------------------------------------------------------------------
-- Set the callback function for an existing key group
-- Return true in the callback to prevent the handling from being passed along to the next keygroup
-- @param keyGroup A keygroup given in keyGroup.*
-- @param callback Function to run when there is an event on the keygroup
-- Callback function parameters are key (.KEY_OK etc) and state ('short' or 'long')
function _M.setKeyGroupCallback(keyGroup, callback)
    keyGroup.callback = callback
end

-------------------------------------------------------------------------------
-- Send an artificial  key press to the instrument
-- @param key (.KEY_*)
-- @param status 'long' or 'short'
function _M.sendKey(key,status)
    if key then
        local data = key
        if status == 'long' then
            data = bit32.bor(data, 0x80)
        end
        _M.sendRegWait(_M.CMD_WRFINALDEC,_M.REG_APP_DO_KEYS, data)
    end
end

end
