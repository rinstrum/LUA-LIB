-------------------------------------------------------------------------------
-- Digital IO network test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("Digital #digital", function ()
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
        death = timers.addTimer(0, 5, function() assert.equal("timed out", nil) end)
    end)

    after_each(function()
        timers.removeTimer(death)
        death = nil
    end)

    it("all", function()
        local cb = spy.new(function() end)

        finally(function()
            upper.turnOff(1, 2, 3, 4, 5, 6)
            upper.releaseOutput(1, 2, 3, 4, 5, 6)
            lower.setAllIOCallback(nil)
        end)

        upper.enableOutput(1, 2, 3, 4, 5, 6)
        upper.turnOff(1, 2, 3, 4, 5, 6)

        app.delay(.1)       lower.setAllIOCallback(cb)
        app.delay(.15)      upper.turnOn(4)
                            upper.turnOn(2)
        app.delay(.3)       assert.spy(cb).was.called_with(10)
                            upper.turnOn(3)

        app.delay(.3)       assert.spy(cb).was.called_with(14)
    end)

    it("toggle", function()
        local cb = spy.new(function() end)
        local cb3 = spy.new(function() end)
        local cb4 = spy.new(function() end)

        finally(function()
            upper.turnOff(3, 4)
            upper.releaseOutput(3, 4)
            lower.setAllIOCallback(nil)
            lower.setIOCallback(3, nil)
            lower.setIOCallback(4, nil)
        end)

        lower.releaseOutput(3, 4)
        upper.enableOutput(3, 4)
        upper.turnOff(3, 4)

        app.delay(.3)       lower.setAllIOCallback(cb)
                            lower.setIOCallback(3, cb3)
                            lower.setIOCallback(4, cb4)

        app.delay(.3)       upper.turnOn(4)
        app.delay(.3)       assert.spy(cb4).was.called_with(4, true)
                            upper.turnOn(3)
        app.delay(.3)       assert.spy(cb3).was.called_with(3, true)
                            upper.turnOff(4)

        app.delay(.3)       assert.spy(cb4).was.called_with(4, false)

        assert.spy(cb).was.called_with(8)
        assert.spy(cb).was.called_with(12)
        assert.spy(cb).was.called_with(4)
    end)

    it("timed", function()
        local cb = spy.new(function() end)

        finally(function()
            upper.turnOff(8)
            upper.releaseOutput(8)
            lower.setIOCallback(8, nil)
        end)

        lower.releaseOutput(8)
        upper.enableOutput(8)
        upper.turnOff(8)

        app.delay(.3)       lower.setIOCallback(8, cb)
        app.delay(.3)       upper.turnOnTimed(8, 0.3)

        app.delay(.5)
        assert.spy(cb).was.called_with(8, true)
        assert.spy(cb).was.called_with(8, false)
    end)

    it("reverse", function()
        local cb = spy.new(function() end)

        finally(function()
            lower.turnOff(1)
            lower.releaseOutput(1)
            upper.setIOCallback(1, nil)
        end)

        lower.enableOutput(1)
        lower.turnOff(1)

        app.delay(.3)       upper.setIOCallback(1, cb)
        app.delay(.3)       lower.turnOn(1)
        app.delay(.3)       lower.turnOff(1)

        app.delay(.5)
        assert.spy(cb).was.called_with(1, true)
        assert.spy(cb).was.called_with(1, false)
    end)
end)
