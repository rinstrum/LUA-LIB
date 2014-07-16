-------------------------------------------------------------------------------
-- Register test helpers.
-- These functions are NOT available inside the rinApp application framework.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

_M = {}

-------------------------------------------------------------------------------
-- Populate the registers based on the contents of the passed tables
-- @param popf The population function
-- @param ... The tables to populate the register definitions from
-- @usage
-- local m, p, d = {}, {}, {}
-- require("rinLibrary.utilities")(p, d)
-- require("rinLibrary.K400Reg")(m, p, d)
-- regs.populate(p.regPopulate, m, p, d)
-- @local
function _M.populate(popf, ...)
    for _, t in pairs({...}) do
        for k, v in pairs(t) do
            popf(k, v)
        end
    end
end

return _M
