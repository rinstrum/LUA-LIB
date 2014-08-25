-------------------------------------------------------------------------------
-- Buzzer network test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local silent = true

if not silent then
    describe("Beep #beep", function ()
        local net = require "tests.network"
        local timers = require 'rinSystem.rinTimers.Pack'
        local app, upper, lower

        before_each(function()
            app, upper, lower = net.openDevices()
        end)

        after_each(function()
            timers.addEvent(rinApp.finish)
            app.run()
            net.closeDevices(app)

            app = nil
            upper = nil
            lower = nil
        end)

        it("upper", function()
            upper.buzz(4, upper.BUZZ_SHORT)
        end)

        it("lower", function()
            lower.buzz(2, lower.BUZZ_MEDIUM)
        end)

        it("both", function()
            upper.buzz(3, upper.BUZZ_MEDIUM)
            lower.buzz(1, lower.BUZZ_LONG)
        end)
    end)
end
