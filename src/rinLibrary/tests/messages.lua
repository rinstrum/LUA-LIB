-------------------------------------------------------------------------------
-- Unit test message checking helpers.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

_M = {}

-------------------------------------------------------------------------------
-- Verify that a register was set by the test case and validate the
-- conents of the message sent
-- @param m The module under test
-- @param regs Table containing the registers to verify
-- @param f the function to call
-- @param ... the arguments to the function f
--
-- The regs table should contain a number of tables.  In each of these the
-- .r element is the register to check and the [1], [2], ... are the
-- expected arguments.
function _M.checkSetRegister(m, regs, f, ...)
    local old = m.CMD_WRFINALHEX
    local wr = {}

    m.CMD_WRFINALHEX = wr
    stub(m, 'sendReg')
    f(...)
    for _, res in pairs(regs) do
        assert.stub(m.sendReg).was.called_with(wr, res.r, unpack(res))
    end
    m.sendReg:revert()
    m.CMD_WRFINALHEX = old
end


-------------------------------------------------------------------------------
-- Verify that no registers were set by a function call
-- @param m The module under test
-- @param f the function to call
-- @param ... the arguments to the function f
function _M.checkNoSetRegister(m, f, ...)
    stub(m, 'sendReg')
    f(...)
    assert.stub(m.sendReg).was.not_called()
    m.sendReg:revert()
end

return _M
