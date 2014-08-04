-------------------------------------------------------------------------------
-- LCD unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("LCD #lcd", function ()
    local dregs = {
        lcdmode                 = 0x000D,
        disp_bottom_left        = 0x000E,
        disp_bottom_right       = 0x000F,
        disp_top_left           = 0x00B0,
        disp_top_right          = 0x00B1,
        disp_top_annun          = 0x00B2,
        disp_top_units          = 0x00B3,
        disp_bottom_annun       = 0x00B4,
        disp_bottom_units       = 0x00B5,
        disp_auto_top_annun     = 0x00B6,
        disp_auto_top_left      = 0x00B7,
        disp_auto_bottom_left   = 0x00B8,
    }

    local function makeModule()
        local m, p, d = {}, {}, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.K400LCD")(m, p, d)
        m.flushed = 0
        m.flush = function() m.flushed = m.flushed + 1 end
        return m, p, d
    end

    describe("deprecated registers", function()
        local _, _, d = makeModule()
            for k, v in pairs(dregs) do
            it("test "..k, function()
                assert.equal(v, d["REG_" .. string.upper(k)])
            end)
        end
    end)

    describe("strLen", function()
        local m = makeModule()
        local tc = {
            { r= 1, s="."                   },
            { r= 1, s="a"                   },
            { r= 0, s=""                    },
            { r= 2, s=".a."                 },
            { r= 3, s=".a.."                },
            { r= 3, s="..a."                },
            { r= 2, s=".."                  },
            { r= 3, s="..."                 },
            { r= 7, s="tuvwxyz"             },
            { r=10, s=".........."          },
            { r= 9, s="a.b.c.d.e.f.g.h.i."  },
            { r= 7, s=".a.b.c.d.e.f."       }
        }
        for i = 1, #tc do
            it("test"..i, function()
                assert.equal(tc[i].r, m.strLenR400(tc[i].s))
            end)
        end
    end)

    describe("strSub", function()
        pending("unimplemented test case")
    end)

    describe("padDots", function()
        local m = makeModule()
        local tc = {
            { r=" .",                   s="."                   },
            { r="a",                    s="a"                   },
            { r="",                     s=""                    },
            { r=" .a.",                 s=".a."                 },
            { r=" .a. .",               s=".a.."                },
            { r=" . .a.",               s="..a."                },
            { r=" . .",                 s=".."                  },
            { r=" . . .",               s="..."                 },
            { r="abcdefg",              s="abcdefg"             },
            { r=" . . . . . . . . . .", s=".........."          },
            { r="a.b.c.d.e.f.g.h.i.",   s="a.b.c.d.e.f.g.h.i."  },
            { r=" .a.b.c.d.e.f.",       s=".a.b.c.d.e.f."       }
        }
        for i = 1, #tc do
            it("test"..i, function()
                assert.equal(tc[i].r, m.padDots(tc[i].s))
            end)
        end
    end)

    describe("splitWords", function()
        pending("unimplemented test case")
    end)
end)

