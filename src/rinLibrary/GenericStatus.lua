-------------------------------------------------------------------------------
--- Status Monitoring.
-- Functions associated with the status monitoring
-- @module rinLibrary.Device.Status
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local pairs = pairs
local ipairs = ipairs
local math = math
local type = type
local tonumber = tonumber
local table = table

local bit32 = require "bit"
local system = require 'rinSystem'
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local utils = require 'rinSystem.utilities'
local timers = require 'rinSystem.rinTimers'
local pow2 = require 'rinLibrary.powersOfTwo'
local usb = require 'rinLibrary.rinUSB'
local True, False = utils.True, utils.False

-------------------------------------------------------------------------------
-- Return the bit position of a set bit in the passed integer value
-- We use a De Bruijn sequence here for efficiency reasons
-- @function findSetBit
-- @param n The number to scan
-- @return 1 .. 32, or 0 for no set bits
-- @return Bitmask with the specified bit set
-- @return The input number with the specified bit removed
-- @local
local findSetBitMap = {
    1, 2, 11, 3, 12, 15, 23, 4, 31, 13, 16, 18, 20, 24, 27, 5, 32, 10,
    14, 22, 30, 17, 19, 26, 9, 21, 29, 25, 8, 28, 7, 6
}
local function findSetBit(n)
    if n == 0 then
        return 0, 0, 0
    end
    if bit32.band(n, 0x80000000) ~= 0 then
        return 32, 0x80000000, bit32.band(n, 0x7fffffff)
    end
    local r = findSetBitMap[math.floor(bit32.band(n, -n) * 0.971032835543155670166015625) % 32 + 1]
    local mask = pow2[r-1]
    return r, mask, n - mask
end

-------------------------------------------------------------------------------
-- Function to test if any of the specified bits are set in the data.
-- @param data The value to check against.
-- @param checkf Function to validate each bit
-- @param ... The bit positions of interest.
-- @return true iff one of the bits is set.
-- @local
local function anyBitSet(data, checkf, ...)
    for i,v in ipairs{...} do
        checkf(v)
        if bit32.band(pow2[v-1], data) ~= 0 then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Function to test if all of the specified bits are set in the data.
-- @param data The value to check against.
-- @param checkf Function to validate each bit
-- @param ... The bit positions of interest.
-- @return true iff all of the bits is set.
-- @local
local function allBitSet(data, checkf, ...)
    local args = {...}
    if #args == 0 then
        return false
    end

    for i,v in ipairs(args) do
        checkf(v)
        if bit32.band(pow2[v-1], data) == 0 then
            return false
        end
    end
    return true
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--- Status Bits for register sysstatus.
--@table sysstatus
-- @field overload Scale overloaded
-- @field underload Scale underload
-- @field err Error active
-- @field setup Instrument in setup mode
-- @field calinprog Instrument calibration in progress
-- @field motion Weight unstable
-- @field centreofzero Centre of Zero (within 0.25 divisions of zero)
-- @field zero Weight within zero band setting
-- @field net Instrument in Net mode
-- @field adcinprogress ADV operation in progress
-- @field lastadvokay Last ADC operation was successful
-- @field tiltxy Tilt XY high (K491 only)
-- @field tiltx Tilt X high (K491 only)
-- @field tilty Tilt Y high (K491 only)
-- @see checkAnySystemStatus
-- @see checkAllSystemStatus
local sysStatusMap
private.registerDeviceInitialiser(function()
    sysStatusMap = {
        adcinprogress   = 0x00080000,
        lastadcokay     = 0x00040000,
        overload        = 0x00020000,
        underload       = 0x00010000,
        err             = 0x00008000,
        setup           = 0x00004000,
        calinprog       = 0x00002000,
        motion          = 0x00001000,
        centreofzero    = 0x00000800,
        zero            = 0x00000400,
        net             = 0x00000200,
        tiltxy          = private.k491(0x00100000),
        tiltx           = private.k491(0x00200000),
        tilty           = private.k491(0x00400000)
    }
end)

local REG_LUA_IOSTATUS = 0x0051
local REG_LUA_STATUS   = 0x0329
local REG_LUA_ESTAT    = 0x0305
local REG_LUA_STAT_RTC = 0x032A
local REG_SETPSTATUS   = 0x032E
local REG_LUA_STAT_NET = 0x030A

local REG_LUA_USB_NOTIFY = 0x0371

--- Status Bits for register lua_status.
--@table luastatus
-- @field net Displayed weight is in NET mode
-- @field gross Displayed weight is in GROSS mode
-- @field zero Weight is in zero band
-- @field notzero Weight is not in zero band
-- @field coz Weight is in Centre Of Zero (within 0.25 divisions of zero)
-- @field notcoz Weight is not in Centre of Zero
-- @field motion Weight is unstable
-- @field notmotion Weight is stable
-- @field range1 Weight is in range/interval 1
-- @field range2 Weight is in range/interval 2
-- @field pt Tare in use is a preset tare
-- @field notpt Tare in use is not a preset tare
-- @field error There is an error active
-- @field uload Scale is underloaded
-- @field oload Scale is overloaded
-- @field noterror There is no error active
-- @field held Weight is held, not available in batching firmware
-- @field notheld Weight is not held, not available in batching firmware
-- @field idle Batch: Batch or truck is idle. Only available in batching firmware and K422
-- @field run Batch is running, only available in batching firmware
-- @field pause Batch is paused, only available in batching firmware
-- @field slow Batch is filling at slow speed, only available in batching firmware
-- @field med Batch is filling at medium speed, only available in batching firmware
-- @field fast Batch is filling at fast speed, only available in batching firmware
-- @field time Batch is waiting for a timer to finish, only available in batching firmware
-- @field input Batch is waiting for an input, only available in batching firmware
-- @field no_info None of the 5 status bits above are true, only available in batching firmware
-- @field fill Batch is in a fill stage, only available in batching firmware
-- @field dump Batch is in a dump stage, only available in batching firmware
-- @field pulse Batch is in a pulse stage, only available in batching firmware
-- @field start Batch is in the start stage, only available in batching firmware
-- @field no_type None of the 4 status bits above are true, only available in batching firmware
-- @field belowmin the weight is below the minimum set for axle capture K422 only
-- @field abovemin the wieght is above the minimum set for axle capture K422 only
-- @field sampling the instrument is currently measuring an axle K422 only
-- @field captured the instrument has captured an axle weight K422 only
-- @field waiting the instrument is waiting for another axle K422 only
-- @field nodynerror there have been no errors on the current truck K422 only
-- @field fasterror the truck was moving too fast to weigh accurately K422 only
-- @field slowerror the truck was moving too slowly K422 only
-- @field traceerror the instrument could not get a traceable reading K422 only
-- @field weighterror the captured axle weight was below the minimum set K422 only
-- @field direrror the truck was travelling in the wrong direction K422 only
-- @field ilockerror there was an interlock error on the current truck K422 only
--
-- @field hires Weight is in high resolution (x10) mode
-- @field dispmode Display mode in 2 bits of data, 0 for calibrated units, 1 for piece counting and 2 for alternate units
-- @field range The current range/interval, 0 for range/interval 1, 1 for range/interval 2
-- @field menu_active The user is currently in the menus
-- @field prod_load The product has just been changed/loaded
-- @field prod_save The product has just been updated/saved
-- @field power_off The user is holding the power key down and the power off count-down is currently being displayed
-- @field init The settings have been re-initialised
-- @field rtc When the RTC status has been enabled this value will toggle each second @see writeRTCStatus
-- @field ser1 When network 1 new message is enabled this will be set when there is a new message on network 1 @see writeNetStatus, not available in batching firmware
-- @field ser2 When network 2 new message is enabled this will be set when there is a new message on network 2 @see writeNetStatus, not available in batching firmware
-- @see setStatusCallback
-- @see anyStatusSet
-- @see allStatusSet
-- @see waitStatus
local statusMap, statusUnmap
private.registerDeviceInitialiser(function()
    statusMap = {
        net         = 0x00000001,
        gross       = 0x00000002,
        zero        = 0x00000004,
        notzero     = 0x00000008,
        coz         = 0x00000010,
        notcoz      = 0x00000020,
        motion      = 0x00000040,
        notmotion   = 0x00000080,
        range1      = 0x00000100,
        range2      = 0x00000200,
        pt          = 0x00000400,
        notpt       = 0x00000800,
        error       = 0x00001000,
        uload       = 0x00002000,
        oload       = 0x00004000,
        noterror    = 0x00008000,
-- Non-batching status bits
        held        = private.nonbatching(0x00010000),
        notheld     = private.nonbatching(0x00020000),
-- This one appears in both batching and axle weighing but with different positions
        idle        = private.batching(0x00010000) or private.k422(0x00040000),
-- Batching specific status bits
        run         = private.batching(0x00020000),
        pause       = private.batching(0x00040000),
        slow        = private.batching(0x00080000),
        med         = private.batching(0x00100000),
        fast        = private.batching(0x00200000),
        time        = private.batching(0x00400000),
        input       = private.batching(0x00800000),
        no_info     = private.batching(0x01000000),
        fill        = private.batching(0x02000000),
        dump        = private.batching(0x04000000),
        pulse       = private.batching(0x08000000),
        start       = private.batching(0x10000000),
        no_type     = private.batching(0x20000000),
        jog         = private.batching(0x40000000),
-- K422 specific status bits
        belowmin    = private.k422(0x00010000),
        abovemin    = private.k422(0x00020000),
        sampling    = private.k422(0x00080000),
        captured    = private.k422(0x00100000),
        waiting     = private.k422(0x00200000),
        nodynerror  = private.k422(0x00400000),
        fasterror   = private.k422(0x00800000),
        slowerror   = private.k422(0x01000000),
        traceerror  = private.k422(0x02000000),
        weighterror = private.k422(0x04000000),
        direrror    = private.k422(0x08000000),
        ilockerror  = private.k422(0x10000000),
    }
    statusUnmap = utils.invert(statusMap)
end)

-- Extended status bits
local ESTAT_HIRES           = 0x00000001
local ESTAT_DISPMODE        = 0x00000006
local ESTAT_DISPMODE_RS     = 1
local ESTAT_RANGE           = 0x00000018
local ESTAT_RANGE_RS        = 3

-- Status Bits for Extended Status.
--
-- You don't need to access these directly, the standard status routines know
-- about both normal status and extended status (but not system status).
local estatusMap = {
    hires       = ESTAT_HIRES,
    dispmode    = ESTAT_DISPMODE,
    range       = ESTAT_RANGE,
    menu_active = 0x00000020,
    prod_load   = 0x00000040,
    prod_save   = 0x00000080,
    power_off   = 0x00000100,
    usb_notify  = 0x00000200,
    init        = 0x01000000,
    rtc         = 0x02000000,
    ser1        = 0x10000000,
    ser2        = 0x20000000
}
local estatusUnmap = utils.invert(estatusMap)

local statBinds = {}
local statID = nil

local eStatBinds = {}
local eStatID = nil

local ioTable = {
    name = 'IO',
    max = function() return 32 end,
    current = 0,
    running = false,
    active = {}
}

local setpointTable = {
    name = 'setpoint',
    max = function() return _M.setPointCount() end,
    current = 0,
    running = false,
    active = {}
}

local IOID = nil
local SETPID = nil

local curStatus, curEStatus

local netStatusMap = { net1 = 1, net2 = 2, both = 3, none = 0, ["1"] = 1, ["2"] = 2 }

local ioState = {}
local keyNames = nil

-------------------------------------------------------------------------------
-- Return the canonical key name for the specified IO/set point
-- @function formatIOsName
-- @return formatted IO/set point key name
-- @local
function private.formatIOsName(type, n)
    return type .. '_' .. n
end

-------------------------------------------------------------------------------
-- Return a mapping of all IO and set point key names
-- @function getIOsNames
-- @return Mapping table of IO and set point names
-- @local
function private.getIOsNames()
    if keyNames == nil then
        keyNames = {}
        for n = 1, ioTable.max() do
            local s = private.formatIOsName('io', n)
            keyNames[s] = s
        end
        for n = 1, _M.setPointCount() do
            local s = private.formatIOsName('setpoint', n)
            keyNames[s] = s
        end
    end
    return keyNames
end

-------------------------------------------------------------------------------
-- Check if the specified IO is an input
-- @function checkInput
-- @param io IO to be checked
-- @param msg Error message if IO is an output (optional)
-- @return true iff the IO is an input
-- @local
function private.checkInput(io, msg)
    if ioState[io] then
        local f = dbg.error
        if not msg then
            msg = 'using output as an input is ill advised'
            f = dbg.warn
        end
        if not ioState[msg] then
            ioState[msg] = true
            f('IO'..io..':', msg)
        end
        return false
    end
    return true
end

-------------------------------------------------------------------------------
-- Check if the specified IO is an output
-- @function checkOutput
-- @param io IO to be checked
-- @return true iff the IO is an output
-- @local
function private.checkOutput(io)
    if not ioState[io] then
        if not ioState.warnOutput then
            ioState.warnOutput = true
            dbg.error('IO'..io..':', 'outputs cannot be used as inputs')
        end
        return false
    end
    return true
end

-------------------------------------------------------------------------------
-- Set an IO to be an output or input
-- @function setIOkind
-- @param io IO to set
-- @param output Boolean, true means output
-- @local
function private.setIOkind(io, output)
    ioState[io] = output
end

-------------------------------------------------------------------------------
-- Query the current system status.
-- @return System status
-- @return Error code, nil if none
-- @local
function private.getSystemStatus()
    local msg, err = private.readRegHex('sysstatus', 1.0)
    if msg ~= nil then
        return tonumber(msg, 16), nil
    end
    return nil, err
end

-------------------------------------------------------------------------------
-- Scan the arguments for a status setting and if it isn't there query it.
-- @param status Status number (optional)
-- @param ... Statuses to check for (as strings)
-- @return System status
-- @return List of status names
-- @local
local function checkOptionalSystemStatus(status, ...)
    if type(status) == 'number' then
        return status, {...}
    end

    return private.getSystemStatus(), {status, ...}
end

-------------------------------------------------------------------------------
-- Check if any of the listed system statuses are present.
-- @tparam sysstatus status System status code
-- @tparam sysstatus ... Statuses to check for
-- @treturn bool True if any one of the referenced statuses is current
-- @see checkAllSystemStatus
-- @usage
-- local nonZero = not device.checkAnySystemStatus('zero')
function _M.checkAnySystemStatus(status, ...)
    local s, p = checkOptionalSystemStatus(status, ...)

    for _, bit in pairs(p) do
        if bit32.band(s, naming.convertNameToValue(bit, sysStatusMap, 0)) ~= 0 then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Check if all of the listed system statuses are present.
-- @tparam sysstatus status System status code
-- @tparam[opt] sysstatus ... Statuses to check for (as strings)
-- @treturn bool True if any one of the referenced statuses is current
-- @see checkAnySystemStatus
-- @usage
-- local zeroNet = device.checkAllSystemStatus('zero', 'net')
function _M.checkAllSystemStatus(status, ...)
    local s, p = checkOptionalSystemStatus(status, ...)

    for _, bit in pairs(p) do
        if bit32.band(s, naming.convertNameToValue(bit, sysStatusMap, 0)) == 0 then
            return false
        end
    end
    return true
end

-------------------------------------------------------------------------------
-- Called when stream data is being renewed
-- @local
function private.renewStatusBinds()
    for _, v in pairs(ioTable.active) do
        v.lastStatus = nil
    end
    for _, v in pairs(setpointTable.active) do
        v.lastStatus = nil
    end
    for _, v in pairs(statBinds) do
        v.lastStatus = nil
    end
    for _, v in pairs(eStatBinds) do
        v.lastStatus = nil
    end
end

-------------------------------------------------------------------------------
-- Called when extended status changes are streamed
-- @param data Data on status streamed
-- @param err Potential error message
-- @local
local function eStatusCallback(data, err)
    curEStatus = data
    private.updateSettings(
        bit32.band(data, ESTAT_HIRES) > 0,
        1 + bit32.rshift(bit32.band(data, ESTAT_DISPMODE), ESTAT_DISPMODE_RS),
        1 + bit32.rshift(bit32.band(data, ESTAT_RANGE), ESTAT_RANGE_RS))

    for k, v in pairs(eStatBinds) do
        local status = bit32.band(data,k)
        if status ~= v.lastStatus  then
            if v.running then
                dbg.warn('Ext Status Event lost: ',string.format('%08X',k),status ~= 0)
            else
                local estatName = naming.convertValueToName(k, estatusUnmap, nil)
                v.lastStatus = status
                v.running = true
                utils.call(v.mainf, estatName, status ~= 0)
                utils.call(v.f, estatName, status ~= 0)
                v.running = false
            end
         end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for an extended status bit
-- @param eStatus Extended status bit
-- @param callback Function to run when there is an event on change in status
-- @see setEStatusMainCallback
local function setEStatusCallback(eStatus, callback)
    utils.checkCallback(callback)
    local eStat = naming.convertNameToValue(eStatus, estatusMap)
    if eStat then
        eStatBinds[eStat] = eStatBinds[eStat] or {}
        eStatBinds[eStat].f = callback
        eStatBinds[eStat].lastStatus = nil
    end
end

-------------------------------------------------------------------------------
-- Set the main library callback function for an extended status bit
-- @function setEStatusMainCallback
-- @param eStatus Extended status bit
-- @param callback Function to run when there is an event on change in status
-- @see setEStatusCallback
-- @local
function private.setEStatusMainCallback(eStatus, callback)
    utils.checkCallback(callback)
    local eStat = naming.convertNameToValue(eStatus, estatusMap)
    if eStat then
        eStatBinds[eStat] = eStatBinds[eStat] or {}
        eStatBinds[eStat].mainf = callback
        eStatBinds[eStat].lastStatus = nil
    end
end

-------------------------------------------------------------------------------
-- Called when status changes are streamed
-- @param data Data on status streamed
-- @param err Potential error message
-- @local
local function statusCallback(data, err)
    curStatus = data
    private.callbackLCDStatus()
    for k,v in pairs(statBinds) do
        local status = bit32.band(data,k)
        if status ~= v.lastStatus  then
            if v.running then
                dbg.warn('Status Event lost: ',string.format('%08X %08X',k,status))
            else
                local sname = naming.convertValueToName(k, statusUnmap)
                local sval = status ~= 0
                v.lastStatus = status
                v.running = true
                utils.call(v.mainf, sname, sval)
                utils.call(v.f, sname, sval)
                v.running = false
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a status bit
-- @tparam ?luastatus|{luastatus,..} status Status name or table of statuses (OR joined, not AND)
-- @func callback Function to run when there is an event on change in status
-- @see anyStatusSet
-- @see allStatusSet
-- @see waitStatus
-- @usage
-- device.setStatusCallback('motion', function(stat, value) print('motion of', stat, 'is', value) end)
function _M.setStatusCallback(status, callback)
    utils.checkCallback(callback)
    local function addCallback(status)
      local stat = naming.convertNameToValue(status, statusMap)
      if stat then
          statBinds[stat] = statBinds[stat] or {}
          statBinds[stat].f = callback
          statBinds[stat].lastStatus = nil
      else
          setEStatusCallback(status, callback)
      end
    end
    
    if type(status) == "table" then
      for k,statusItem in pairs(status) do
        addCallback(statusItem) 
      end
    else
      addCallback(status)
    end    
end

-------------------------------------------------------------------------------
-- Set the internal callback function for a status bit
-- @param status status name
-- @param callback Function to run when there is an event on change in status
-- @see setStatusCallback
-- @local
function private.setStatusMainCallback(status, callback)
    utils.checkCallback(callback)

    local stat = naming.convertNameToValue(status, statusMap)
    if stat then
        statBinds[stat] = statBinds[stat] or {}
        statBinds[stat].mainf = callback
        statBinds[stat].lastStatus = nil
    else
        private.setEStatusMainCallback(status, callback)
    end
end

-------------------------------------------------------------------------------
-- Called to check state of current instrument status
-- @tparam luastatus ... Status bits to check
-- @treturn bool True if any of the status bits are set in current instrument status
-- @see setStatusCallback
-- @see allStatusSet
-- @see waitStatus
-- @usage
-- device.enableOutput(5)
-- if device.anyStatusSet('motion', 'stat_err', 'oload', 'uload') then
--     device.turnOn(5)  -- turn on output 5 if motion or any errors
-- else
--     device.turnOff(5)
-- end
function _M.anyStatusSet(...)
    for i, v in pairs{...} do
        local b = naming.convertNameToValue(v, statusMap)
        if b then
            if bit32.band(curStatus, b) ~= 0 then
                return true
            end
        else
            b = naming.convertNameToValue(v, estatusMap)
            if b and bit32.band(curEStatus, b) ~= 0 then
                return true
            end
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Called to check state of current instrument status
-- @tparam luastatus ... Status bits to check
-- @treturn bool True if all of the status bits are set in cur instrument status
-- @see setStatusCallback
-- @see anyStatusSet
-- @see waitStatus
-- @usage
-- device.enableOutput(5)
-- if device.allStatusSet('notmotion', 'notzero', 'gross') then
--     device.turnOn(5)  -- turn on output 5 if stable gross weight not in zero band
-- else
--     device.turnOff(5)
-- end
function _M.allStatusSet(...)
    local args = {...}
    if #args == 0 then
        return false
    end

    for i, v in pairs(args) do
        local b = naming.convertNameToValue(v, statusMap)
        if b then
            if bit32.band(curStatus, b) == 0 then
                return false
            end
        else
            b = naming.convertNameToValue(v, estatusMap)
            if not b or bit32.band(curEStatus, b) == 0 then
                return false
            end
        end
    end
    return true
end

-------------------------------------------------------------------------------
-- Wait until selected status bits are true
-- @tparam luastatus ... Status bits to wait for (can also take an int to 
-- specify an optional timeout)
-- @treturn bool True if the wait succeeded and false otherwise
-- @see setStatusCallback
-- @see anyStatusSet
-- @see allStatusSet
-- @see waitStatus
-- @usage
-- device.waitStatus('notmotion')           -- wait for no motion
-- device.waitStatus('coz')                 -- wait for Centre of zero
-- device.waitStatus('zero', 'notmotion')   -- wait for no motion and zero
function _M.waitStatus(...)
    local stat, finished, args = 0, False, {}
    for _, v in pairs({...}) do
        if type(v) == 'number' and v > 0 and finished == False then
            finished = timers.addOneShot(v)
        elseif type(v) == 'string' then
            table.insert(args, v)
        end
    end
    _M.app.delayUntil(function()
        return _M.allStatusSet(unpack(args)) or finished()
    end)
    return not finished()
end

-------------------------------------------------------------------------------
-- Called when IO status changes are streamed
-- @param t Table defining the type of bit event
-- @param data Data on SETP status streamed
-- @param err Potential error message
-- @local
local function IOsCallback(t, data, err)
    local old = t.current
    t.current = data

    -- Process active watchers.  This should be merged into the loop below but
    -- that will change the behaviour slightly which might break backwards
    -- compatibility.
    for k, v in pairs(t.active) do
        local status = v.status(data)
        if status ~= v.lastStatus then
            if v.running then
                dbg.warn(t.name .. ' event lost:', k, v.warnlost(status))
            else
                v.lastStatus = status
                v.running = true
                v.cb(status)
                v.running = false
            end
        end
    end

    -- Check for simulated key events for this io/set point efficiently
    local z, n, p2 = bit32.bxor(data, old)
    while z ~= 0 do
        n, p2, z = findSetBit(z)
        private.ioKey(t.name, n, bit32.band(data, p2) ~= 0)
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a IO
-- @param t Table defining the type of bit event
-- @param which The bit number we're interested in
-- @param callback Function taking IO and on/off status as parameters
-- @local
local function addIOsCallback(t, which, callback)
    utils.checkCallback(callback)

    if which < 1 or which > t.max() then
        dbg.error('addCallback ' .. t.name .. ' Invalid:', which)
    else
        local bit = pow2[which-1]
        if callback then
            t.active[which] = {
                status = function(s) return bit32.band(s, bit) end,
                warnlost = function(s) return s ~= 0 end,
                cb = function(s) return callback(which, s ~= 0) end
            }
        else
            t.active[which] = nil
            dbg.debug('addCallback:', 'nil value for '..t.name..' callback function')
        end
    end
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any IO status changes
-- @param t Table defining the type of bit event
-- @param callback Function taking current IO status as a parameter
-- @local
local function addIOsAllCallback(t, callback)
    utils.checkCallback(callback)
    if callback then
        t.active.all = {
            status = function(s) return s end,
            warnlost = function(s) return string.format('%08X', s) end,
            cb = function(s) return callback(s) end
        }
    else
        t.active.all = nil
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a IO
-- @tparam ?int|{int,..} io 1..32, or table of values (e.g. {1,2,15})
-- @func callback Function taking IO and on/off status as parameters
-- @see setAllIOCallback
-- @see getCurIO
-- @see anyIOSet
-- @see allIOSet
-- @see waitIO
-- @usage
-- function handleIO1(IO, active)
--     if (active) then
--         print (IO,' is on!')
--     end
-- end
-- device.setIOCallback(1, handleIO1)
function _M.setIOCallback(io, callback)
  if type(io) == "table" then
    for k,ioItem in pairs(io) do
      private.checkInput(ioItem)
      addIOsCallback(ioTable, ioItem, callback) 
    end
  else
    private.checkInput(io)
    return addIOsCallback(ioTable, io, callback)
  end
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any IO status changes
-- @func callback Function taking current IO status as a parameter
-- @see setIOCallback
-- @see getCurIO
-- @see anyIOSet
-- @see allIOSet
-- @see waitIO
-- @usage
-- function handleIO(data)
--     -- 4 bits of status information for IO 3..6 turned into a grading indication
--     curGrade = bit32.rshift(bit32.band(data,0x03C),2)
-- end
-- device.setAllIOCallback(handleIO)
function _M.setAllIOCallback(callback)
    return addIOsAllCallback(ioTable, callback)
end

-------------------------------------------------------------------------------
-- Set the callback function for a SETP
-- @int setpoint 1 .. setPointCount()
-- @func callback Function taking SETP and on/off status as parameters
-- @see setAllSETPCallback
-- @see anySETPSet
-- @see allSETPSet
-- @see waitSETP
-- @usage
-- function handleSETP1(SETP, active)
--     if (active) then
--         print (SETP,' is on!')
--     end
-- end
-- device.setSETPCallback(1, handleSETP1)
function _M.setSETPCallback(setpoint, callback)
    return addIOsCallback(setpointTable, setpoint, callback)
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any SETP status changes
-- @func callback Function taking current SETP status as a parameter
-- @see setSETPCallback
-- @see anySETPSet
-- @see allSETPSet
-- @see waitSETP
-- @usage
-- function handleSETP(data)
--     -- 4 bits of status information for SETP 3..6 turned into a grading indication
--     curGrade = bit32.rshift(bit32.band(data,0x03C),2)
-- end
-- device.setAllSETPCallback(handleSETP)
function _M.setAllSETPCallback(callback)
    return addIOsAllCallback(setpointTable, callback)
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO
-- @treturn int 32 bits of IO data
-- @see setIOCallback
-- @see setAllIOCallback
-- @see getCurIOStr
-- @see anyIOSet
-- @see allIOSet
-- @see waitIO
-- @usage
-- print('current IO bits are', device.getCurIO())
function _M.getCurIO()
    return ioTable.current
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO as a string of 1s and 0s
-- @param data The binary integer being converted
-- @param bits The number of significant bits in data
-- @return 32 characters of IO data
-- @local
local function getBitStr(data, bits)
    local s = {}
    local ch
    for i = bits-1, 0, -1 do
        if bit32.band(data, pow2[i]) ~= 0 then
            ch = '1'
        else
            ch = '0'
        end
        table.insert(s,ch)
    end
    return table.concat(s)
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO as a string of 1s and 0s
-- @treturn string 32 characters of IO data
-- @see getCurIO
-- @usage
-- print('current IO bits are: ' .. device.getCurIOStr())
function _M.getCurIOStr()
    return getBitStr(ioTable.current, 32)
end

-------------------------------------------------------------------------------
-- Called to check state of current IO
-- @int ... IOs to check
-- @treturn bool True if any of the listed IO are active
-- @see setIOCallback
-- @see setAllIOCallback
-- @see getCurIO
-- @see allIOSet
-- @see waitIO
-- @usage
-- device.enableOutput(3)
-- if not device.anyIOSet(1,2,4,5) then
--     device.turnOn(3)  -- turn on output 3 if no other outputs on
-- else
--     device.turnOff(3)
-- end
function _M.anyIOSet(...)
    return anyBitSet(ioTable.current, private.checkInput, ...)
end

-------------------------------------------------------------------------------
-- Called to check state of IO
-- @int ... IOs to check
-- @treturn bool True if all of the listed IO are active
-- @see setIOCallback
-- @see setAllIOCallback
-- @see getCurIO
-- @see anyIOSet
-- @see waitIO
-- @usage
-- device.enableOutput(3)
-- if device.allIOSet(1,2) then
--     device.turnOn(3)  -- turn on output 3 if IO 1 and 2 both on
-- else
--     device.turnOff(3)
-- end
function _M.allIOSet(...)
    return allBitSet(ioTable.current, private.checkInput, ...)
end

-------------------------------------------------------------------------------
-- Called to get current state of the 16 setpoints
-- @treturn int 16 bits of SETP status data
-- @usage
-- print('current setpoint bits are', device.getCurSETP())
function _M.getCurSETP()
    return setpointTable.current
end

-------------------------------------------------------------------------------
-- Called to check state of current SETP
-- @int ... Set points to check
-- @treturn bool True if any of the listed SETP are active
-- @see setSETPCallback
-- @see setAllSETPCallback
-- @see allSETPSet
-- @see waitSETP
-- @usage
-- device.enableOutput(1)
-- if not device.anySETPSet(1,2) then
--     device.turnOn(1)  -- turn on output 1 if setpoints 1 and 2 are both inactive
-- else
--     device.turnOff(1)
-- end
function _M.anySETPSet(...)
    return anyBitSet(setpointTable.current, True, ...)
end

-------------------------------------------------------------------------------
-- Called to check state of SETP
-- @tab t Table defining the type of bit event
-- @int ... Set points to check
-- @treturn bool True if all of the listed IO are active
-- @see setSETPCallback
-- @see setAllSETPCallback
-- @see anySETPSet
-- @see waitSETP
-- @usage
-- device.enableOutput(1)
-- if device.allSETPSet(1, 2) then
--     device.turnOn(1)  -- turn on output 1 if Setpoints 1 and 2 are active
-- else
--     device.turnOff(1)
-- end
function _M.allSETPSet(...)
    return allBitSet(setpointTable.current, True, ...)
end

-------------------------------------------------------------------------------
-- Wait until IO is in a particular state
-- @param t Table defining the type of bit event
-- @param bit 1..32
-- @param state true to wait for IO to come on or false to wait for it to go off, default off
-- @param timeout the maximum time to wait, default to wait forever
-- @return true if the wait succeeded and false otherwise
-- @local
local function IOsWait(t, bit, state, timeout)
    if bit < 1 or bit > t.max() then
        dbg.error('IOsWait '..t.name..' invalid:', bit)
        return false
    end
    local mask = pow2[bit-1]
    local finished = (timeout or 0) > 0 and timers.addOneShot(timeout) or False
    local ns = not state

    _M.app.delayUntil(function()
        return ns == (bit32.band(t.current, mask) == 0) or finished()
    end)
    return not finished()
end

-------------------------------------------------------------------------------
-- Wait until IO is in a particular state
-- @int IO 1..32
-- @bool[opt] state True to wait for IO to come on or false to wait for it to 
-- go off. Default false.
-- @int[opt] timeout The maximum time in seconds to wait for the IOs. Default to 
-- wait forever.
-- @treturn bool True if the wait succeeded and false otherwise
-- @see setIOCallback
-- @see setAllIOCallback
-- @see getCurIO
-- @see anyIOSet
-- @see allIOSet
-- @usage
-- device.waitIO(1, true) -- wait until IO1 turns on
function _M.waitIO(IO, state, timeout)
    private.checkInput(IO, 'waiting on an output is a very bad idea')
    return IOsWait(ioTable, IO, state, timeout)
end

-------------------------------------------------------------------------------
-- Wait until SETP is in a particular state
-- @int SETP 1 .. setPointCount()
-- @bool[opt] state True to wait for SETP to come on or false to wait for it to
--  go off. Default false.
-- @int[opt] timeout The maximum time in seconds to wait for the IOs. Default to 
-- wait forever.
-- @treturn bool True if the wait succeeded and false otherwise
-- @see setSETPCallback
-- @see setAllSETPCallback
-- @see anySETPSet
-- @see allSETPSet
-- @see waitSETP
-- @usage
-- device.waitSETP(1, true) -- wait until Setpoint 1 turns on
function _M.waitSETP(SETP, state, timeout)
    return IOsWait(setpointTable, IO, state, timeout)
end

-------------------------------------------------------------------------------
-- Control the use of RTC status bit.
-- The RTC status is enabled as part of the normal initialisation process
-- for the application framework.  You shouldn't need to call this and if
-- in doubt don't.
-- @param s true to enable RTC change monitoring, false to disable
-- @usage
-- device.writeRTCStatus(true)  -- enable RTC monitoring
-- device.writeRTCStatus(false) -- disable RTC monitoring
-- @local
local function writeRTCStatus(s)
    private.writeRegHex(REG_LUA_STAT_RTC, s == false and 0 or 1)
end

-------------------------------------------------------------------------------
-- Process a RTC update tick
-- @param status Status
-- @param active Active?
-- @local
local function handleRTC(status, active)
    private.RTCtick()
end

-------------------------------------------------------------------------------
-- Process initialisation status message
-- @param status Status
-- @param active Active?
-- @local
local function handleINIT(status, active)
    if active then
        private.resetRegisterInfoCache()
        timers.addEvent(function()
            dbg.info('Event:', 'INIT')
            private.readSettings()
            private.RTCread()
        end)
    end
end

-------------------------------------------------------------------------------
-- Handle the power off key being held down.  This doesn't mean we can exit
-- since the operation can be cancelled.  It does mean we should prepair as
-- best we can for a loss of power.
--
-- Specifically, we write everything outstanding to disc/flash.
-- @param status Status
-- @param active Active?
-- @local
local function handlePowerOff(status, active)
    if active then
        dbg.info('Event:', 'Power Off')
        utils.sync()
    end
end

-------------------------------------------------------------------------------
-- Handle the USB notify flag being set. This is set high when the host device
-- has mounted a USB device that we can access.
--
-- @param status Status
-- @param active Active?
-- @local
local handleUSBNotifyFirstRun = true
function _M.handleUSBNotify(status, active)

  -- If the status is high
  if active then
    -- Read the notification from the device.
    local data, err = private.readRegLiteral(REG_LUA_USB_NOTIFY)
    if err == nil and data ~= "" then
      -- Call the partition callback with the two capture groups
      local event, device = string.match(data, "^([a-z]+): (.*)$")
      -- Handle callback on first run
      if (handleUSBNotifyFirstRun == true and event == "added")
          or handleUSBNotifyFirstRun == false then
        usb.usbCallback({{"partition", event, device}})
      end
    end
  end
  handleUSBNotifyFirstRun = false
end

-------------------------------------------------------------------------------
-- Control the use of Net status bits
-- @string status net1, net2, both or none
-- @usage
-- device.writeNetStatus('net1')
-- device.writeNetStatus('none')
-- device.writeNetStatus('both')
function _M.writeNetStatus(status)
    local s = naming.convertNameToValue(status, netStatusMap, 0)
    private.writeRegHex(REG_LUA_STAT_NET, s)
end

-------------------------------------------------------------------------------
-- Setup status monitoring via a stream.
-- This routine is called automatically by the rinApp application framework.
-- @usage
-- device.setupStatus()
function _M.setupStatus()
    curStatus, curEStatus = 0, 0
    statID  = _M.addStream(REG_LUA_STATUS, statusCallback, 'change')
    eStatID = _M.addStream(REG_LUA_ESTAT,  eStatusCallback, 'change')
    IOID    = _M.addStream(REG_LUA_IOSTATUS, function(d, e) IOsCallback(ioTable, d, e) end, 'change')
    SETPID  = _M.addStream(REG_SETPSTATUS, function(d, e) IOsCallback(setpointTable, d, e) end, 'change')
    private.RTCread()
    private.setEStatusMainCallback('rtc',  handleRTC)
    private.setEStatusMainCallback('init', handleINIT)
    private.setEStatusMainCallback('power_off', handlePowerOff)
    private.setEStatusMainCallback('usb_notify', _M.handleUSBNotify)
    writeRTCStatus(true)
end

-------------------------------------------------------------------------------
-- Cancel status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endStatus()
function _M.endStatus()
    writeRTCStatus(false)
    private.setEStatusMainCallback('rtc',  nil)
    private.setEStatusMainCallback('init', nil)
    private.setEStatusMainCallback('power_off', nil)
    private.setEstatusMainCallback('usb_notify', nil)
    _M.removeStream(statID)     statID = nil
    _M.removeStream(eStatID)    eStatID = nil
    _M.endIOStatus()
    _M.endSETPStatus()
end

-------------------------------------------------------------------------------
-- Cancel IO status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endIOStatus()
function _M.endIOStatus()
    _M.removeStream(IOID)
    IOID = nil
end

-------------------------------------------------------------------------------
-- Cancel SETP status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endSETPStatus()
function _M.endSETPStatus()
    _M.removeStream(SETPID)
    SETPID = nil
end

end
