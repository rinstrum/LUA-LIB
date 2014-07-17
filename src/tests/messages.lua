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
local function check(func, ret, m, regs, f, ...)
    local old, oldp, wr, oldfunc = {}, {}, {}, nil
    local names = { func }
    local priv = m.getPrivate()

    for _,v in ipairs(names) do
        old[v], m[v] = m[v], wr
        oldp[v], priv[v] = priv[v], wr
    end

    m[func] = spy.new(function() return ret end)
    priv[func] = m[func]
    f(...)
    for _, res in pairs(regs) do
        assert.spy(m[func]).was.called_with(res.r, unpack(res))
    end

    for _,v in ipairs(names) do
        m[v] = old[v]
        priv[v] = oldp[v]
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

function _M.checkWriteReg(...) check('readReg', ...) end
function _M.checkNoWriteReg(...) checkNo('readReg', ...) end

function _M.checkWriteReg(...) check('writeReg', nil, ...) end
function _M.checkNoWriteReg(...) checkNo('writeReg', ...) end

function _M.checkWriteRegAsync(...) check('writeRegAsync', nil, ...) end
function _M.checkNoWriteRegAsync(...) checkNo('writeRegAsync', ...) end

function _M.checkWriteRegHexAsync(...) check('writeRegHexAsync', nil, ...) end
function _M.checkNoWriteRegHexAsync(...) checkNo('writeRegHexAsync', ...) end

function _M.checkExReg(...) check('exReg', nil, ...) end
function _M.checkNoExReg(...) checkNo('exReg', ...) end

function _M.checkExRegAsync(...) check('exRegAsync', nil, ...) end
function _M.checkNoExRegAsync(...) checkNo('exRegAsync', ...) end

return _M
