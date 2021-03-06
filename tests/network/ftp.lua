-------------------------------------------------------------------------------
-- FTP test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("FTP #ftp", function ()
    local net = require "tests.network"
    for _, host in ipairs({ net.upperIPaddress, net.lowerIPaddress }) do
        describe(host, function()
            local filename = nil

            it("get passwd", function()
                assert.equal(145, #net.getFile(host, '/etc/passwd'))
            end)

            it("get timezone", function()
                assert.equal("US/Eastern\n", net.getFile(host, '/etc/timezone'))
            end)

            it("get missing", function()
                assert.is_nil(net.getFile(host, '/etc/missing-file'))
            end)

            it("put", function()
                local f = net.tmpname('ftp')
                local c1, c2 = 'xyzzy', ''

                assert.is_nil(net.getFile(host, f))

                finally(function() net.deleteFile(host, f) end)
                net.putFile(host, f, c1)
                assert.equal(c1, net.getFile(host, f))

                net.putFile(host, f, c2)
                assert.equal(c2, net.getFile(host, f))
            end)
        end)
    end
end)
