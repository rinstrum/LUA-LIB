-------------------------------------------------------------------------------
-- FTP test.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

describe("Telnet #telnet", function ()
    local net = require "tests.network"
    for _, host in ipairs({ net.upperIPaddress, net.lowerIPaddress }) do
        describe(host, function()
            local filename = nil

            it("echo", function()
                local s = net.telnetOpen(host)
                assert.is_not_nil(s)

                finally(function() net.telnetClose(s) end)

                local r = net.telnetSend(s, "echo banana")
                assert.equal("banana", r)
            end)

            it("cd", function()
                local s = net.telnetOpen(host)
                assert.is_not_nil(s)

                finally(function() net.telnetClose(s) end)

                local r = net.telnetSend(s, "cd /etc")
                r = net.telnetSend(s, "cat timezone")
                assert.equal('US/Eastern', r)
            end)

            it("xeq", function()
                local r = net.xeq(host, "cat /etc/timezone")
                assert.equal('US/Eastern', r)
            end)

            it("rm", function()
                local f = net.tmpname('telnet')
                net.xeq(host, "echo hello >" .. f)
                local r = net.getFile(host, f)
                assert.equal("hello\n", r)
                net.deleteFile(host, f)
                r = net.getFile(host, f)
                assert.is_nil(r)
            end)
        end)
    end
end)
