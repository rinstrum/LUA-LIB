-------------------------------------------------------------------------------
-- LCD unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("LCD #lcd", function ()
    local dregs = {
        --lcdmode                 = 0x000D,
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
        require("rinLibrary.GenericLCD")(m, p, d)
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

    describe("K422 non-longer missing registers", function()
        local m, p, d = {}, { deviceType = 'k422' }, {}
        require("rinLibrary.utilities")(m, p, d)
        require("rinLibrary.GenericLCD")(m, p, d)

        for k, v in pairs(dregs) do
            if v >= 16 then
                it("test "..k, function()
                    assert.is_not_nil(d["REG_" .. string.upper(k)])
                end)
            end
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
                assert.equal(tc[i].r, m.strLenLCD(tc[i].s))
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
                assert.equal(tc[i].r, m.strSubLCD(unpack(tc[i].a)))
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

