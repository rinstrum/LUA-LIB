-------------------------------------------------------------------------------
-- Additional assertions.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local s = require "say"

-- Assert two real values are approximately equal
local function approximately(state, args)
    assert(args.n >= 3, s("assertion.internal.argtolittle", { "approximately", 3, tostring(argcnt) }))
    local target = tonumber(args[1])
    local value = tonumber(args[2])
    local fuzz = tonumber(args[3])
    assert(target ~= nil, s("assertion.internal.badargtype", { "approximately", "number", type(args[1]) }))
    assert(value ~= nil, s("assertion.internal.badargtype", { "approximately", "number", type(args[2]) }))
    assert(fuzz ~= nil, s("assertion.internal.badargtype", { "approximately", "number", type(args[3]) }))

    return value >= (target - fuzz) and value <= (target + fuzz)
end

s:set("assertion.approximately.positive", "Expected numbers to be approximately equal.\nExpected:\n%s\nPassed in:\n%s\nTolerance:\n%s\n")
s:set("assertion.approximately.negative", "Expected numbers to be not approximately equal.\nExpected:\n%s\nPassed in:\n%s\nTolerance:\n%s\n")

assert:register("assertion", "approximately", approximately, "assertion.approximately.positive", "assertion.approximately.negative")
