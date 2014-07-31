-------------------------------------------------------------------------------
-- Register unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local regs = require "tests.registers"

describe("K400Reg #register", function()
    local registers = {
        absmvv                  = 0x0023,
        active_product_name     = 0xB006,
        active_product_no       = 0xB000,
        adcsample               = 0x0020,
        altgross                = 0x002C,
        altnet                  = 0x002E,
        clr_all_totals          = 0xB002,
        clr_docket_totals       = 0xB004,
        fullscale               = 0x002F,
        grandtotal              = 0x002B,
        gross                   = 0x0026,
        grossnet                = 0x0025,
        keybuffer               = 0x0008,
        lcd                     = 0x0009,
        manhold                 = 0x002A,
        net                     = 0x0027,
        peakhold                = 0x0029,
        rawadc                  = 0x002D,
        select_product_delete   = 0xB011,
        select_product_name     = 0xB010,
        select_product_no       = 0xB00F,
        select_product_rename   = 0xB012,
        syserr                  = 0x0022,
        sysstatus               = 0x0021,
        tare                    = 0x0028
    }

    -- Newer registers that don't get the deprecated REG_xxx interface
    local extraRegisters = {
        piececount              = 0x0053
    }

    local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.K400Reg")(m, p, d)

        regs.populate(p.regPopulate, m, p, d)

        return m, p, d
    end

    it("getRegisterNumber", function()
        local m, p = makeModule()
        assert.equal(registers.keybuffer, p.getRegisterNumber('KeyBuffer'))
        assert.equal(registers.manhold, p.getRegisterNumber(registers.manhold))
    end)

    it("getRegisterName", function()
        local m, p, d = makeModule()
        assert.equal('grandtotal', p.getRegisterName('GrandTotal'))
        assert.equal('adcsample', p.getRegisterName(0x20))
    end)

    describe("deprecated", function()
        local _, _, d = makeModule()
        for k, v in pairs(registers) do
            it("register"..k, function()
                assert.equal(v, d['REG_'..string.upper(k)])
            end)
        end
    end)

    describe("registers", function()
        local m, p = makeModule()
        for r, v in pairs(registers) do
            it('test '..r, function()
                assert.equal(v, p.getRegisterNumber(r))
                assert.equal(r, p.getRegisterName(v))
            end)
        end
    end)

    describe("extra registers", function()
        local m, p = makeModule()
        for r, v in pairs(extraRegisters) do
            it('test '..r, function()
                assert.equal(v, p.getRegisterNumber(r))
                assert.equal(r, p.getRegisterName(v))
            end)
        end
    end)

    it("literalToFloat", function()
        local m, p = makeModule()
        local tests = {
            {   d = '1234',     r = 1234    },
            {   d = '- 123.4',  r = -123.4  },
            {   d = '+ 543.21', r = 543.21  },
            {   d = '0',        r = 0       },
            {   d = '.1',       r = .1      },
        }
        for i = 1, #tests do
            it("test "..i, function()
                local t = tests[i]
                assert.approximately(t.r, p.literalToFloat(t.d), t.r * 1e-14)
            end)
        end
    end)

    describe("toFloat", function()
        local m, p = makeModule()
        m.getDispModeDP = function(x) return 3 end
        local tests = {
            {   d = '1234',     r = 4.66                     },
            {   d = 'ff001234', r = -16772.556               },
            {   d = 'ffffffff', r = -.0001,         dp = 4   },
            {   d = '80000000', r = -21474836.48,   dp = 2   },
            {   d = '7fffffff', r = 214748364.7,    dp = 1   },
            {   d = '0',        r = 0,              dp = 0   },
            {   d = '1',        r = 1,              dp = 0   },
            {   d = '100',      r = 2560,           dp = -1  }
        }
        for i = 1, #tests do
            it("test "..i, function()
                local t = tests[i]
                assert.approximately(t.r, p.toFloat(t.d, t.dp), t.r * 1e-12)
            end)
        end
    end)
end)
