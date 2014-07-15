-------------------------------------------------------------------------------
-- Unit test message checking helpers.
-- These functions are NOT available inside the rinApp application framework.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

_M = {}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Verify that a register was set by the test case and validate the
-- conents of the message sent
-- @param func String representing the name of the function being expected
-- @param ret Return value from the function call
-- @param m The module under test
-- @param regs Table containing the registers to verify
-- @param f the function to call
-- @param ... the arguments to the function f
--
-- The regs table should contain a number of tables.  In each of these the
-- .r element is the register to check and the [1], [2], ... are the
-- expected arguments.
-- @local
local function check(func, cmd, ret, m, regs, f, ...)
    local old, wr, oldfunc = {}, {}, nil
    local names = { func }

    for _,v in ipairs(names) do
        old[v], m[v] = m[v], wr
    end

    m[func] = spy.new(function() return ret end)
    f(...)
    for _, res in pairs(regs) do
        if cmd then
            assert.spy(m[func]).was.called_with(cmd, res.r, unpack(res))
        else
            assert.spy(m[func]).was.called_with(res.r, unpack(res))
        end
    end

    for _,v in ipairs(names) do
        m[v] = old[v]
    end

    return ret
end

local function checkNo(func, m, f, ...)
    stub(m, func)
    f(...)
    assert.stub(m[func]).was.not_called()
    m[func]:revert()
end

-------------------------------------------------------------------------------
-- Various routines to verify that different kinds of message were sent or not
-- @local
function _M.checkSendReg(cmd, ...) check('sendReg', cmd, nil, ...) end
function _M.checkNoSendReg(...) checkNo('sendReg', ...) end

function _M.checkSendRegWait(cmd, ...) check('sendRegWait', cmd, true, ...) end
function _M.checkNoSendRegWait(...) checkNo('sendRegWait', ...) end

function _M.checkWriteReg(...) check('writeReg', nil, nil, ...) end
function _M.checkNoWriteReg(...) checkNo('writeReg', ...) end

return _M
