-------------------------------------------------------------------------------
-- Users unit test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("device type #devices", function()
    local devices = { 'k401', 'k402', 'k410', 'k491' }
    local function makeModule(device)
        local m, p, d = {}, { deviceType = device }, {}
        require("rinLibrary.utilities")(m, p, d)

        return m, p, d
    end

    for _, dev in pairs(devices) do
        describe(dev, function()
            local _, p = makeModule(dev)
            assert.is_true(p[dev](true))
            for _, d in pairs(devices) do
                it(dev .. ' ' .. d, function()
                    if d == dev then assert.is_true(p[dev](true))
                    else             assert.is_nil(p[d]('xyzzy'))
                    end
                end)
            end
        end)
    end

    describe('non-batching', function()
        for _, v in pairs{ 'k401', 'k402', 'k491' } do
            it(v, function()
                local _, p = makeModule(v)
                assert.is_nil(p.batching('hello'))
                assert.equal('aardvark', p.nonbatching('aardvark'))
            end)
        end
    end)

    describe('batching', function()
        for _, v in pairs{ 'k410' } do
            it(v, function()
                local _, p = makeModule(v)
                assert.is_nil(p.nonbatching('hello'))
                assert.equal('aardvark', p.batching('aardvark'))
            end)
        end
    end)

    it('select', function()
        local _, p = makeModule'k491'
        assert.equal(3, p.valueByDevice{ k401=2, k491=3, k410=6 })
        assert.equal(6, p.valueByDevice{ k401=2, k491=6, k410=1 })
        assert.equal('abc', p.valueByDevice{ k401=2, k410=1, default='abc' })
        assert.is_nil(p.valueByDevice{ k401=2, k410=1 })
        assert.is_nil(p.valueByDevice{ k491='nil', default=1 })
        assert.is_nil(p.valueByDevice{ k401='abc', default='nil' })
    end)
end)
