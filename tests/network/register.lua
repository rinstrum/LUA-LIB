-------------------------------------------------------------------------------
-- Register network test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local regs = require "tests.registers"

describe("K400Reg #register", function()
    local net = require "tests.network"
    local timers = require 'rinSystem.rinTimers.Pack'
    local app, upper, lower, death, lowerPrivate, upperPrivate

    setup(function()
        app, upper, lower = net.openDevices()
        lowerPrivate, upperPrivate = lower.getPrivate(), upper.getPrivate()
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

    describe("read and write numeric", function()
        local reg = 'usernum1'

        local function check(a, b)
            upper.writeReg(reg, a)
            lower.writeReg(reg, b)
            lower.delay(0.2)

            local r, err = upperPrivate.readReg(reg)
            assert.is_nil(err)
            assert.equal(a, r)

            r, err = lower.readReg(reg)
            assert.is_nil(err)
            assert.equal(b, r)
        end

        it("firsts", function()     check(3, 2)     end)
        it("seconds", function()    check(11, 13)   end)
        it("thirds", function()     check(5, 7)     end)
    end)

    describe("read and write string", function()
        local reg = 'userid1'

        local function check(a, b)
            upper.writeReg(reg, a)
            lower.writeReg(reg, b)
            upper.delay(0.2)

            local d, e = upper.sendRegWait('rdlit', reg)
            assert.is_nil(e)
            assert.equal(a, d)

            d, e = lowerPrivate.readRegLiteral(reg)
            assert.is_nil(e)
            assert.equal(b, d)
        end

        it("initials", function()   check('hello', 'fnord') end)
        it("middles", function()    check('fake', 'bogus')  end)
        it("finals", function()     check('bye', '')        end)
    end)

    describe("execute", function()
        local xreg = 'select_product_rename'
        local rreg = 'select_product_name'

        local function check(a, b)
            upper.exReg(xreg, a)
            lower.exReg(xreg, b)
            upper.delay(0.2)

            local d, e = upper.readReg(rreg)
            assert.is_nil(e)
            assert.equal(1, d)

            d, e = lower.readReg(rreg)
            assert.is_nil(e)
            assert.equal(1, d)
        end

        it("product", function()    check('aprod', 'proda')     end)
        it("wedge", function()      check('widget', 'boxen')    end)
    end)
end)
