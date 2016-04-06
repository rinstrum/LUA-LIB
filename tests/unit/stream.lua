-------------------------------------------------------------------------------
-- Streaming unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("Streaming #stream", function ()
    local start, stop = 1, 0
    local manual, auto, auto10, auto3, auto1, onchange = 0, 1, 2, 3, 4, 5

    local function makeModule()
        local m, p, d = {}, { deviceType='' }, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.rinCon")(m, p, d)
        require("rinLibrary.K400Reg")(m, p, d)
        require("rinLibrary.K400Stream")(m, p, d)
        require("rinLibrary.K400Setpoint")(m, p, d)
        p.processDeviceInitialisers()
        return m, p, d
    end

    it("enumerations", function()
        local _, _, d = makeModule()
        for k, v in pairs{
            start           = start,
            stop            = stop,
            freq_manual     = manual,
            freq_auto       = auto,
            freq_auto10     = auto10,
            freq_auto3      = auto3,
            freq_auto1      = auto1,
            freq_onchange   = onchange
        } do
            it("test "..k, function()
                assert.equal(v, d['STM_' .. string.upper(k)])
            end)
        end
    end)

    describe("set", function()
        local m = makeModule()
        local z = require "tests.messages"
        for _, t in pairs{
            { s='auto1', r='gross', c={
                { r=0x026,  f='getRegDecimalPlaces'         },
                { r=0x026,  f='getRegType'                  },
                { r=0x341,  f='writeRegHexAsync',   auto1   },
                { r=0x342,  f='writeRegAsync',      0x0026  },
                { r=0x340,  f='exRegAsync',         start   }
            }},
            { s='onchange', r='grossnet', c={
                { r=0x025,  f='getRegDecimalPlaces'         },
                { r=0x025,  f='getRegType'                  },
                { r=0x341,  f='writeRegHexAsync',   onchange},
                { r=0x343,  f='writeRegAsync',      0x0025  },
                { r=0x340,  f='exRegAsync',         start   }
            }},
            { s='auto', r='tare', c={
                { r=0x028,  f='getRegDecimalPlaces'         },
                { r=0x028,  f='getRegType'                  },
                { r=0x341,  f='writeRegHexAsync',   auto    },
                { r=0x344,  f='writeRegAsync',      0x0028  },
                { r=0x340,  f='exRegAsync',         start   }
            }},
            { s='auto10', r='net', c={
                { r=0x027,  f='getRegDecimalPlaces'         },
                { r=0x027,  f='getRegType'                  },
                { r=0x341,  f='writeRegHexAsync',   auto10  },
                { r=0x345,  f='writeRegAsync',      0x0027  },
                { r=0x340,  f='exRegAsync',         start   }
            }},
            { s='auto3', r='fullscale', c={
                { r=0x02F,  f='getRegDecimalPlaces'         },
                { r=0x02F,  f='getRegType'                  },
                { r=0x341,  f='writeRegHexAsync',   auto3   },
                { r=0x346,  f='writeRegAsync',      0x002F  },
                { r=0x340,  f='exRegAsync',         start   }
            }},
        } do
            it(t.s, function()
                z.checkNoReg(m, m.setStreamFreq, t.s)
                z.checkReg(m, t.c, m.addStream, t.r, function() end, 'always')
            end)
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
        assert.spy(p.writeRegAsync).was.called_with(0x342, 0x27)

        -- set second stream
        local d2 = m.addStream('tare', function() end, 'always')
        assert.spy(p.writeRegAsync).was.called_with(0x343, 0x28)

        -- remove first stream
        z.checkReg(m, {{ r=0x342, f='writeReg', 0 }}, m.removeStream, d1)

        -- set first stream again, should reuse the stream register
        d1 = m.addStream('grossnet', function() end, 'always')
        assert.spy(p.writeRegAsync).was.called_with(0x342, 0x25)

        -- rmove both steams
        z.checkReg(m, { { r=0x343, f='writeReg', 0 } }, m.removeStream, d2)
        z.checkReg(m, { { r=0x342, f='writeReg', 0 },
                        { r=0x340, f='exReg', 0    } }, m.removeStream, d1)

        -- clean up and finish
        z.restoreRegFunctions(saved)
    end)

    describe("many streams", function()
        local m = makeModule()
        local z = require "tests.messages"
        m.setStreamFreq('onchange')
    
        for _, t in pairs{
            { r='adcsample',    reg=0x342,  arg=0x0020  },
            { r='sysstatus',    reg=0x343,  arg=0x0021  },
            { r='syserr',       reg=0x344,  arg=0x0022  },
            { r='absmvv',       reg=0x345,  arg=0x0023  },
            { r='grossnet',     reg=0x346,  arg=0x0025  },
            { r='gross',        reg=0x352,  arg=0x0026  },
            { r='net',          reg=0x353,  arg=0x0027  },
            { r='tare',         reg=0x354,  arg=0x0028  },
            { r='peakhold',     reg=0x355,  arg=0x0029  },
            { r='manhold',      reg=0x356,  arg=0x002A  },
            { r='grandtotal',   reg=0x042,  arg=12      },
            { r='altgross',     reg=0x043,  arg=13      },
            { r='fullscale',    reg=0x044,  arg=15      },
            { r='io_status',    reg=0x045,  arg=16      },
            { r='altnet',       reg=0x046,  arg=14      }
        } do
            it(t.r, function()
                local c = {{ r = t.reg, f = 'writeRegAsync', t.arg }}
                z.checkReg(m, c, m.addStream, t.r, function() end, 'always')
            end)
        end
    end)

end)
