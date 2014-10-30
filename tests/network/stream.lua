-------------------------------------------------------------------------------
-- Streaming network test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
require "tests.assertions"

describe("Streaming #stream", function ()
    local net = require "tests.network"
    local timers = require 'rinSystem.rinTimers'
    local app, upper, lower, death

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
-- Need to verify different stream timings.
    describe("timings", function()
        local s, count = nil, 0

        after_each(function()
            upper.removeStream(s)
            s = nil
            upper.setStreamFreq('onchange')
        end)

        local function increment(...) count = count + 1 end

        it("auto10", function()
            upper.setStreamFreq('auto10')
            s = upper.addStream('gross', increment, 'always')
            timers.addTimer(0, .1, function() count = 0 end)
            timers.addTimer(0, 1.1, function()
                assert.between(count, 8, 12)
            end)
            app.delay(1.2)
        end)

        it("auto3", function()
            upper.setStreamFreq('auto3')
            s = upper.addStream('gross', increment, 'always')
            timers.addTimer(0, .1, function() count = 0 end)
            timers.addTimer(0, 2.1, function()
                assert.between(count, 4, 8)
            end)
            app.delay(2.2)
        end)

        it("auto1", function()
            upper.setStreamFreq('auto1')
            s = upper.addStream('gross', increment, 'always')
            timers.addTimer(0, .1, function() count = 0 end)
            timers.addTimer(0, 3.1, function()
                assert.between(count, 2, 4)
            end)
            app.delay(3.2)
        end)

        it("auto25", function()
            upper.setStreamFreq('auto')
            s = upper.addStream('gross', increment, 'always')
            timers.addTimer(0, .1, function() count = 0 end)
            timers.addTimer(0, 1.1, function()
                assert.between(count, 19, 26)
            end)
            app.delay(1.2)
        end)
    end)
end)
