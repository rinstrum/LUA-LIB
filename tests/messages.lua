-------------------------------------------------------------------------------
-- Unit test message checking helpers.
-- These functions are NOT available inside the rinApp application framework.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

_M = {}

-------------------------------------------------------------------------------
-- Hide a list of functions
-- @param m Module under test
-- @param names List of function names to hide
-- @param ret Return value from these functions
-- @return Descriptor that allows the functions to be fully restored
-- @see restore
-- @local
local function hide(m, names, ret)
    local old, oldp = {}, {}
    local priv = m.getPrivate()

    for _,v in pairs(names) do
        old[v], m[v] = m[v], spy.new(function() return ret end)
        oldp[v], priv[v] = priv[v], m[v]
    end
    return { mod=m, mf=old, pf=oldp }
end

-------------------------------------------------------------------------------
-- Restore a list of functions
-- @param prev Descriptor returned from the above function
-- @see hide
-- @local
local function restore(prev)
    local m = prev.mod
    local p = m.getPrivate()

    for _,v in ipairs(prev.mf) do
        m[v] = prev.mf[v]
        p[v] = prev.pf[v]
    end
end

-------------------------------------------------------------------------------
-- Verify that a register was set by the test case and validate the
-- conents of the message sent
-- @param names List of function names to mock
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
local function check(names, ret, m, regs, f, ...)
    local saved = hide(m, names, ret)

    f(...)
    for _, res in pairs(regs) do
        local func = res.f
        if func == nil then func = names[1] end
        assert.spy(m[func]).was.called_with(res.r, unpack(res))
    end

    restore(saved)
    return ret
end

-------------------------------------------------------------------------------
-- Verify that a register was set by the test case and validate the
-- conents of the message sent
-- @param names List of function names to mock
-- @param m The module under test
-- @param f the function to call
-- @param ... the arguments to the function f
-- @local
local function checkNo(names, m, f, ...)
    for _, fn in pairs(names) do
        stub(m, fn)
    end
    f(...)
    for _, fn in pairs(names) do
        assert.stub(m[fn]).was.not_called()
        m[fn]:revert()
    end
end

-------------------------------------------------------------------------------
-- Various routines to verify that different kinds of message were sent or not
-- @local

function _M.checkReadReg(...) check({'readReg'}, ...) end
function _M.checkNoReadReg(...) checkNo({'readReg'}, ...) end

function _M.checkWriteReg(...) check({'writeReg'}, nil, ...) end
function _M.checkNoWriteReg(...) checkNo({'writeReg'}, ...) end

function _M.checkWriteRegAsync(...) check({'writeRegAsync'}, nil, ...) end
function _M.checkNoWriteRegAsync(...) checkNo({'writeRegAsync'}, ...) end

function _M.checkWriteRegHex(...) check({'writeRegHex'}, nil, ...) end
function _M.checkNoWriteRegHex(...) checkNo({'writeRegHex'}, ...) end

function _M.checkWriteRegHexAsync(...) check({'writeRegHexAsync'}, nil, ...) end
function _M.checkNoWriteRegHexAsync(...) checkNo({'writeRegHexAsync'}, ...) end

function _M.checkExReg(...) check({'exReg'}, nil, ...) end
function _M.checkNoExReg(...) checkNo({'exReg'}, ...) end

function _M.checkExRegAsync(...) check({'exRegAsync'}, nil, ...) end
function _M.checkNoExRegAsync(...) checkNo({'exRegAsync'}, ...) end

local allRegisters = {
    'writeReg',     'writeRegAsync',
    'writeRegHex',  'writeRegHexAsync',
    'exReg',        'exRegAsync',
    'readReg',      'readRegDec',       'readRegHex',
    'readRegLiteral',
    'getRegName',   'getRegType',
    'getRegDecimalPlaces'
}

function _M.checkReg(...) check(allRegisters, nil, ...) end
function _M.checkNoReg(...) checkNo(allRegisters, ...) end

-------------------------------------------------------------------------------
-- Hide all register access function so they don't attempt communication
-- @param m Module under test
-- @param ret Return value for read function
-- @return Descriptor which can be used to restore everything
-- @see retoreRegFunctions
-- @usage
-- local saved = msg.saveRegFunctions(m)
-- ...
-- msg.restoreRegFunctions(saved)
function _M.saveRegFunctions(m, ret)
    return hide(m, allRegisters, ret)
end

-------------------------------------------------------------------------------
-- Restore register functions back to their previous state
-- @function restoreRegFunctions
-- @param Descriptor to restore
-- @see saveRegFunctions
-- @usage
-- local saved = msg.saveRegFunctions(m)
-- ...
-- msg.restoreRegFunctions(saved)
_M.restoreRegFunctions = restore

return _M
