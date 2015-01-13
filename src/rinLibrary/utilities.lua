-------------------------------------------------------------------------------
--- General purpose utility functions.
-- Functions for internal library use
-- @module rinLibrary.utilities
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local utils = require 'rinSystem.utilities'

local lpeg = require "rinLibrary.lpeg"
local C, P, R = lpeg.C, lpeg.P, lpeg.R

local regPattern = P'REG_' * C(R('AZ', '09', '__')^1)

local lower = string.lower
local min, max = math.min, math.max

return function(mod, private, deprecated)
    local regMap, regUnmap = { [0] = 0 }, { [0] = 0 }
    local deviceInitialisers = {}

-------------------------------------------------------------------------------
-- Check if a particular module or modules have been loaded.
-- @function isModuleLoaded
-- @param m Module name(s)
-- @return true iff all the specified modules are loaded
-- @local
    function private.isModuleLoaded(...)
        local r = true
        for _, m in pairs({...}) do
            r = r and (private.modules[m] or false)
        end
        return r
    end

-------------------------------------------------------------------------------
-- Add an entry to the register mapping table
-- @param reg Key
-- @param num Value
-- @see addRegisters
-- @local
    local function addRegister(reg, num)
        if num ~= nil then
            local r = lower(reg)
            regMap[r] = num
            regUnmap[num] = r
        end
    end

-------------------------------------------------------------------------------
-- Add a list of registers to the mapping table
-- @function addRegisters
-- @param reglist List of pairs to add
-- @see addRegister
-- @see getRegisterNumber
-- @see getRegisterName
-- @see regPopulate
-- @usage
-- private.addRegisters{{ 'regname', 0x666}}
--
-- private.addRegisters{
--     { 'dead', 0xdead },
--     { 'beef', 0xbeef }
-- }
-- @local
    function private.addRegisters(reglist)
        for r, v in pairs(reglist) do
            addRegister(r, v)
        end
    end

-------------------------------------------------------------------------------
-- Add an entry to the register mapping table if it is of the correct form
-- @function regPopulate
-- @param k Key
-- @param v Value
-- @see getRegisterNumber
-- @see getRegisterName
-- @see addRegister
-- @local
    function private.regPopulate(k, v)
        if type(k) == "string" then
            local m = regPattern:match(k)
            if m ~= nil then
                addRegister(m, v)
            end
        end
    end

-------------------------------------------------------------------------------
-- Convert a string register name to the associated register number.
-- @function getRegisterNumber
-- @param r Register name or number
-- @param silent Don't error out on an unknown register (optional, default noisy)
-- @return Register number
-- @see getRegisterName
-- @usage
-- -- Find out what register number the gross weight is stored in
-- print(private.getRegisterNumber('gross')
-- @local
    function private.getRegisterNumber(r, silent)
        local n = naming.convertNameToValue(r, regMap)
        if n == nil and not silent then
            error('rinLibrary: bad register '..tostring(r))
        end
        return n
    end

-------------------------------------------------------------------------------
-- Convert a register number to the associated canonical register name.
-- @function getRegisterName
-- @param r Register name or number
-- @return Register name
-- @see getRegisterNumber
-- @local
    function private.getRegisterName(r)
        local n = naming.convertValueToName(r, regUnmap)
        if n == nil then
            error('rinLibrary: unknown register '..tostring(r))
        end
        return n
    end

-------------------------------------------------------------------------------
-- Register a deprecated register name and value.
-- @function registerDeprecated
-- @param registers List of register names
-- @local
    function private.registerDeprecated(registers)
        -- Have to rawset this to avoid hitting the set register capture
        -- function that is installed in the deprecated table.
        for _, reg in pairs(registers) do
            local n = naming.convertNameToValue(reg, regMap)
            if n ~= nil then
                rawset(deprecated, 'REG_' .. string.upper(reg), n)
            end
        end
    end

-------------------------------------------------------------------------------
-- Expose a function if the given condition isn't false.
-- If the condition is false, a stub routine is instead installed that
-- prints an error including the function name.
-- @function exposeFunction
-- @param n Name of the field to be exposed
-- @param b Boolean condition to check
-- @param f Function to call if the boolean isn't false
-- @return The function or a no-op stub
-- @local
    function private.exposeFunction(n, b, f)
        if b then
            mod[n] = f
            return f
        end
        mod[n] = function()
            dbg.error('K400:', 'call to invalid function '..n)
        end
        return function() end
    end

-------------------------------------------------------------------------------
-- Add a value to an index modulo a size
-- @function addModBase1
-- @param value Value to modify
-- @param inc Increment to add to value
-- @param size Maximum number to reture
-- @param wrap Should the increment wrap around the ends
-- @return Updated value
-- @local
    function private.addModBase1(value, inc, size, wrap)
        if wrap then
            value = value + inc % size
            if value > size then value = value - size end
        else
            value = math.min(size, math.max(1, value + inc))
        end
        return value
    end

-------------------------------------------------------------------------------
-- Return our argument
-- @param v Value to return
-- @return v
-- @local
    local function willy(v)
        return v
    end

-------------------------------------------------------------------------------
-- Return nil
-- @param v Value to not return
-- @return nil
-- @local
    local function nilly(v)
        return nil
    end

-------------------------------------------------------------------------------
-- Filter a value based on a specific device
-- @function k401 k402 k410 k491
-- @param v Value to return if we're the specified device
-- @return v or nil
-- @local
    for _, d in pairs{
        'k401', 'k402',
        'k410', 'k411', 'k412', 'k415',
        'k422', 'k491'
    } do
        private[d] = function(v)
			assert(private.deviceType ~= nil)
            private[d] =(private.deviceType == d) and willy or nilly
            return private[d](v)
        end
    end

-------------------------------------------------------------------------------
-- Look up our device type in the list and return the associated code
-- @function valueByDevice
-- @param l List of device, value pairs
-- @return associated value
-- @see batching
-- @see nonbatching
-- @local
-- @usage
-- local code = valueByDevice{ k401 = 3, k491 = 2, k410 = 'nil', default = 6 }
    function private.valueByDevice(l)
		assert(private.deviceType ~= nil)
        local r = l[private.deviceType] or l.default
        if r == 'nil' then return nil end
        return r
    end

-------------------------------------------------------------------------------
-- Filter a value based on a batching device
-- @function batching
-- @param v Value to return if batching
-- @return v or nil
-- @see nonbatching
-- @see valueByDevice
-- @local
    function private.batching(v)
		assert(private.deviceType ~= nil)
        private.batching = private.valueByDevice{
            k410 = willy,   k411 = willy,
            k412 = willy,   k415 = willy,
            default = nilly
        }
        return private.batching(v)
    end

-------------------------------------------------------------------------------
-- Filter a value based on a nonbatching device
-- @function nonbatching
-- @param v Value to return if non-batching
-- @return v or nil
-- @see batching
-- @see valueByDevice
-- @local
    function private.nonbatching(v)
		assert(private.deviceType ~= nil)
        private.nonbatching = private.valueByDevice{
            k410 = nilly,   k411 = nilly,
            k412 = nilly,   k415 = nilly,
            default = willy
        }
        return private.nonbatching(v)
    end

-------------------------------------------------------------------------------
-- Register a call back that is to be called after the device type has been
-- identified correctly.
-- @function registerDeviceInitialiser
-- @param f Function to call
-- @param ... Arguments to be passed to the function
-- @local
    function private.registerDeviceInitialiser(f, ...)
        utils.checkCallback(f)
        table.insert(deviceInitialisers, { func=f, args={...} })
    end

-------------------------------------------------------------------------------
-- Invoke the register device type dependent call backs
-- @function processDeviceInitialisers
-- @local
    function private.processDeviceInitialisers()
        local inits = deviceInitialisers
        deviceInitialisers = nil
        for _, v in ipairs(inits) do
            utils.call(v.func, unpack(v.args))
        end
    end

    if _TEST then
        mod.getPrivate = function() return private end
    end
end
