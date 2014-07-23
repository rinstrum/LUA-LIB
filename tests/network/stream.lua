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

-- Need to verify streaming works.
-- Need to verify streaming multiple registers.
-- Need to verify differnt stream timings.
    describe("timings", function()
        local s, count

        --after_each(function() upper.removeStream(s) s = nil print("after 2") end)
        before_each(function() count = 0 end)

        after_each(function()
            upper.removeStream(s)
            s = nil
        end)

        local function increment() count = count + 1 end

        it("auto10", function()
            s = upper.addStream('gross', increment, 'auto10')
            timers.addTimer(0, .1, function() count = 0 end)
            timers.addTimer(0, 1.1, function()
                assert.between(count, 8, 12)
            end)
            upper.delay(1.2)
        end)

        it("auto3", function()
            s = upper.addStream('gross', increment, 'auto3')
            timers.addTimer(0, .1, function() count = 0 end)
            timers.addTimer(0, 2.1, function()
                assert.between(count, 4, 8)
            end)
            upper.delay(2.2)
        end)

        it('auto1', function()
            s = upper.addStream('gross', increment, 'auto1')
            timers.addTimer(0, .1, function() count = 0 end)
            timers.addTimer(0, 5.1, function()
                assert.between(count, 4, 6)
            end)
            upper.delay(5.2)
        end)
    end)
end)
