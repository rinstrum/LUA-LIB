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

    describe("deprecated enumerations", function()
        local _, _, d = makeModule()
        for k, v in pairs{
            battery           = 0x0001,
            clock             = 0x0002,
            bat_lo            = 0x0004,
            bat_midl          = 0x0008,
            bat_midh          = 0x0010,
            bat_hi            = 0x0020,
            bat_full          = 0x003D,
            wait              = 0x0040,
            wait45            = 0x0100,
            wait90            = 0x0200,
            wait135           = 0x0080,
            waitall           = 0x03C0,
            sigma             = 0x00001,
            balance           = 0x00002,
            coz               = 0x00004,
            hold              = 0x00008,
            motion            = 0x00010,
            net               = 0x00020,
            range             = 0x00040,
            zero              = 0x00080,
            bal_sega          = 0x00100,
            bal_segb          = 0x00200,
            bal_segc          = 0x00400,
            bal_segd          = 0x00800,
            bal_sege          = 0x01000,
            bal_segf          = 0x02000,
            bal_segg          = 0x04000,
            range_segadg      = 0x08000,
            range_segc        = 0x10000,
            range_sege        = 0x20000,
            units_none        = 0,
            units_kg          = 0x01,
            units_lb          = 0x02,
            units_t           = 0x03,
            units_g           = 0x04,
            units_oz          = 0x05,
            units_n           = 0x06,
            units_arrow_l     = 0x07,
            units_p           = 0x08,
            units_l           = 0x09,
            units_arrow_h     = 0x0A,
            units_other_per_h = 0x14,
            units_other_per_m = 0x11,
            units_other_per_s = 0x12,
            units_other_pc    = 0x30,
            units_other_tot   = 0x08
        } do
            it("test "..k, function()
                assert.equal(v, d[string.upper(k)])
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
            it("test "..i, function()
                assert.equal(tc[i].r, m.strLenR400(tc[i].s))
            end)
        end
    end)

    describe("strSub", function()
        local m = makeModule()
        local tc = {
            { a={'.', 1, 1 },                   r='.'               },
            { a={'a', 1, 1 },                   r='a'               },
            { a={'', 1, 1 },                    r=''                },
            { a={'.a.', 1, 1 },                 r='.'               },
            { a={'.a.', 2, 2 },                 r='a.'              },
            { a={'a.b.c.d.e.f.g.h.i.', 2, 2 },  r='b.'              },
            { a={'a.b.c.d.e.f.g.h.i.', 2, 6 },  r='b.c.d.e.f.'      },
            { a={'..........', 2, 6 },          r='.....'           },
            { a={'abcdefg', 4, 5 },             r='de'              },
            { a={'.a.', 1, 5 },                 r='.a.'             },
            { a={'.a..', 1, 5 },                r='.a..'            },
            { a={'..a.', 1, 5 },                r='..a.'            },
            { a={'.', 4, 5 },                   r=''                },
            { a={'a', 4, 5 },                   r=''                },
            { a={'', 4, 5 },                    r=''                },
            { a={"a.b.c.d.e.f.g.h.i.", 4, 9 },  r="d.e.f.g.h.i."    },
            { a={"a.b.c.d.e.f.g.h.i.", 5 },     r="e.f.g.h.i."      }
        }
        for i = 1, #tc do
            it("test "..i, function()
                assert.equal(tc[i].r, m.strSubR400(unpack(tc[i].a)))
            end)
        end
    end)

    describe("padDots", function()
        local m = makeModule()
        local tc = {
            { r=' .',                   s='.'                   },
            { r='a',                    s='a'                   },
            { r='',                     s=''                    },
            { r=' .a.',                 s='.a.'                 },
            { r=' .a. .',               s='.a..'                },
            { r=' . .a.',               s='..a.'                },
            { r=' . .',                 s='..'                  },
            { r=' . . .',               s='...'                 },
            { r='abcdefg',              s='abcdefg'             },
            { r=' . . . . . . . . . .', s='..........'          },
            { r='a.b.c.d.e.f.g.h.i.',   s='a.b.c.d.e.f.g.h.i.'  },
            { r=' .a.b.c.d.e.f.',       s='.a.b.c.d.e.f.'       }
        }
        for i = 1, #tc do
            it("test "..i, function()
                assert.equal(tc[i].r, m.padDots(tc[i].s))
            end)
        end
    end)

    describe("splitWords", function()
        pending("unimplemented test case")
    end)
end)

