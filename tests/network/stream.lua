-------------------------------------------------------------------------------
-- Streaming network test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
require "tests.assertions"

describe("Streaming #stream", function ()
    local net = require "tests.network"
    local timers = require 'rinSystem.rinTimers.Pack'
    local app, upper, lower

    setup(function()
        app, upper, lower = net.openDevices()
    end)

    teardown(function()
        net.closeDevices(app)
    end)

    before_each(function()
        death = timers.addTimer(0, 25, function() assert.equal("timed out", nil) end)
    end)

    after_each(function()
        timers.removeTimer(death)
        death = nil
    end)

    it("dummy", function()
    end)
end)
