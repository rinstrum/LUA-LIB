-------------------------------------------------------------------------------
-- Timer network test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("Timer #timer", function ()
    local net = require "tests.network"
    local timers = require 'rinSystem.rinTimers.Pack'
    local app, upper, lower

    setup(function()
        app, upper, lower = net.openDevices()

        setloop({
            pcall = pcall,
            create_timer =  function(sec, on_timeout)
                                timers.addTimer(0, sec, on_timeout)
                            end,
            step =          function()
                                if app.isRunning() then
                                    app.step()
                                end
                            end
        })
    end)

    teardown(function()
        timers.addEvent(app.finish)
        app.run()
        net.closeDevices(app)
    end)

    it("timer", function(done)
        timers.addTimer(0, .1, async(function() done() end))
    end)

    it("event", function(done)
        timers.addEvent(async(function() done() end))
    end)
end)
