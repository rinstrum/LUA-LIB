-------------------------------------------------------------------------------
-- canonical naming unit tests.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("canonical form #canonical", function()
    local canonical = require('rinLibrary.namings').canonicalisation

    local canTests = {
        { res = "",         val = "" },
        { res = "",         val = " " },
        { res = "",         val = "  " },
        { res = "a",        val = "a" },
        { res = "a",        val = " a" },
        { res = "a",        val = "a " },
        { res = "a",        val = " a " },
        { res = "a",        val = "  a  " },
        { res = "a b",      val = "a  b" },
        { res = "ab cd",    val = "  ab cd  " },
        { res = "ab cd",    val = "  ab   cd  " },
        { res = "ab cd",    val = "ab    cd" },
        { res = "ab cd",    val = "ab    cd" },
        { res = "a\000b",   val = " \t\r\n\f\va\000b \r\t\n\f\v" },
        { res = "abc",      val = '  AbC  ' }
    }

    for i = 1, #canTests do
        it("test "..i, function()
            local r = canTests[i]
            assert.equal(r.res, canonical(r.val))
        end)
    end
end)

