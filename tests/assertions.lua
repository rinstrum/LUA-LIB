-------------------------------------------------------------------------------
-- Additional assertions.
-- These functions are NOT available inside the rinApp application framework.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local s = require "say"

-------------------------------------------------------------------------------
-- Assert two real values are approximately equal
-- @param state Internal assert state
-- @param args Arguments to the assert call
-- @local
local function approximately(state, args)
    assert(args.n >= 3, s("assertion.internal.argtolittle", { "approximately", 3, tostring(argcnt) }))
    local target = tonumber(args[1])
    local value = tonumber(args[2])
    local fuzz = math.abs(tonumber(args[3]))
    assert(target ~= nil, s("assertion.internal.badargtype", { "approximately", "number", type(args[1]) }))
    assert(value ~= nil, s("assertion.internal.badargtype", { "approximately", "number", type(args[2]) }))
    assert(fuzz ~= nil, s("assertion.internal.badargtype", { "approximately", "number", type(args[3]) }))

    return value >= (target - fuzz) and value <= (target + fuzz)
end

s:set("assertion.approximately.positive", "Expected numbers to be approximately equal.\nExpected:\n%s\nPassed in:\n%s\nTolerance:\n%s\n")
s:set("assertion.approximately.negative", "Expected numbers to be not approximately equal.\nExpected:\n%s\nPassed in:\n%s\nTolerance:\n%s\n")

assert:register("assertion", "approximately", approximately, "assertion.approximately.positive", "assertion.approximately.negative")

-------------------------------------------------------------------------------
-- Assert two arrays of real values are approximately equal
-- @param state Internal assert state
-- @param args Arguments to the assert call
-- @local
local function roughly(state, args)
    assert(args.n >= 3, s("assertion.internal.argtolittle", { "roughly", 3, tostring(argcnt) }))
    local fuzz = math.abs(tonumber(args[3]))
    assert(fuzz ~= nil, s("assertion.internal.badargtype", { "roughly", "number", type(args[3]) }))

    for i = 1, #args[1] do
        local target = tonumber(args[1][i])
        local value = tonumber(args[2][i])
        assert(target ~= nil, s("assertion.internal.badargtype", { "roughly", "number", type(args[1]) }))
        assert(value ~= nil, s("assertion.internal.badargtype", { "roughly", "number", type(args[2]) }))
        if value < (target - fuzz) or value > (target + fuzz) then
            return false
        end
    end
    return true
end

s:set("assertion.approximately.positive", "Expected numbers to be approximately equal.\nExpected:\n%s\nPassed in:\n%s\nTolerance:\n%s\n")
s:set("assertion.approximately.negative", "Expected numbers to be not approximately equal.\nExpected:\n%s\nPassed in:\n%s\nTolerance:\n%s\n")

assert:register("assertion", "roughly", roughly, "assertion.approximately.positive", "assertion.approximately.negative")

local function between(state, args)
    assert(args.n >= 3, s("assertion.internal.argtolittle", { "between", 3, tostring(argcnt) }))

    local value = args[1]
    local low, high = args[2], args[3]

    return value >= low and value <= high
end

s:set("assertion.between.positive", "Expected number to be in range.\nPassed in:\n%s\nShould be between:\n%s\nand\n%s\n")
s:set("assertion.between.negative", "Expected number to be not range.\nPassed in:\n%s\nShould be between:\n%s\nand\n%s\n")

assert:register("assertion", "between", between, "assertion.between.positive", "assertion.between.negative")
