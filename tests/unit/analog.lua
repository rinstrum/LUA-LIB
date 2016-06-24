-------------------------------------------------------------------------------
-- Buzzer unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("analog #analog", function ()
    local numAnalog
    local regData   = { 0x0323, 0x030B, 0x030C, 0x030D }
    local regType   = { 0xA801, 0xA811, 0xA821, 0xA831 }
    local regClip   = { 0xA806, 0xA816, 0xA826, 0xA836 }
    --local regSource = { 0xA805, 0xA815, 0xA825, 0xA835 }
    local volt, current, comms = 1, 0, 3

    local function makeModule(device)
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.GenericAnalog")(m, p, d)
        p.deviceType = device or 'a418'
        p.processDeviceInitialisers()
        numAnalog = m.getAnalogModuleMaximum()
        return m, p, d
    end

    it("enumerations", function()
        local _, _, d = makeModule()
        assert.equal(current,   d.CUR)
        assert.equal(volt,      d.VOLT)
        assert.equal(comms,     d.ANALOG_COMMS)
    end)

    describe("getAnalogModuleMaximum", function()
        for d, n in pairs{
            k401 = 1,
            k402 = 1,
            k410 = 1,
            k422 = 1,
            k491 = 1,
            a418 = 4
        } do
            it(d, function()
                assert.equal(n, makeModule(d).getAnalogModuleMaximum())
            end)
        end
    end)

    -- These tests are digging deep into the non-exposed internals
    describe("type", function()
        local m, p = makeModule()
        local z = require "tests.messages"
        local cases = {
            { type = volt,      ex = volt       },
            { type = current,   ex = current    },
            { type = 'volt',    ex = volt       },
            { type = 'current', ex = current    },
            { type = 'unknown', ex = volt       }
        }

        for n = 1, numAnalog do
            for i, v in pairs(cases) do
                it("test A"..n.." "..i, function()
                    z.checkWriteReg(m, {{ r=regType[n], v.ex }}, m.setAnalogType, n, v.type)
                end)
            end
        end
    end)

    describe("clip", function()
        local m, p = makeModule()
        local z = require "tests.messages"
        local cases = {
            { clip = true,  ex = 1  },
            { clip = false, ex = 0  },
            { clip = 0,     ex = 0  },
            { clip = 1,     ex = 1  }
        }

        for n = 1, numAnalog do
            for i, v in pairs(cases) do
                it("test A"..n.." "..i, function()
                    z.checkWriteRegAsync(m, {{ r=regClip[n], v.ex }}, m.setAnalogClip, n, v.clip)
                end)
            end
        end
    end)

    describe("raw", function()
        local m, p = makeModule()
        local z = require "tests.messages"
        local cases = {
            { raw = 0,      ex = 0      },
            { raw = 50000,  ex = 50000  },
            { raw = 10000,  ex = 10000  }
        }

        for n = 1, numAnalog do
            for i, v in pairs(cases) do
                it("test A"..n.." "..i, function()
                    z.checkWriteRegAsync(m, {{ r=regData[n], v.ex }}, m.setAnalogRaw, n, v.raw)
                end)
            end
        end
    end)

--    it("val", function()
--        local m, p = makeModule()
--        local cases = {
--            { val = 0,          ex = 0      },
--            { val = 1,          ex = 50000  },
--            { val = 0.5,        ex = 25000  },
--            { val = 0.777799,   ex = 38890  }
--        }
--        for i, v in pairs(cases) do
--            it("test "..i, function()
--                stub(m, 'setAnalogRaw')
--                m.setAnalogVal(1, v.val)
--                assert.stub(m.setAnalogRaw).was.called_with(1, v.ex)
--                m.setAnalogRaw:revert()
--            end)
--        end
--    end)

--    it("percent", function()
--        local m, p = makeModule()
--        local cases = {
--            { val = 0,          ex = 0      },
--            { val = 100,        ex = 50000  },
--            { val = 50,         ex = 25000  },
--            { val = 77.7799,    ex = 38890  }
--        }
--        for i, v in pairs(cases) do
--            it("test "..i, function()
--                stub(m, 'setAnalogRaw')
--                m.setAnalogPC(v.val)
--                assert.stub(m.setAnalogRaw).was.called_with(1, v.ex)
--                m.setAnalogRaw:revert()
--            end)
--        end
--    end)

--    it("current", function()
--        local m, p = makeModule()
--        local cases = {
--            { val = 4,          ex = 0      },
--            { val = 20,         ex = 50000  },
--            { val = 12,         ex = 25000  },
--            { val = 13,         ex = 28125  }
--        }
--        for i, v in pairs(cases) do
--            it("test "..i, function()
--                stub(m, 'setAnalogRaw')
--                stub(m, 'setAnalogType')
--
--                m.setAnalogCur(v.val)
--                assert.stub(m.setAnalogRaw).was.called_with(1, v.ex)
--                assert.stub(m.setAnalogType).was.called_with(1, current)
--
--                m.setAnalogRaw:revert()
--                m.setAnalogType:revert()
--            end)
--        end
--    end)

--    it("volt", function()
--        local m, p = makeModule()
--        local cases = {
--            { val = 0,          ex = 0      },
--            { val = 10,         ex = 50000  },
--            { val = 1.2345678,  ex = 6173   }
--        }
--        for i, v in pairs(cases) do
--            it("test "..i, function()
--                stub(m, 'setAnalogRaw')
--                stub(m, 'setAnalogType')
--
--                m.setAnalogVolt(v.val)
--                assert.stub(m.setAnalogRaw).was.called_with(v.ex)
--                assert.stub(m.setAnalogType).was.called_with(volt)
--
--                m.setAnalogRaw:revert()
--                m.setAnalogType:revert()
--            end)
--        end
--    end)
end)
