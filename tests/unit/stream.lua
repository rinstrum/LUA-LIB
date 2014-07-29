-------------------------------------------------------------------------------
-- Streaming unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("Streaming #stream", function ()
    local start, stop = 1, 0
    local manual, auto, auto10, auto3, auto1, onchange = 0, 1, 2, 3, 4, 5

    local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.rinCon")(m, p, d)
        require("rinLibrary.K400Reg")(m, p, d)
        require("rinLibrary.K400Stream")(m, p, d)
        return m, p, d
    end

    describe("deprecated registers", function()
        local _, _, d = makeModule()
        for k, v in pairs({
            streamdata      = 0x0040,
            streammode      = 0x0041,
            streamreg1      = 0x0042,
            streamreg2      = 0x0043,
            streamreg3      = 0x0044,
            streamreg4      = 0x0045,
            streamreg5      = 0x0046,
            lualib          = 0x0300,
            luauser         = 0x0310
        }) do
            it("test "..k, function()
                assert.equal(v, d["REG_" .. string.upper(k)])
            end)
        end
    end)

    it("enumerations", function()
        local _, _, d = makeModule()
        for k, v in pairs({
            start           = start,
            stop            = stop,
            freq_manual     = manual,
            freq_auto       = auto,
            freq_auto10     = auto10,
            freq_auto3      = auto3,
            freq_auto1      = auto1,
            freq_onchange   = onchange
        }) do
            it("test "..k, function()
                assert.equal(v, d['STM_' .. string.upper(k)])
            end)
        end
    end)

    describe("set", function()
        local m = makeModule()
        local z = require "tests.messages"
        for _, t in pairs({
            { s='auto1', r='gross', c={
                { r=0x026,  f='getRegDecimalPlaces'         },
                { r=0x026,  f='getRegType'                  },
                { r=0x351,  f='writeRegHexAsync',   auto1   },
                { r=0x352,  f='writeRegAsync',      0x0026  },
                { r=0x350,  f='exRegAsync',         start   }
            }},
            { s='onchange', r='grossnet', c={
                { r=0x025,  f='getRegDecimalPlaces'         },
                { r=0x025,  f='getRegType'                  },
                { r=0x351,  f='writeRegHexAsync',   onchange},
                { r=0x353,  f='writeRegAsync',      0x0025  },
                { r=0x350,  f='exRegAsync',         start   }
            }},
            { s='auto', r='gross', c={
                { r=0x026,  f='getRegDecimalPlaces'         },
                { r=0x026,  f='getRegType'                  },
                { r=0x351,  f='writeRegHexAsync',   auto    },
                { r=0x354,  f='writeRegAsync',      0x0026  },
                { r=0x350,  f='exRegAsync',         start   }
            }},
            { s='auto10', r='net', c={
                { r=0x027,  f='getRegDecimalPlaces'         },
                { r=0x027,  f='getRegType'                  },
                { r=0x351,  f='writeRegHexAsync',   auto10  },
                { r=0x355,  f='writeRegAsync',      0x0027  },
                { r=0x350,  f='exRegAsync',         start   }
            }},
            { s='auto3', r='grossnet', c={
                { r=0x025,  f='getRegDecimalPlaces'         },
                { r=0x025,  f='getRegType'                  },
                { r=0x351,  f='writeRegHexAsync',   auto3   },
                { r=0x356,  f='writeRegAsync',      0x0025  },
                { r=0x350,  f='exRegAsync',         start   }
            }},
        }) do
            z.checkNoReg(m, m.setStreamFreq, t.s)
            z.checkReg(m, t.c, m.addStream, t.r, function() end, 'always')
        end
    end)

    it("clear", function()
        local m, p = makeModule()
        local z = require "tests.messages"
        local saved = z.saveRegFunctions(m)
        p.writeRegAsync = spy.new(function() end)

        -- set speed
        z.checkNoReg(m, m.setStreamFreq, 'auto')

        -- set first stream
        local d1 = m.addStream('net', function() end, 'always')
        assert.spy(p.writeRegAsync).was.called_with(0x352, 0x27)

        -- set second stream
        local d2 = m.addStream('tare', function() end, 'always')
        assert.spy(p.writeRegAsync).was.called_with(0x353, 0x28)

        -- remove first stream
        z.checkReg(m, {{ r=0x352, f='writeReg', 0 }}, m.removeStream, d1)

        -- set first stream again, should reuse the stream register
        d1 = m.addStream('grossnet', function() end, 'always')
        assert.spy(p.writeRegAsync).was.called_with(0x352, 0x25)

        -- rmove both steams
        z.checkReg(m, { { r=0x353, f='writeReg', 0 } }, m.removeStream, d2)
        z.checkReg(m, { { r=0x352, f='writeReg', 0 },
                        { r=0x350, f='exReg', 0    } }, m.removeStream, d1)

        -- clean up and finish
        z.restoreRegFunctions(saved)
    end)
end)
