-------------------------------------------------------------------------------
-- Analog network test.
-- @author Darren
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
require "tests.assertions"

describe("Analog #analog", function ()
    local net = require "tests.network"
    local timers = require 'rinSystem.rinTimers'
    local app, upper, lower

    before_each(function()
        app, upper, lower = net.openDevices()
    end)

    after_each(function()
        net.closeDevices(app)

        app = nil
        upper = nil
        lower = nil
    end)

    it("check limits", function()
        --  Callback to capture changes to current weight
        local curWeight = 0
        upper.addStream('grossnet', function(d, e) curWeight = d end, 'change')

        -- Callback to monitor motion status
--        upper.setStatusCallback(upper.STAT_MOTION, function(status, active)
--            if active then
--                print('','motion')
--            else
--                print('stable',curWeight)
--            end
--        end)

        local function check(volts, target, fuzz)
            lower.setAnalogVolt(1, volts)
            app.delay(0.4)
            upper.waitStatus('notmotion')
            assert.approximately(curWeight, target, fuzz)
        end

        local count = 0
        app.setMainLoop(function()
            check(0, 0, 10)
            check(10, 10000, 15)

            count = count + 1
            if count >= 2 then
                rinApp.finish()
            end
        end)

        -- Finally, put a timer in place so we don't run forever
        timers.addTimer(0, 20, function() rinApp.finish() error("timed out") end)
        app.run()
        assert.is_true(count > 0)
    end)

    it("linearity", function()
        --  Callback to capture changes to current weight
        local curWeight = 0
        -- Change the following to 'grossnet' once the REG_ version is deprecated
        lower.addStream('grossnet', function(d, e) curWeight = d end, 'change')

        local data = require("tests.regression")()
        for i = 0, 5 do
            upper.setAnalogVolt(1, i * 2)
            app.delay(0.4)
            lower.waitStatus('notmotion')
            data.add(i, curWeight)
        end
        assert.roughly({1, 1}, data.r(), 1e-5)
    end)
end)
